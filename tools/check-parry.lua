--!nocheck
-- Pruebas del motor de Auto Parry (ver tools/run-parry-test.ps1)
-- Todo es sintetico: se simulan enemigos, animaciones y pulsaciones.
-- NO demuestran que funcione en Clover RPG; demuestran que la logica hace
-- lo que dice hacer con los datos que recibe.

local comprobaciones = 0

local function afirmar(condicion, mensaje)
	comprobaciones = comprobaciones + 1
	if not condicion then
		error("[TEST] FALLO: " .. mensaje, 0)
	end
end

local function nuevoMotor(ajustes)
	local cfg = AutoParry.configPorDefecto()
	cfg.modoDiagnostico = true
	if ajustes then
		for clave, valor in pairs(ajustes) do
			cfg[clave] = valor
		end
	end
	return AutoParry.nuevo(cfg)
end

local function ultimoAtaque(motor)
	for i = #motor.eventos, 1, -1 do
		local evento = motor.eventos[i]
		if not evento.soloDiagnostico and evento.animacion ~= "" then
			return evento
		end
	end
	return nil
end

-- Cuenta solo las pulsaciones (no los "soltar" de VirtualInputManager)
local function pulsaciones()
	local total = 0
	for _, registro in ipairs(__teclas) do
		if registro.estado == true then
			total = total + 1
		end
	end
	return total
end

local function escenario(nombreEnemigo, posicion, nombreAnimacion, duracion)
	local personaje = __crearPersonaje()
	__crearArma(personaje)
	local enemigo, humanoide, animator = __crearEnemigo(nombreEnemigo, posicion)
	animator.AnimationPlayed:Fire(__crearTrack(nombreAnimacion, duracion))
	return personaje, enemigo, humanoide, animator
end

--------------------------------------------------------------------
-- 1. Lobo: deteccion, calculo de impacto y pulsacion
--------------------------------------------------------------------
do
	__limpiarMundo()
	local personaje = __crearPersonaje()
	__crearArma(personaje)
	local _, humanoide, animator = __crearEnemigo("Wolf", Vector3.new(0, 0, 5))

	local motor = nuevoMotor()
	motor:iniciar()
	afirmar(motor:contarEnemigos() == 1, "deberia vigilar exactamente 1 lobo")

	__teclas = {}
	animator.AnimationPlayed:Fire(__crearTrack("WolfBite", 1.0))

	local evento = ultimoAtaque(motor)
	afirmar(evento ~= nil, "no se registro el ataque")
	afirmar(evento.resultado == "pendiente", "el ataque deberia quedar pendiente")
	afirmar(math.abs(evento.impacto - 0.5) < 0.001, "impacto esperado 0.50s, obtenido " .. tostring(evento.impacto))
	afirmar(evento.fuenteTiempo:find("estimado") ~= nil, "la fuente deberia ser 'estimado'")

	__avanzar(0.5)
	afirmar(pulsaciones() >= 1, "no se envio ninguna tecla al llegar el impacto")
	afirmar(evento.resultado == "parry enviado", "resultado tras pulsar: " .. tostring(evento.resultado))

	-- La verificacion espera su ventana completa (0.9s) antes de concluir.
	__avanzar(1.0)
	afirmar(evento.resultado == "probable exito (sin dano)", "verificacion: " .. tostring(evento.resultado))

	humanoide.Health = 100
	motor:destruir()
end

--------------------------------------------------------------------
-- 2. Movimiento normal no dispara parry
--------------------------------------------------------------------
do
	__limpiarMundo()
	local personaje = __crearPersonaje()
	__crearArma(personaje)
	local _, _, animator = __crearEnemigo("Wolf", Vector3.new(0, 0, 5))

	local motor = nuevoMotor()
	motor:iniciar()
	__teclas = {}

	animator.AnimationPlayed:Fire(__crearTrack("WolfIdle", 2.0))
	animator.AnimationPlayed:Fire(__crearTrack("WolfWalk", 1.2))

	afirmar(ultimoAtaque(motor) == nil, "un idle/walk no debe registrarse como ataque")
	__avanzar(1.0)
	afirmar(pulsaciones() == 0, "no debe pulsarse F sin ataque real")

	motor:destruir()
