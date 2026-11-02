--!nocheck
--[[
	Brotherhood :: motor de Auto Parry
	==================================
	Modulo independiente de la interfaz. No conoce Brotherhood: recibe una tabla
	de configuracion y devuelve un motor con eventos observables.

	PRINCIPIO DE DISENO
	-------------------
	No hay ni un solo AnimationId ni un tiempo de ataque escrito a mano.
	Todo se deriva de datos reales del juego en tiempo de ejecucion:

	  - El nombre/ID de la animacion sale del propio AnimationTrack.
	  - El momento del impacto se estima con la duracion real del track
	    (impactoRelativo x Length) o con un impactoMs calibrado en el perfil
	    tras observar el ataque.

	Si un perfil no tiene datos calibrados, el motor lo dice en el registro de
	diagnostico en lugar de fingir que sabe cuando golpea.

	API de entrada usada para pulsar F (en orden, con pcall):
	  1. keypress / keyrelease      (UNC, si existe)
	  2. VirtualInputManager:SendKeyEvent
	El metodo que funcione se guarda y se muestra en el diagnostico.
]]

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local M = {}

M.VERSION = "1.1.0"

--------------------------------------------------------------------
-- Perfiles
--------------------------------------------------------------------
-- patronesModelo: coincidencias sobre el nombre del Model (minusculas).
-- patronesAnimacion: vacio = usar palabrasAtaque. Si se rellena con datos
--   capturados, manda sobre las palabras clave y evita falsos positivos.
-- impactoMs: calibrado a mano. Si es nil se usa impactoRelativo x Length.
-- impactoRelativo: estimacion inicial sobre la duracion real del track.
-- bloqueable: informativo. El motor consulta ataquesNoBloqueables.

M.PERFILES = {
	wolf = {
		id = "wolf",
		nombre = "Lobo normal",
		-- La prioridad decide que perfil gana cuando dos coinciden.
		-- "Dire Wolf" contiene "wolf", asi que el lobo gigante necesita
		-- una prioridad mayor o acabaria usando el perfil equivocado.
		prioridad = 10,
		patronesModelo = { "wolf", "lobo" },
		patronesAnimacion = {},
		palabrasAtaque = {
			"attack", "bite", "claw", "slash", "lunge", "maul",
			"chomp", "gnaw", "pounce", "strike", "swing", "snap",
		},
		palabrasIgnoradas = {
			"idle", "walk", "run", "sprint", "jump", "fall",
			"death", "spawn", "emote", "howl", "sleep", "sit",
		},
		alcance = 22,
		impactoRelativo = 0.5,
		impactoMs = nil,
		bloqueable = true,
		-- Nombres/IDs de ataques que NO se pueden bloquear y exigen esquiva.
		-- Vacio a proposito: no se inventa ninguno. Se rellena con datos
		-- capturados del juego (boton "Copiar captura" en la pestana Parry).
		ataquesNoBloqueables = {},
	},
	direwolf = {
		id = "direwolf",
		nombre = "Dire Wolf",
		prioridad = 20,
		patronesModelo = { "dire wolf", "direwolf", "dire" },
		patronesAnimacion = {},
		palabrasAtaque = {
			"attack", "bite", "claw", "slash", "lunge", "maul",
			"chomp", "pounce", "strike", "swing", "stomp", "roar",
		},
		palabrasIgnoradas = {
			"idle", "walk", "run", "sprint", "jump", "fall",
			"death", "spawn", "emote", "howl", "sleep", "sit",
		},
		alcance = 30,
		impactoRelativo = 0.5,
		impactoMs = nil,
		bloqueable = true,
		ataquesNoBloqueables = {},
	},
}

function M.configPorDefecto()
	return {
		activo = false,
		exigirArma = true,
		modoDiagnostico = true,
		leadMs = 0,
		duracionPulsacion = 60,
		cooldownPorEnemigo = 0.9,
		margenAlcance = 6,
		perfiles = {
			wolf = { impactoRelativo = 0.5, impactoMs = nil, activo = true },
			direwolf = { impactoRelativo = 0.5, impactoMs = nil, activo = true },
		},
		teclaParry = "F",
		ventanaVerificacion = 0.9,
	}
