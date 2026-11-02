--!nocheck
--[[
	Brotherhood :: loader
	=====================
	Bootstrap de una sola linea para el ejecutor Xeno.

		loadstring(game:HttpGet("https://raw.githubusercontent.com/Master77pp/Auto_Parry_CloverRPG/main/loader.lua"))()

	Que hace:
	  1. Descarga src/main.lua desde GitHub (con cache-busting por VERSION).
	  2. Prueba los metodos de descarga disponibles, en orden y con pcall.
	  3. Compila con loadstring y ejecuta en un hilo propio (task.spawn),
	     porque el hilo del runner de Xeno no admite ceder (yield).
	  4. Cualquier fallo se reporta en pantalla y en la consola, nunca en silencio.

	Metodos de descarga usados (todos presentes en Xeno; el resto ni se intenta):
	  game:HttpGet  -> metodo principal
	  request       -> respaldo UNC
	  http_request  -> respaldo UNC alternativo
]]

local REPO    = "Master77pp/Auto_Parry_CloverRPG"
local BRANCH  = "main"
local ENTRY   = "src/main.lua"
local VERSION = "2.0.0"

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

local function comprobar(nombre, fn)
	if typeof(fn) == "function" then
		return true
	end
	return false
end

--------------------------------------------------------------------
-- Descarga
--------------------------------------------------------------------

local URL = ("https://raw.githubusercontent.com/%s/%s/%s?v=%s"):format(REPO, BRANCH, ENTRY, VERSION)

local metodos = {}

local okHttpGet, fnHttpGet = pcall(function()
	return game.HttpGet
end)

if okHttpGet and type(fnHttpGet) == "function" then
	table.insert(metodos, {
		nombre = "game:HttpGet",
		ejecutar = function()
			return fnHttpGet(game, URL)
		end,
	})
end

if typeof(request) == "function" then
	table.insert(metodos, {
		nombre = "request",
		ejecutar = function()
			local r = request({ Url = URL, Method = "GET" })
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
			local r = http_request({ Url = URL, Method = "GET" })
			if type(r) == "table" then
				return r.Body or r.body
			end
		end,
	})
end

if #metodos == 0 then
	aviso("Error: este ejecutor no expone ninguna funcion HTTP")
	error("[Brotherhood] sin metodos de descarga disponibles (ni game:HttpGet, ni request)", 0)
end

local fuente, metodo, ultimoError
local diagnosticos = {}

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
		ultimoError = "404 en " .. ENTRY
	else
		fuente = resultado
		metodo = candidato.nombre
		break
	end
end

if not fuente then
	for _, linea in ipairs(diagnosticos) do
		warn("[Brotherhood] " .. linea)
	end
	aviso("No se pudo descargar la interfaz")
	error("[Brotherhood] descarga fallida: " .. tostring(ultimoError), 0)
end

--------------------------------------------------------------------
-- Diagnostico de compatibilidad
--------------------------------------------------------------------

print("[Brotherhood] ejecutor:    " .. identificarEjecutor())
print("[Brotherhood] descarga via: " .. metodo)
print("[Brotherhood] bytes:       " .. tostring(#fuente))
print(("[Brotherhood] loadstring:   %s"):format(tostring(comprobar("loadstring", loadstring))))
print(("[Brotherhood] gethui:       %s"):format(tostring(comprobar("gethui", gethui))))
print(("[Brotherhood] setclipboard: %s"):format(tostring(comprobar("setclipboard", setclipboard))))

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
	end
end)