end

--------------------------------------------------------------------
-- 3. Sin ataques no hay pulsaciones (motor encendido)
--------------------------------------------------------------------
do
	__limpiarMundo()
	__crearPersonaje()
	local motor = nuevoMotor()
	motor:iniciar()
	__teclas = {}
	__avanzar(2.0)
	afirmar(pulsaciones() == 0, "no debe pulsarse F si no hay enemigos atacando")
	afirmar(motor:contarEnemigos() == 0, "no deberia haber enemigos vigilados")
	motor:destruir()
end

--------------------------------------------------------------------
-- 4. Cooldown por enemigo
--------------------------------------------------------------------
do
	__limpiarMundo()
	local personaje = __crearPersonaje()
	__crearArma(personaje)
	local _, _, animator = __crearEnemigo("Wolf", Vector3.new(0, 0, 5))

	local motor = nuevoMotor({ cooldownPorEnemigo = 100 })
	motor:iniciar()
	__teclas = {}

	animator.AnimationPlayed:Fire(__crearTrack("WolfBite", 1.0))
	__avanzar(0.5)
	afirmar(pulsaciones() == 1, "primer ataque: deberia pulsar una vez")

	local primero = ultimoAtaque(motor)
	animator.AnimationPlayed:Fire(__crearTrack("WolfBite", 1.0))
	__avanzar(0.5)
	afirmar(pulsaciones() == 1, "segundo ataque en cooldown no debe pulsar")
	afirmar(ultimoAtaque(motor).resultado:find("cooldown") ~= nil, "deberia marcarse como cooldown")

	motor:destruir()
end

--------------------------------------------------------------------
-- 5. Sin arma equipada
--------------------------------------------------------------------
do
	__limpiarMundo()
	__crearPersonaje() -- sin __crearArma
	local _, _, animator = __crearEnemigo("Wolf", Vector3.new(0, 0, 5))

	local motor = nuevoMotor({ exigirArma = true })
	motor:iniciar()
	__teclas = {}
	animator.AnimationPlayed:Fire(__crearTrack("WolfBite", 1.0))
	__avanzar(0.5)

	afirmar(pulsaciones() == 0, "no debe pulsar sin arma si exigirArma esta activo")
	afirmar(ultimoAtaque(motor).resultado:find("sin arma") ~= nil, "deberia indicar falta de arma")

	motor:destruir()
end

--------------------------------------------------------------------
-- 6. Fuera de alcance
--------------------------------------------------------------------
do
	__limpiarMundo()
	local personaje = __crearPersonaje()
	__crearArma(personaje)
	local _, _, animator = __crearEnemigo("Wolf", Vector3.new(0, 0, 300))

	local motor = nuevoMotor()
	motor:iniciar()
	__teclas = {}
	animator.AnimationPlayed:Fire(__crearTrack("WolfBite", 1.0))
	__avanzar(0.5)

	afirmar(pulsaciones() == 0, "no debe pulsar fuera de alcance")
	afirmar(ultimoAtaque(motor).resultado:find("fuera de alcance") ~= nil, "deberia indicar distancia")

	motor:destruir()
end

--------------------------------------------------------------------
-- 7. Dire Wolf usa su propio perfil, no el del lobo
--------------------------------------------------------------------
do
	__limpiarMundo()
	local personaje = __crearPersonaje()
	__crearArma(personaje)
	local _, _, animator = __crearEnemigo("Dire Wolf", Vector3.new(0, 0, 10))

	local motor = nuevoMotor()
	motor.config.perfiles.wolf.impactoRelativo = 0.5
	motor.config.perfiles.direwolf.impactoRelativo = 0.8
	motor:iniciar()

	animator.AnimationPlayed:Fire(__crearTrack("DireWolfBite", 1.25))
	local evento = ultimoAtaque(motor)
	afirmar(evento.perfil == "Dire Wolf", "perfil detectado: " .. tostring(evento.perfil))
	afirmar(math.abs(evento.impacto - 1.0) < 0.01, "impacto Dire Wolf esperado 1.00s, obtenido " .. tostring(evento.impacto))

	motor:destruir()
