--!nocheck
--[[
	Auto Parry — Clover RPG :: punto de entrada
	-------------------------------------------
	Aquí va la lógica real del script. El loader descarga este archivo
	y lo ejecuta; no necesitas cambiar ninguna URL al editarlo.
]]

local VERSION = "1.0.0"

_G.AutoParry = _G.AutoParry or {}

local AP = _G.AutoParry
AP.version = VERSION
AP.enabled = false
AP.modules = AP.modules or {}

-- Punto de extensión: registra módulos aquí cuando los tengas.
function AP:register(nombre, modulo)
	self.modules[nombre] = modulo
	return modulo
end

function AP:setEnabled(estado)
	self.enabled = not not estado
	print(("[Auto Parry] activado: %s"):format(tostring(self.enabled)))
	return self.enabled
end

print(("[Auto Parry] v%s cargado correctamente."):format(VERSION))
