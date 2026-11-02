--!nocheck
-- Mock minimo de las APIs de Roblox usadas por Brotherhood.
-- Objetivo: ejecutar src/main.lua fuera del juego y detectar errores de
-- logica (nil index, orden de inicializacion, callbacks rotos).

local SENALES = {
	MouseEnter = true,
	MouseLeave = true,
	MouseButton1Click = true,
	MouseButton2Click = true,
	InputBegan = true,
	InputChanged = true,
	InputEnded = true,
	Changed = true,
	Activated = true,
	TouchTap = true,
}

local function nuevaSenal()
	local callbacks = {}
	local s = {}
	function s:Connect(fn)
		table.insert(callbacks, fn)
		return {
			Disconnect = function()
				for i, f in ipairs(callbacks) do
					if f == fn then
						table.remove(callbacks, i)
						break
					end
				end
			end,
		}
	end
	function s:Once(fn)
		return self:Connect(fn)
	end
	function s:Fire(...)
		for _, fn in ipairs(callbacks) do
			fn(...)
		end
	end
	return s
end

local Instance_mt = {}

function Instance_mt.__index(self, k)
	if k == "Parent" then
		return rawget(self, "_parent")
	end
	local v = rawget(self, k)
	if v ~= nil then
		return v
	end
	if SENALES[k] then
		local clave = "__sig_" .. k
		local s = rawget(self, clave)
		if not s then
			s = nuevaSenal()
			rawset(self, clave, s)
		end
		return s
	end
	if k == "WaitForChild" then
		return function(_, _nombre, _timeout)
			return criarFalso("Folder")
		end
	end
	if k == "Destroy" then
		return function(yo)
			rawset(yo, "_destroyed", true)
		end
	end
	if k == "GetChildren" then
		return function(yo)
			return rawget(yo, "_children") or {}
		end
	end
	if k == "Clone" then
		return function(yo)
			return criarFalso(yo.ClassName or "Frame")
		end
	end
	return nil
end

function Instance_mt.__newindex(self, k, v)
	if k == "Parent" then
		rawset(self, "_parent", v)
		if v then
			local hijos = rawget(v, "_children")
			if not hijos then
				hijos = {}
				rawset(v, "_children", hijos)
			end
			table.insert(hijos, self)
		end
		return
	end
	rawset(self, k, v)
end

function Instance_mt.__tostring(self)
	return tostring(rawget(self, "Name") or rawget(self, "ClassName") or "Instance")
end

function criarFalso(clase)
	local obj = {
		__mockInstance = true,
		ClassName = clase or "Frame",
		Name = clase or "Frame",
		_children = {},
	}
	return setmetatable(obj, Instance_mt)
end

-- typeof: los objetos falsos se comportan como Instance
local typeofOriginal = typeof
typeof = function(v)
	if type(v) == "table" and rawget(v, "__mockInstance") then
		return "Instance"
	end
	return typeofOriginal(v)
end

-- Constructores (en el CLI de Luau no existen: se declaran primero)
UDim = {}
UDim2 = {}
Vector2 = {}
Color3 = {}
TweenInfo = {}

function UDim.new(escala, desplazamiento)
	return { Scale = escala or 0, Offset = desplazamiento or 0 }
end

function UDim2.new(xs, xo, ys, yo)
	return {
		X = { Scale = xs or 0, Offset = xo or 0 },
		Y = { Scale = ys or 0, Offset = yo or 0 },
	}
end

function Vector2.new(x, y)
	return { X = x or 0, Y = y or 0 }
end

function Color3.fromRGB(r, g, b)
	return { R = (r or 0) / 255, G = (g or 0) / 255, B = (b or 0) / 255 }
end

function TweenInfo.new(duracion, estilo, direccion)
	return { Time = duracion, Style = estilo, Direction = direccion }
end

-- Enum dinamico
Enum = setmetatable({}, {
	__index = function(_, categoria)
		return setmetatable({}, {
			__index = function(_, item)
				return setmetatable({ Name = categoria .. "." .. item }, {
					__tostring = function(yo)
						return yo.Name
					end,
				})
			end,
		})
	end,
})

-- task
task = {
	spawn = function(fn, ...)
		local hilo = coroutine.create(fn)
		coroutine.resume(hilo, ...)
	end,
	wait = function()
		return 0
	end,
	delay = function(_tiempo, _fn) end,
	defer = function(_fn) end,
}

-- Instance.new
Instance = {
	new = function(clase)
		return criarFalso(clase)
	end,
}

-- Servicios falsos
local function servicio(nombre)
	local s = criarFalso("Service")
	s.Name = nombre
	return s
end

local Players = servicio("Players")
local PlayerGui = criarFalso("PlayerGui")
local LocalPlayer = criarFalso("Player")
rawset(LocalPlayer, "WaitForChild", function(_, _n, _t)
	return PlayerGui
end)
rawset(Players, "LocalPlayer", LocalPlayer)

local TweenService = servicio("TweenService")
rawset(TweenService, "Create", function(_self, _inst, _info, _props)
	return {
		Play = function() end,
		Completed = { Wait = function() end, Connect = function() end },
	}
end)

local UserInputService = servicio("UserInputService")
local CoreGui = servicio("CoreGui")
local StarterGui = servicio("StarterGui")
rawset(StarterGui, "SetCore", function() end)

local servicios = {
	Players = Players,
	TweenService = TweenService,
	UserInputService = UserInputService,
	CoreGui = CoreGui,
	StarterGui = StarterGui,
}

game = criarFalso("DataModel")
rawset(game, "GetService", function(_self, nombre)
	if servicios[nombre] then
		return servicios[nombre]
	end
	return servicio(nombre)
end)
rawset(game, "HttpGet", function(_self, _url)
	return "-- mock"
end)

workspace = criarFalso("Workspace")
rawset(workspace, "CurrentCamera", nil)

-- El _G del CLI de Luau es de solo lectura: se sustituye por una tabla propia.
_G = {}

-- warn no existe en el CLI de Luau
function warn(...)
	print("[warn]", ...)
end

-- El CLI resuelve los globales nativos (typeof) dentro de loadstring con otro
-- entorno. Se inyecta un local al inicio de cada chunk para que el codigo
-- cargado vea el mismo typeof que el resto del test.
__mockTypeof = typeof
local loadstringReal = loadstring
loadstring = function(fuente, nombre)
	return loadstringReal("local typeof = __mockTypeof\n" .. fuente, nombre)
end
