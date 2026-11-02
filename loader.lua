--!nocheck
--[[
	Brotherhood :: loader
	=====================
	Bootstrap de una sola linea para el ejecutor Xeno.

		loadstring(game:HttpGet("https://raw.githubusercontent.com/Master77pp/Auto_Parry_CloverRPG/main/loader.lua"))()

	Que hace:
	  1. Descarga src/main.lua y los modulos de src/ desde GitHub.
	  2. Prueba los metodos de descarga disponibles, en orden y con pcall.
	  3. Expone los modulos en _G.__BH_MODULES para que la interfaz los compile.
	  4. Compila con loadstring y ejecuta en un hilo propio (task.spawn),
	     porque el hilo del runner de Xeno no admite ceder (yield).
	  5. Cualquier fallo se reporta en pantalla y en la consola, nunca en silencio.

	Si un modulo opcional falla, la interfaz arranca igual y lo indica en pantalla.
]]

local REPO    = "Master77pp/Auto_Parry_CloverRPG"
local BRANCH  = "main"
local ENTRY   = "src/main.lua"
local VERSION = "2.2.0"

-- Modulos opcionales: nombre logico -> ruta en el repo
local MODULOS = {
	autoparry = "src/autoparry.lua",
}

--------------------------------------------------------------------
-- Utilidades
--------------------------------------------------------------------

local function aviso(texto)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "Brotherhood",
			Text = texto,
			Duration = 6,
		})
	end)
end

local function identificarEjecutor()
	if typeof(identifyexecutor) == "function" then
		local ok, nombre = pcall(identifyexecutor)
		if ok and type(nombre) == "string" and nombre ~= "" then
			return nombre
		end
	end
	return "Desconocido"
end

local function disponible(fn)
	return typeof(fn) == "function"
end

--------------------------------------------------------------------
-- Descarga
--------------------------------------------------------------------

local function construirMetodos(url)
	local metodos = {}

	local okHttpGet, fnHttpGet = pcall(function()
		return game.HttpGet
	end)

	if okHttpGet and type(fnHttpGet) == "function" then
		table.insert(metodos, {
			nombre = "game:HttpGet",
			ejecutar = function()
				return fnHttpGet(game, url)
			end,
		})
	end

	if typeof(request) == "function" then
		table.insert(metodos, {
			nombre = "request",
			ejecutar = function()
				local r = request({ Url = url, Method = "GET" })
				if type(r) == "table" then
					return r.Body or r.body
				end
			end,
		})
	end

	if typeof(http_request) == "function" then
		table.insert(metodos, {
			nombre = "http_request",
			ejecutar = function()
				local r = http_request({ Url = url, Method = "GET" })
				if type(r) == "table" then
					return r.Body or r.body
				end
			end,
		})
	end

	return metodos
end

local function descargar(ruta)
	local url = ("https://raw.githubusercontent.com/%s/%s/%s?v=%s"):format(REPO, BRANCH, ruta, VERSION)
	local metodos = construirMetodos(url)
	local diagnosticos = {}
	local ultimoError = "sin metodos disponibles"

	if #metodos == 0 then
		return nil, nil, diagnosticos, ultimoError
	end

	for _, candidato in ipairs(metodos) do
		local ok, resultado = pcall(candidato.ejecutar)

		if not ok then
			table.insert(diagnosticos, ("%s: excepcion (%s)"):format(candidato.nombre, tostring(resultado)))
			ultimoError = tostring(resultado)
		elseif type(resultado) ~= "string" or resultado == "" then
			table.insert(diagnosticos, ("%s: respuesta vacia"):format(candidato.nombre))
			ultimoError = "respuesta vacia"
		elseif resultado:sub(1, 14) == "404: Not Found" then
			table.insert(diagnosticos, ("%s: 404 (revisa REPO/BRANCH/ruta)"):format(candidato.nombre))
			ultimoError = "404 en " .. ruta
		else
			return resultado, candidato.nombre, diagnosticos
		end
	end

	return nil, nil, diagnosticos, ultimoError
end

--------------------------------------------------------------------
-- Interfaz principal
--------------------------------------------------------------------

local fuente, metodo, diagnosticos, ultimoError = descargar(ENTRY)

if not fuente then
	for _, linea in ipairs(diagnosticos) do
		warn("[Brotherhood] " .. linea)
	end
	aviso("No se pudo descargar la interfaz")
	error("[Brotherhood] descarga fallida: " .. tostring(ultimoError), 0)
end

--------------------------------------------------------------------
-- Modulos opcionales
--------------------------------------------------------------------

local modulos = {}
local fallidos = {}

for nombre, ruta in pairs(MODULOS) do
	local contenido, metodoModulo, diagModulo, errorModulo = descargar(ruta)

	if contenido then
		modulos[nombre] = contenido
		print(("[Brotherhood] modulo %s cargado via %s (%d bytes)"):format(nombre, tostring(metodoModulo), #contenido))
	else
		table.insert(fallidos, nombre)
		for _, linea in ipairs(diagModulo or {}) do
			warn("[Brotherhood] " .. linea)
		end
		warn(("[Brotherhood] modulo %s no disponible: %s"):format(nombre, tostring(errorModulo)))
	end
end

_G.__BH_MODULES = modulos

--------------------------------------------------------------------
-- Diagnostico de compatibilidad
--------------------------------------------------------------------

print("[Brotherhood] ejecutor:    " .. identificarEjecutor())
print("[Brotherhood] descarga via: " .. tostring(metodo))
print("[Brotherhood] bytes:       " .. tostring(#fuente))
print(("[Brotherhood] loadstring:   %s"):format(tostring(disponible(loadstring))))
print(("[Brotherhood] gethui:       %s"):format(tostring(disponible(gethui))))
print(("[Brotherhood] setclipboard: %s"):format(tostring(disponible(setclipboard))))
print(("[Brotherhood] keypress:     %s"):format(tostring(disponible(keypress))))
print(("[Brotherhood] modulos:      %d/%d"):format(#modulos, #modulos + #fallidos))

--------------------------------------------------------------------
-- Compilacion y ejecucion
--------------------------------------------------------------------

local chunk, errorSintaxis = loadstring(fuente, "@" .. ENTRY)

if not chunk then
	warn("[Brotherhood] error de sintaxis: " .. tostring(errorSintaxis))
	aviso("Error de sintaxis en la interfaz")
	error("[Brotherhood] sintaxis: " .. tostring(errorSintaxis), 0)
end

-- Xeno no permite ceder en el hilo del runner: todo el trabajo pesado
-- (GUI, esperas, descargas) ocurre dentro de este hilo aparte.
task.spawn(function()
	local ok, errorEjecucion = pcall(chunk)
	if not ok then
		warn("[Brotherhood] error en ejecucion: " .. tostring(errorEjecucion))
		aviso("Error al iniciar la interfaz: " .. tostring(errorEjecucion))
		return
	end

	if #fallidos > 0 then
		aviso("Modulos no disponibles: " .. table.concat(fallidos, ", "))
	end
end)
