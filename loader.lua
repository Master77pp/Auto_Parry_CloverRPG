--!nocheck
--[[
	Auto Parry — Clover RPG :: bootstrap loader
	--------------------------------------------
	Punto de entrada único y estable. Este archivo NO cambia de URL:
	la lógica vive en src/ y se actualiza sin que tengas que repartir
	un enlace nuevo.

	Para publicar una actualización: sube VERSION aquí abajo y haz push.
	El parámetro ?v= evita que la caché de GitHub (~5 min) sirva el archivo viejo.
]]

local REPO    = "Master77pp/Auto_Parry_CloverRPG"
local BRANCH  = "main"
local ENTRY   = "src/main.lua"
local VERSION = "1.0.0"

local BASE = ("https://raw.githubusercontent.com/%s/%s/"):format(REPO, BRANCH)

-- Aviso en pantalla; si el ejecutor no soporta SetCore, se ignora.
local function notify(mensaje)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "Auto Parry",
			Text = mensaje,
			Duration = 6,
		})
	end)
end

local function fetch(path)
	local url = ("%s%s?v=%s"):format(BASE, path, VERSION)
	local ok, body = pcall(game.HttpGet, game, url)

	if not ok then
		return nil, ("no se pudo conectar: %s"):format(tostring(body))
	end
	if type(body) ~= "string" or body == "" then
		return nil, "respuesta vacía del servidor"
	end
	if body:sub(1, 14) == "404: Not Found" then
		return nil, ("404 en %s (revisa REPO, BRANCH y la ruta; el repo debe ser público)"):format(path)
	end

	return body
end

local fuente, err = fetch(ENTRY)
if not fuente then
	notify("Error: " .. err)
	error("[Auto Parry] " .. err, 0)
end

local chunk, syntaxErr = loadstring(fuente, "@" .. ENTRY)
if not chunk then
	notify("Error de sintaxis en " .. ENTRY)
	error("[Auto Parry] sintaxis: " .. tostring(syntaxErr), 0)
end

local ok, runErr = pcall(chunk)
if not ok then
	notify("Error en ejecución: " .. tostring(runErr))
	error("[Auto Parry] ejecución: " .. tostring(runErr), 0)
end
