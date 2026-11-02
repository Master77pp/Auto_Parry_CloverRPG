--!nocheck
-- Mock minimo de las APIs de Roblox usadas por Brotherhood y el motor de
-- Auto Parry. Objetivo: ejecutar el codigo fuera del juego y detectar errores
-- de logica (nil index, orden de inicializacion, callbacks rotos, tiempos).

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
	AnimationPlayed = true,
	HealthChanged = true,
	DescendantAdded = true,
	ChildAdded = true,
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
		local copia = {}
		for i, fn in ipairs(callbacks) do
			copia[i] = fn
		end
		for _, fn in ipairs(copia) do
			fn(...)
		end
	end
	return s
end

local Instance_mt = {}

local function descendientes(inst, acc)
	acc = acc or {}
	local hijos = rawget(inst, "_children") or {}
	for _, hijo in ipairs(hijos) do
		table.insert(acc, hijo)
		descendientes(hijo, acc)
	end
	return acc
end

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
			local copia = {}
			for i, hijo in ipairs(rawget(yo, "_children") or {}) do
				copia[i] = hijo
			end
			return copia
		end
	end
	if k == "GetDescendants" then
		return function(yo)
			return descendientes(yo, {})
		end
	end
	if k == "FindFirstChildOfClass" then
		return function(yo, clase)
			for _, hijo in ipairs(rawget(yo, "_children") or {}) do
				if rawget(hijo, "ClassName") == clase then
					return hijo
				end
			end
			return nil
		end
	end
	if k == "FindFirstChild" then
		return function(yo, nombre)
			for _, hijo in ipairs(rawget(yo, "_children") or {}) do
				if rawget(hijo, "Name") == nombre then
					return hijo
				end
			end
			return nil
		end
	end
	if k == "IsA" then
		return function(yo, clase)
			return rawget(yo, "ClassName") == clase or clase == "Instance"
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

-- Vector3 con resta (para distancias)
local Vector3_mt = {}
Vector3_mt.__index = Vector3_mt
function Vector3_mt.__sub(a, b)
	local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
	local magnitud = math.sqrt(dx * dx + dy * dy + dz * dz)
	return setmetatable({ X = dx, Y = dy, Z = dz, Magnitude = magnitud }, Vector3_mt)
end

Vector3 = {}

function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, Magnitude = 0 }, Vector3_mt)
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

-- Reloj virtual y cola de tareas
__reloj = 0
local tareas = {}

function __avanzar(dt)
	local objetivo = __reloj + (dt or 0)
	while true do
		local elegido, indice = nil, nil
		for i, tarea in ipairs(tareas) do
			if tarea.t <= objetivo and (not elegido or tarea.t < elegido.t) then
				elegido, indice = tarea, i
			end
		end
		if not elegido then
			break
		end
		table.remove(tareas, indice)
		__reloj = elegido.t
		local ok, err = pcall(elegido.fn)
		if not ok then
			print("[mock] tarea fallo: " .. tostring(err))
		end
	end
	__reloj = objetivo
end

task = {
	spawn = function(fn, ...)
		local hilo = coroutine.create(fn)
		coroutine.resume(hilo, ...)
	end,
	wait = function()
		return 0
	end,
	delay = function(tiempo, fn)
		table.insert(tareas, { t = __reloj + (tiempo or 0), fn = fn })
	end,
	defer = function(fn)
		table.insert(tareas, { t = __reloj, fn = fn })
	end,
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
	rawset(s, "Name", nombre)
	return s
end

local Players = servicio("Players")
local PlayerGui = criarFalso("PlayerGui")
local LocalPlayer = criarFalso("Player")
rawset(LocalPlayer, "WaitForChild", function(_, _n, _t)
	return PlayerGui
end)
rawset(LocalPlayer, "Character", nil)
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

-- Registro de teclas enviadas
__teclas = {}

local VirtualInputManager = servicio("VirtualInputManager")
rawset(VirtualInputManager, "SendKeyEvent", function(_self, estado, tecla, _texto, _juego)
	table.insert(__teclas, { via = "VirtualInputManager", estado = estado, tecla = tostring(tecla) })
	return true
end)

local servicios = {
	Players = Players,
	TweenService = TweenService,
	UserInputService = UserInputService,
	CoreGui = CoreGui,
	StarterGui = StarterGui,
	VirtualInputManager = VirtualInputManager,
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

--------------------------------------------------------------------
-- Constructores de escenario
--------------------------------------------------------------------

function __crearPersonaje()
	local personaje = criarFalso("Model")
	rawset(personaje, "Name", "Jugador")

	local raiz = criarFalso("Part")
	rawset(raiz, "Name", "HumanoidRootPart")
	rawset(raiz, "Position", Vector3.new(0, 0, 0))
	raiz.Parent = personaje

	local humanoide = criarFalso("Humanoid")
	rawset(humanoide, "Health", 100)
	rawset(humanoide, "MaxHealth", 100)
	rawset(humanoide, "GetState", function()
		return Enum.HumanoidStateType.Running
	end)
	humanoide.Parent = personaje

	local animator = criarFalso("Animator")
	animator.Parent = humanoide

	rawset(LocalPlayer, "Character", personaje)
	return personaje, humanoide, animator
end

function __crearEnemigo(nombre, posicion, conAnimator)
	local modelo = criarFalso("Model")
	rawset(modelo, "Name", nombre)

	local raiz = criarFalso("Part")
	rawset(raiz, "Name", "HumanoidRootPart")
	rawset(raiz, "Position", posicion or Vector3.new(0, 0, 5))
	raiz.Parent = modelo
	rawset(modelo, "PrimaryPart", raiz)

	local humanoide = criarFalso("Humanoid")
	rawset(humanoide, "Health", 130)
	rawset(humanoide, "MaxHealth", 130)
	rawset(humanoide, "GetState", function()
		return Enum.HumanoidStateType.Running
	end)
	humanoide.Parent = modelo

	local animator = nil
	if conAnimator ~= false then
		animator = criarFalso("Animator")
		animator.Parent = humanoide
	end

	modelo.Parent = workspace
	return modelo, humanoide, animator
end

function __crearTrack(nombre, duracion)
	return {
		Animation = { Name = nombre, AnimationId = "rbxassetid://0000000000" },
		Length = duracion,
		IsPlaying = true,
		TimePosition = 0,
		WeightCurrent = 1,
	}
end

function __crearArma(personaje)
	local herramienta = criarFalso("Tool")
	rawset(herramienta, "Name", "Espada")
	herramienta.Parent = personaje
	return herramienta
end

function __limpiarMundo()
	rawset(workspace, "_children", {})
	rawset(LocalPlayer, "Character", nil)
	__teclas = {}
end