end

--------------------------------------------------------------------
-- Utilidades
--------------------------------------------------------------------

local function minusculas(texto)
	return string.lower(tostring(texto or ""))
end

local function contieneAlguno(texto, patrones)
	for _, patron in ipairs(patrones or {}) do
		if patron ~= "" and string.find(texto, minusculas(patron), 1, true) then
			return true, patron
		end
	end
	return false, nil
end

function M.personajeVivo()
	local personaje = LocalPlayer and LocalPlayer.Character
	if not personaje then
		return nil, nil
	end
	local humanoide = personaje:FindFirstChildOfClass("Humanoid")
	if not humanoide or (humanoide.Health or 0) <= 0 then
		return nil, nil
	end
	return personaje, humanoide
end

function M.tieneArma(personaje)
	if not personaje then
		return false, nil
	end
	for _, objeto in ipairs(personaje:GetChildren()) do
		if objeto:IsA("Tool") then
			return true, objeto
		end
	end
	return false, nil
end

function M.distancia(modelo, personaje)
	local a = modelo and (modelo.PrimaryPart or modelo:FindFirstChild("HumanoidRootPart"))
	local b = personaje and personaje:FindFirstChild("HumanoidRootPart")
	if not a or not b then
		return 0
	end
	local ok, valor = pcall(function()
		return (a.Position - b.Position).Magnitude
	end)
	if ok and type(valor) == "number" then
		return valor
	end
	return 0
end

local ESTADOS_UTILES = {
	Running = true,
	RunningNoPhysics = true,
	Idle = true,
	Landed = true,
}

function M.puedeActuar(humanoide)
	if not humanoide then
		return false
	end
	local ok, estado = pcall(function()
		return humanoide:GetState()
	end)
	if not ok or estado == nil then
		return true -- sin informacion, no se bloquea la accion
	end
	local nombre = tostring(estado):match("([%w]+)$") or ""
	return ESTADOS_UTILES[nombre] == true
end

function M.infoAnimacion(track)
	local anim = track and track.Animation
	local nombre = anim and tostring(anim.Name or "") or ""
	local id = anim and tostring(anim.AnimationId or "") or ""
	if nombre == "" then
		nombre = id
	end
	return nombre, id
end

function M.esAtaque(perfil, nombre, id)
	local texto = minusculas(nombre) .. " " .. minusculas(id)

	if contieneAlguno(texto, perfil.palabrasIgnoradas) then
		return false, "palabra ignorada"
	end

	if perfil.patronesAnimacion and #perfil.patronesAnimacion > 0 then
		local coincide = contieneAlguno(texto, perfil.patronesAnimacion)
		if coincide then
			return true, "patron calibrado"
		end
		return false, "no esta en los patrones calibrados"
	end

	local coincide, patron = contieneAlguno(texto, perfil.palabrasAtaque)
	if coincide then
		return true, "palabra clave: " .. tostring(patron)
	end

	return false, "sin coincidencia"
end