end

--------------------------------------------------------------------
-- 8. Motor apagado: detecta pero no pulsa
--------------------------------------------------------------------
do
	__limpiarMundo()
	local personaje = __crearPersonaje()
	__crearArma(personaje)
	local _, _, animator = __crearEnemigo("Wolf", Vector3.new(0, 0, 5))

	local motor = nuevoMotor()
	motor:refrescar()
	__teclas = {}
	animator.AnimationPlayed:Fire(__crearTrack("WolfBite", 1.0))
	__avanzar(1.0)

	afirmar(pulsaciones() == 0, "con el motor apagado no debe pulsarse F")
	afirmar(motor.config.activo == false, "el motor deberia seguir apagado")

	motor:destruir()
end

--------------------------------------------------------------------
-- 9. Metodo keypress tiene prioridad sobre VirtualInputManager
--------------------------------------------------------------------
do
	__limpiarMundo()
	local personaje = __crearPersonaje()
	__crearArma(personaje)
	local _, _, animator = __crearEnemigo("Wolf", Vector3.new(0, 0, 5))

	local registros = {}
	keypress = function(tecla)
		table.insert(registros, tecla)
	end

	local motor = nuevoMotor()
	motor:iniciar()
	__teclas = {}
	animator.AnimationPlayed:Fire(__crearTrack("WolfBite", 1.0))
	__avanzar(0.5)

	afirmar(#registros == 1, "keypress deberia haberse llamado una vez")
	afirmar(registros[1] == "F", "keypress deberia recibir la tecla F, recibio " .. tostring(registros[1]))
	afirmar(motor.metodoTecla == "keypress/keyrelease", "metodo elegido: " .. tostring(motor.metodoTecla))

	keypress = nil
	motor:destruir()
end

--------------------------------------------------------------------
-- 10. Unidades: clasificacion de animaciones
--------------------------------------------------------------------
do
	local perfil = AutoParry.PERFILES.wolf
	afirmar(AutoParry.esAtaque(perfil, "WolfBite", "") == true, "WolfBite es ataque")
	afirmar(AutoParry.esAtaque(perfil, "WolfIdle", "") == false, "WolfIdle no es ataque")
	afirmar(AutoParry.esAtaque(perfil, "Howl", "") == false, "Howl no es ataque")
	afirmar(AutoParry.esAtaque(perfil, "Attack01", "") == true, "Attack01 es ataque")
	afirmar(AutoParry.perfilPara({ Name = "Dire Wolf" }).id == "direwolf", "Dire Wolf detectado")
	afirmar(AutoParry.perfilPara({ Name = "Wolf" }).id == "wolf", "Wolf detectado")
	afirmar(AutoParry.perfilPara({ Name = "Zombie" }) == nil, "Zombie no tiene perfil")
end

--------------------------------------------------------------------
-- 11. Prioridad de perfiles: "Dire Wolf" nunca cae en "Wolf"
--------------------------------------------------------------------
do
	-- pairs() no garantiza orden; se comprueba muchas veces con variantes.
	local nombres = { "Dire Wolf", "direwolf", "DireWolf", "DIRE WOLF", "Dire Wolf Boss" }
	for _, nombre in ipairs(nombres) do
		for _ = 1, 25 do
			local perfil = AutoParry.perfilPara({ Name = nombre })
			afirmar(perfil ~= nil and perfil.id == "direwolf",
				"perfil incorrecto para " .. nombre .. ": " .. tostring(perfil and perfil.id))
		end
	end
	afirmar(AutoParry.perfilPara({ Name = "Wolf" }).id == "wolf", "el lobo normal sigue siendo wolf")
	afirmar(AutoParry.perfilPara({ Name = "Lobo" }).id == "wolf", "Lobo en espanol sigue siendo wolf")
	afirmar(AutoParry.perfilPara({ Name = "Wolf Pup" }).id == "wolf", "Wolf Pup usa el perfil de lobo")
end

--------------------------------------------------------------------
-- 12. Ataque marcado como no bloqueable: no se pulsa F
--------------------------------------------------------------------
do
	__limpiarMundo()
	local personaje = __crearPersonaje()
	__crearArma(personaje)
	local _, _, animator = __crearEnemigo("Wolf", Vector3.new(0, 0, 5))

	local perfil = AutoParry.PERFILES.wolf
	perfil.ataquesNoBloqueables = { "unblockable" }

	local motor = nuevoMotor()
	motor:iniciar()
	__teclas = {}
	animator.AnimationPlayed:Fire(__crearTrack("WolfUnblockableBite", 1.0))
	__avanzar(1.0)

	afirmar(pulsaciones() == 0, "un ataque no bloqueable no debe pulsar F")
	afirmar(ultimoAtaque(motor) == nil, "no debe crearse evento de parry para un ataque no bloqueable")

	perfil.ataquesNoBloqueables = {}
	motor:destruir()
end

--------------------------------------------------------------------
-- 13. Si llega dano durante la ventana, el resultado es fallo
--------------------------------------------------------------------
do
	__limpiarMundo()
	local personaje, humanoide, animator = __crearPersonaje()
	__crearArma(personaje)
	local _, _, animatorEnemigo = __crearEnemigo("Wolf", Vector3.new(0, 0, 5))

	local motor = nuevoMotor()
	motor:iniciar()
	__teclas = {}
	animatorEnemigo.AnimationPlayed:Fire(__crearTrack("WolfBite", 1.0))
	__avanzar(0.5)
	afirmar(pulsaciones() == 1, "deberia haber pulsado una vez")

	humanoide.Health = 72
	humanoide.HealthChanged:Fire(72)
	afirmar(ultimoAtaque(motor).resultado == "fallo (recibiste dano)",
		"resultado esperado fallo, obtenido " .. tostring(ultimoAtaque(motor).resultado))

	motor:destruir()
end

--------------------------------------------------------------------
-- 14. Captura: se registran todas las animaciones, incluso con motor apagado
--------------------------------------------------------------------
do
	__limpiarMundo()
	__crearPersonaje()
	local _, _, animator = __crearEnemigo("Dire Wolf", Vector3.new(0, 0, 10))

	local motor = nuevoMotor()
	motor:refrescar()
	animator.AnimationPlayed:Fire(__crearTrack("DireWolfWalk", 1.4))
	animator.AnimationPlayed:Fire(__crearTrack("DireWolfBite", 1.2))

	afirmar(#motor.observadas == 2, "deberian registrarse 2 animaciones, hay " .. tostring(#motor.observadas))
	afirmar(motor.observadas[1].ataque == false, "caminar no es ataque")
	afirmar(motor.observadas[2].ataque == true, "morder es ataque")
	afirmar(motor.observadas[2].duracion == 1.2, "duracion registrada incorrecta")
	afirmar(pulsaciones() == 0, "con el motor apagado no debe pulsarse F")

	local texto = motor:exportar()
	afirmar(texto:find("DireWolfBite", 1, true) ~= nil, "la captura no incluye la animacion")
	afirmar(texto:find("ATAQUE", 1, true) ~= nil, "la captura no clasifica el ataque")
	afirmar(texto:find("Animator", 1, true) == nil, "la captura no debe inventar IDs")

	motor:destruir()
end

print(("[TEST PARRY] OK: %d comprobaciones"):format(comprobaciones))