function M.perfilPara(modelo)
	local nombre = minusculas(modelo and modelo.Name)
	local elegido, prioridadGanadora, patronGanador = nil, -math.huge, 0

	for _, perfil in pairs(M.PERFILES) do
		for _, patron in ipairs(perfil.patronesModelo or {}) do
			local buscado = minusculas(patron)
			if buscado ~= "" and string.find(nombre, buscado, 1, true) then
				local prioridad = perfil.prioridad or 0
				-- Prioridad explicita y, en empate, el patron mas largo.
				-- Asi "Dire Wolf" nunca cae en el perfil "Wolf".
				if prioridad > prioridadGanadora
					or (prioridad == prioridadGanadora and #buscado > patronGanador) then
					elegido = perfil
					prioridadGanadora = prioridad
					patronGanador = #buscado
				end
			end
		end
	end

	return elegido
end

function M.esNoBloqueable(perfil, nombre, id)
	local lista = perfil and perfil.ataquesNoBloqueables
	if not lista or #lista == 0 then
		return false
	end
	local texto = minusculas(nombre) .. " " .. minusculas(id)
	return contieneAlguno(texto, lista)
end

--------------------------------------------------------------------
-- Motor
--------------------------------------------------------------------

local Motor = {}
Motor.__index = Motor

function M.nuevo(config)
	local self = setmetatable({}, Motor)

	self.config = config or M.configPorDefecto()
	self.eventos = {}
	self.maxEventos = 200
	self.observadas = {}
	self.maxObservadas = 300
	self.enemigos = {}
	self.conexiones = {}
	self.observadores = {}
	self.totalEventos = 0
	self.metodoTecla = nil
	self.refrescoPendiente = false
	self.virtualInput = nil
	self.destruido = false

	pcall(function()
		self.virtualInput = game:GetService("VirtualInputManager")
	end)

	self:_conectarWorkspace()

	-- Escanea lo que ya existe aunque el motor este apagado: asi se pueden
	-- capturar animaciones para calibrar sin arriesgar parpadeos de parry.
	task.defer(function()
		pcall(function()
			self:refrescar()
		end)
	end)

	return self
end

function Motor:_conectarWorkspace()
	local ok, conexion = pcall(function()
		return workspace.DescendantAdded:Connect(function(instancia)
			local clase = instancia.ClassName
			if clase == "Humanoid" or clase == "Animator" or clase == "Model" then
				self:_programarRefresco()
			end
		end)
	end)
	if ok then
		table.insert(self.conexiones, conexion)
	end
end

function Motor:_programarRefresco()
	if self.refrescoPendiente then
		return
	end
	self.refrescoPendiente = true
	task.delay(0.4, function()
		self.refrescoPendiente = false
		pcall(function()
			self:refrescar()
		end)
	end)
end

function Motor:contarEnemigos()
	local total = 0
	for _ in pairs(self.enemigos) do
		total = total + 1
	end
	return total
end

function Motor:refrescar()
	if self.destruido then
		return 0
	end

	local vistos = {}

	local ok, descendientes = pcall(function()
		return workspace:GetDescendants()
	end)
	if not ok then
		return 0
	end

	for _, objeto in ipairs(descendientes) do
		if objeto.ClassName == "Model" then
			local humanoide = objeto:FindFirstChildOfClass("Humanoid")
			if humanoide and (humanoide.Health or 0) > 0 then
				local perfil = M.perfilPara(objeto)
				if perfil then
					vistos[objeto] = true
					if not self.enemigos[objeto] then
						local animator = humanoide:FindFirstChildOfClass("Animator")
						if animator then
							self:_vigilar(objeto, humanoide, animator, perfil)
						end
					end
				end
			end
		end
	end

	local aSoltar = {}
	for modelo, datos in pairs(self.enemigos) do
		if not vistos[modelo] or (datos.humanoide.Health or 0) <= 0 then
			table.insert(aSoltar, modelo)
		end
	end
	for _, modelo in ipairs(aSoltar) do
		self:_soltar(modelo)
	end

	return self:contarEnemigos()
end

function Motor:_vigilar(modelo, humanoide, animator, perfil)
	local datos = {
		modelo = modelo,
		humanoide = humanoide,
		animator = animator,
		perfil = perfil,
		ultimoPulso = nil,
	}

	datos.conexion = animator.AnimationPlayed:Connect(function(track)
		local ok, err = pcall(function()
			self:_alDetectarAnimacion(datos, track)
		end)
		if not ok then
			self:_anotar("error", "fallo al procesar animacion: " .. tostring(err))
		end
	end)

	self.enemigos[modelo] = datos
	self:_anotar("info", ("Enemigo detectado: %s (%s)"):format(tostring(modelo.Name), perfil.nombre))
end

function Motor:_soltar(modelo)
	local datos = self.enemigos[modelo]
	if not datos then
		return
	end
	pcall(function()
		datos.conexion:Disconnect()
	end)
	self.enemigos[modelo] = nil
	self:_anotar("info", "Enemigo fuera de seguimiento: " .. tostring(modelo.Name))
end

function Motor:_observar(datos, nombre, id, duracion, esAtaque, motivo)
	local registro = {
		momento = os.clock(),
		enemigo = tostring(datos.modelo.Name),
		perfil = datos.perfil.id,
		animacion = nombre,
		animId = id,
		duracion = duracion,
		ataque = esAtaque,
		motivo = motivo,
	}

	table.insert(self.observadas, registro)
	while #self.observadas > self.maxObservadas do
		table.remove(self.observadas, 1)
	end
end

function Motor:_alDetectarAnimacion(datos, track)
	local nombre, id = M.infoAnimacion(track)
	local duracion = tonumber(track.Length) or 0
	local esAtaque, motivo = M.esAtaque(datos.perfil, nombre, id)

	-- Se registra SIEMPRE, incluso con el motor apagado: es la materia prima
	-- para calibrar (nombre real, ID, duracion y clasificacion de cada animacion).
	self:_observar(datos, nombre, id, duracion, esAtaque, motivo)

	if not esAtaque then
		if self.config.modoDiagnostico then
			self:_anotar("descartado", ("%s: «%s» ignorada (%s)"):format(tostring(datos.modelo.Name), nombre, motivo))
		end
		return
	end

	if M.esNoBloqueable(datos.perfil, nombre, id) then
		self:_anotar("info", ("%s: «%s» es NO BLOQUEABLE; no se pulsa F (usa Q + direccion)"):format(
			tostring(datos.modelo.Name), nombre
		))
		return
	end

	if not self.config.activo then
		self:_anotar("info", ("Ataque detectado con el motor apagado: %s / %s"):format(tostring(datos.modelo.Name), nombre))
		return
	end

	local ajuste = (self.config.perfiles and self.config.perfiles[datos.perfil.id]) or {}

	if ajuste.activo == false then
		self:_anotar("descartado", ("%s: perfil desactivado en ajustes"):format(datos.perfil.nombre))
		return
	end

	local impacto
	local fuenteTiempo

	if ajuste.impactoMs and ajuste.impactoMs > 0 then
		impacto = ajuste.impactoMs / 1000
		fuenteTiempo = "calibrado"
	else
		local ratio = ajuste.impactoRelativo or datos.perfil.impactoRelativo or 0.5
		impacto = duracion * ratio
		fuenteTiempo = ("estimado %.0f%% de %.2fs"):format(ratio * 100, duracion)
	end

	local anticipacion = (self.config.leadMs or 0) / 1000
	local espera = math.max(0, impacto - anticipacion)

	local evento = {
		id = self.totalEventos + 1,
		momento = os.clock(),
		enemigo = tostring(datos.modelo.Name),
		perfil = datos.perfil.nombre,
		animacion = nombre,
		animId = id,
		duracion = duracion,
		impacto = impacto,
		fuenteTiempo = fuenteTiempo,
		resultado = "pendiente",
		detalle = "",
		vidaAntes = nil,
	}

	self.totalEventos = self.totalEventos + 1
	self:_registrar(evento)
	self:_anotar("ataque", ("%s inicia «%s» (%.2fs) -> impacto en %.2fs [%s]"):format(
		tostring(datos.modelo.Name), nombre, duracion, impacto, fuenteTiempo
	))

	task.delay(espera, function()
		local ok, err = pcall(function()
			self:_ejecutarParry(datos, evento)
		end)
		if not ok then
			evento.resultado = "error interno"
			evento.detalle = tostring(err)
			self:_actualizar(evento)
		end
	end)
end

function Motor:_ejecutarParry(datos, evento)
	if not self.config.activo then
		evento.resultado = "cancelado (motor apagado)"
		self:_actualizar(evento)
		return
	end

	local ahora = os.clock()
	local cooldown = self.config.cooldownPorEnemigo or 0.9
	if datos.ultimoPulso and (ahora - datos.ultimoPulso) < cooldown then
		evento.resultado = "omitido (cooldown)"
		self:_actualizar(evento)
		return
	end

	local personaje, humanoide = M.personajeVivo()
	if not personaje then
		evento.resultado = "omitido (jugador sin vida)"
		self:_actualizar(evento)
		return
	end

	if self.config.exigirArma then
		local conArma, herramienta = M.tieneArma(personaje)
		if not conArma then
			evento.resultado = "omitido (sin arma equipada)"
			self:_actualizar(evento)
			return
		end
		evento.detalle = "arma: " .. tostring(herramienta and herramienta.Name)
	end

	local distancia = M.distancia(datos.modelo, personaje)
	local alcance = (datos.perfil.alcance or 22) + (self.config.margenAlcance or 6)
	if distancia > alcance then
		evento.resultado = ("omitido (fuera de alcance: %.0f)"):format(distancia)
		self:_actualizar(evento)
		return
	end

	if not M.puedeActuar(humanoide) then
		evento.resultado = "omitido (estado del personaje no permite bloquear)"
		self:_actualizar(evento)
		return
	end

	evento.vidaAntes = humanoide.Health
	evento.distancia = distancia

	local pulsado = self:_pulsarF()
	datos.ultimoPulso = ahora

	if pulsado then
		evento.resultado = "parry enviado"
		evento.detalle = (evento.detalle ~= "" and evento.detalle .. " · " or "") .. "via " .. tostring(self.metodoTecla)
		self:_actualizar(evento)
		self:_programarVerificacion(evento)
	else
		evento.resultado = "fallo de entrada (no se pudo pulsar F)"
		self:_actualizar(evento)
	end
end

function Motor:_pulsarF()
	local duracion = (self.config.duracionPulsacion or 60) / 1000

	-- 1. keypress/keyrelease (API UNC). La firma cambia segun el ejecutor:
	--    unos esperan el nombre ("F") y otros el codigo virtual (0x46).
	--    Se prueban ambos; el que funcione queda anotado en el diagnostico.
	if typeof(keypress) == "function" then
		local intentos = { tostring(self.config.teclaParry or "F"), 0x46 }
		for _, valor in ipairs(intentos) do
			local ok = pcall(keypress, valor)
			if ok then
				self.metodoTecla = "keypress/keyrelease"
				if typeof(keyrelease) == "function" then
					task.delay(duracion, function()
						pcall(keyrelease, valor)
					end)
				end
				return true
			end
		end
	end

	-- 2. VirtualInputManager: pulsacion y suelte reales.
	local vim = self.virtualInput
	if vim then
		local ok = pcall(function()
			vim:SendKeyEvent(true, Enum.KeyCode.F, false, game)
		end)
		if ok then
			self.metodoTecla = "VirtualInputManager"
			task.delay(duracion, function()
				pcall(function()
					vim:SendKeyEvent(false, Enum.KeyCode.F, false, game)
				end)
			end)
			return true
		end
	end

	return false
end

-- Verificacion heuristica y honesta: se observa el HealthChanged del jugador
-- durante una ventana. Si la vida baja, el parry fallo. Si no baja en toda la
-- ventana, se marca "probable exito", nunca "exito" a secas: la ausencia de
-- dano tambien podria significar que el golpe no llego.
function Motor:_programarVerificacion(evento)
	local _, humanoide = M.personajeVivo()
	if not humanoide then
		evento.resultado = "no verificable (personaje no disponible)"
		self:_actualizar(evento)
		return
	end

	local vidaAntes = evento.vidaAntes or humanoide.Health
	local ventana = self.config.ventanaVerificacion or 0.9
	local cerrado = false
	local conexion = nil

	local function cerrar(resultado, detalle)
		if cerrado then
			return
		end
		cerrado = true
		if conexion then
			pcall(function()
				conexion:Disconnect()
			end)
		end
		evento.resultado = resultado
		if detalle and detalle ~= "" then
			evento.detalle = detalle
		end
		self:_actualizar(evento)
	end

	pcall(function()
		conexion = humanoide.HealthChanged:Connect(function(vida)
			local actual = tonumber(vida)
			if actual and actual < vidaAntes - 0.5 then
				cerrar("fallo (recibiste dano)", ("%.0f -> %.0f HP"):format(vidaAntes, actual))
			end
		end)
	end)

	task.delay(ventana, function()
		if cerrado then
			return
		end
		local _, actual = M.personajeVivo()
		if not actual then
			cerrar("no verificable (personaje no disponible)")
		elseif actual.Health < vidaAntes - 0.5 then
			cerrar("fallo (recibiste dano)", ("%.0f -> %.0f HP"):format(vidaAntes, actual.Health))
		else
			cerrar("probable exito (sin dano)", ("%.0f HP sin cambios en %.1fs"):format(actual.Health, ventana))
		end
	end)
end

--------------------------------------------------------------------
-- Registro y observadores
--------------------------------------------------------------------

function Motor:_registrar(evento)
	table.insert(self.eventos, evento)
	while #self.eventos > self.maxEventos do
		table.remove(self.eventos, 1)
	end
	self:_avisar(evento)
end

function Motor:_actualizar(evento)
	self:_avisar(evento)
end

function Motor:_anotar(tipo, texto)
	local linea = {
		id = self.totalEventos,
		momento = os.clock(),
		enemigo = "",
		animacion = "",
		impacto = 0,
		resultado = tipo,
		detalle = texto,
		soloDiagnostico = true,
	}
	table.insert(self.eventos, linea)
	while #self.eventos > self.maxEventos do
		table.remove(self.eventos, 1)
	end
	self:_avisar(linea)
end

function Motor:_avisar(evento)
	for _, observador in ipairs(self.observadores) do
		local ok = pcall(observador, evento, self)
		if not ok then
			-- un observador roto no debe tumbar el motor
		end
	end
end

function Motor:onEvento(fn)
	if type(fn) == "function" then
		table.insert(self.observadores, fn)
	end
	return function()
		for i, observador in ipairs(self.observadores) do
			if observador == fn then
				table.remove(self.observadores, i)
				break
			end
		end
	end
end

function Motor:limpiar()
	self.eventos = {}
	self.observadas = {}
end

function Motor:exportar()
	local lineas = {}

	table.insert(lineas, ("Brotherhood :: captura de Auto Parry v%s"):format(M.VERSION))
	table.insert(lineas, ("Fecha: %s"):format(os.date("%Y-%m-%d %H:%M:%S")))
	table.insert(lineas, ("Enemigos vigilados: %d"):format(self:contarEnemigos()))
	table.insert(lineas, ("Motor: %s"):format(self.config.activo and "activo" or "apagado"))
	table.insert(lineas, ("Metodo de tecla: %s"):format(tostring(self.metodoTecla or "sin usar")))
	table.insert(lineas, "")
	table.insert(lineas, "ANIMACIONES OBSERVADAS (enemigo | animacion | AnimationId | duracion | clasificacion)")
	table.insert(lineas, "--------------------------------------------------------------------------")

	for _, r in ipairs(self.observadas) do
		table.insert(lineas, ("%s | \"%s\" | %s | %.2fs | %s (%s)"):format(
			r.enemigo,
			r.animacion,
			r.animId ~= "" and r.animId or "sin id",
			r.duracion,
			r.ataque and "ATAQUE" or "no ataque",
			tostring(r.motivo)
		))
	end

	if #self.observadas == 0 then
		table.insert(lineas, "(vacio: no se ha observado ninguna animacion todavia)")
	end

	table.insert(lineas, "")
	table.insert(lineas, "EVENTOS")
	table.insert(lineas, "--------------------------------------------------------------------------")

	for _, e in ipairs(self.eventos) do
		if e.soloDiagnostico then
			table.insert(lineas, ("[%s] %s"):format(tostring(e.resultado), tostring(e.detalle)))
		else
			table.insert(lineas, ("[%s] %s · %s · impacto %.2fs · %s · %s"):format(
				tostring(e.resultado),
				tostring(e.enemigo),
				tostring(e.animacion),
				tonumber(e.impacto) or 0,
				tostring(e.fuenteTiempo or "?"),
				tostring(e.detalle or "")
			))
		end
	end

	return table.concat(lineas, "\n")
end

function Motor:iniciar()
	self.config.activo = true
	local total = self:refrescar()
	self:_anotar("info", ("Motor activo. Enemigos vigilados: %d"):format(total))
	return total
end

function Motor:detener()
	self.config.activo = false
	self:_anotar("info", "Motor detenido")
end

function Motor:destruir()
	self.destruido = true
	self:detener()

	local modelos = {}
	for modelo in pairs(self.enemigos) do
		table.insert(modelos, modelo)
	end
	for _, modelo in ipairs(modelos) do
		self:_soltar(modelo)
	end

	for _, conexion in ipairs(self.conexiones) do
		pcall(function()
			conexion:Disconnect()
		end)
	end
	self.conexiones = {}
	self.observadores = {}
end

return M
