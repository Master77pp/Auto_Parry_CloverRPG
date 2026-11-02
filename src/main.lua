--!nocheck
--[[
	Brotherhood :: interfaz principal
	=================================
	Pensada para el ejecutor Xeno (Windows, 64 bits).

	APIs utilizadas (todas verificadas en Xeno):
	  loadstring(chunk, nombre)  -> compilacion en el loader
	  game:HttpGet(url)          -> descarga de archivos
	  gethui()                   -> contenedor de GUI (opcional, con fallback)
	  task.spawn / task.wait     -> hilo propio, sin bloquear el runner
	  TweenService               -> animaciones
	  UserInputService           -> arrastre y atajo de teclado

	APIs NO utilizadas a proposito:
	  Drawing, setthreadidentity, syn.*, protect_gui, getconnections
	(no estan verificadas en Xeno, o dependen de identidad de hilo)

	Ninguna llamada que pueda fallar queda sin pcall.
]]

local VERSION = "2.0.0"

--------------------------------------------------------------------
-- 1. Servicios
--------------------------------------------------------------------

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- CoreGui puede no ser accesible segun la identidad del hilo.
local CoreGui = nil
pcall(function()
	CoreGui = game:GetService("CoreGui")
end)

local NOMBRE_GUI = "Brotherhood"

--------------------------------------------------------------------
-- 2. Utilidades
--------------------------------------------------------------------

local function nuevo(clase, props, padre)
	local inst = Instance.new(clase)
	if props then
		for k, v in pairs(props) do
			if k ~= "Parent" then
				inst[k] = v
			end
		end
	end
	if padre then
		inst.Parent = padre
	end
	return inst
end

local function animar(inst, props, duracion, estilo, direccion)
	local info = TweenInfo.new(
		duracion or 0.2,
		estilo or Enum.EasingStyle.Quad,
		direccion or Enum.EasingDirection.Out
	)
	local t = TweenService:Create(inst, info, props)
	t:Play()
	return t
end

local function esquinas(inst, radio)
	nuevo("UICorner", { CornerRadius = UDim.new(0, radio or 8) }, inst)
end

local function borde(inst, color, grosor, transparencia)
	local s = nuevo("UIStroke", {
		Color = color or Color3.fromRGB(255, 255, 255),
		Thickness = grosor or 1,
		Transparency = transparencia or 0.85,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, inst)
	return s
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

--------------------------------------------------------------------
-- 3. Tema
--------------------------------------------------------------------

local Tema = {
	fondo        = Color3.fromRGB(17, 17, 21),
	barra        = Color3.fromRGB(23, 23, 29),
	tarjeta      = Color3.fromRGB(31, 31, 40),
	tarjetaHover = Color3.fromRGB(39, 39, 50),
	acento       = Color3.fromRGB(124, 92, 255),
	acentoOscuro = Color3.fromRGB(94, 68, 205),
	texto        = Color3.fromRGB(236, 236, 245),
	subtexto     = Color3.fromRGB(146, 146, 165),
	exito        = Color3.fromRGB(82, 201, 132),
	peligro      = Color3.fromRGB(232, 84, 84),
}

--------------------------------------------------------------------
-- 4. Contenedor de la GUI (gethui -> CoreGui -> PlayerGui)
--------------------------------------------------------------------

local screenGui = nuevo("ScreenGui", {
	Name = NOMBRE_GUI,
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 999999,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

local function montarGui(gui)
	local candidatos = {}

	if typeof(gethui) == "function" then
		table.insert(candidatos, { "gethui()", function()
			return gethui()
		end })
	end
	if CoreGui then
		table.insert(candidatos, { "CoreGui", function()
			return CoreGui
		end })
	end
	if LocalPlayer then
		table.insert(candidatos, { "PlayerGui", function()
			return LocalPlayer:WaitForChild("PlayerGui", 5)
		end })
	end

	for _, candidato in ipairs(candidatos) do
		local ok, contenedor = pcall(candidato[2])
		if ok and typeof(contenedor) == "Instance" then
			local okPadre = pcall(function()
				gui.Parent = contenedor
			end)
			if okPadre then
				return candidato[1]
			end
		end
	end
	return nil
end

local contenedorUsado = montarGui(screenGui)
if not contenedorUsado then
	pcall(function()
		screenGui:Destroy()
	end)
	error("[Brotherhood] no se encontro un contenedor de GUI valido (gethui/CoreGui/PlayerGui)", 0)
end

-- Evita duplicados si el script se ejecuta dos veces.
if _G.Brotherhood and _G.Brotherhood.gui and _G.Brotherhood.gui ~= screenGui then
	pcall(function()
		_G.Brotherhood.gui:Destroy()
	end)
end

--------------------------------------------------------------------
-- 5. Ventana
--------------------------------------------------------------------

local ventana = nuevo("Frame", {
	Name = "Ventana",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	Size = UDim2.new(0, 560, 0, 380),
	BackgroundColor3 = Tema.fondo,
	BorderSizePixel = 0,
	ClipsDescendants = true,
}, screenGui)

esquinas(ventana, 14)
borde(ventana, Color3.fromRGB(255, 255, 255), 1, 0.88)

local introScale = nuevo("UIScale", { Scale = 0.9 }, ventana)

-- Escalado en pantallas pequenas
local escalaGlobal = nuevo("UIScale", { Scale = 1 }, screenGui)

local function ajustarEscala()
	local camara = workspace.CurrentCamera
	local vp = camara and camara.ViewportSize or Vector2.new(1280, 720)
	local factor = math.min(vp.X / 620, vp.Y / 440)
	escalaGlobal.Scale = math.clamp(factor, 0.6, 1)
end

pcall(ajustarEscala)

--------------------------------------------------------------------
-- 6. Notificaciones
--------------------------------------------------------------------

local capaAvisos = nuevo("Frame", {
	Name = "Avisos",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 16),
	Size = UDim2.new(0, 240, 1, -32),
	BackgroundTransparency = 1,
}, screenGui)

local listaAvisos = nuevo("UIListLayout", {
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
}, capaAvisos)

local function notificar(titulo, mensaje, color)
	local tarjeta = nuevo("Frame", {
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundColor3 = Tema.tarjeta,
		BorderSizePixel = 0,
	}, capaAvisos)

	esquinas(tarjeta, 8)
	borde(tarjeta, color or Tema.acento, 1, 0.4)

	nuevo("Frame", {
		Size = UDim2.new(0, 3, 1, -16),
		Position = UDim2.new(0, 8, 0, 8),
		BackgroundColor3 = color or Tema.acento,
		BorderSizePixel = 0,
	}, tarjeta)

	nuevo("TextLabel", {
		Size = UDim2.new(1, -28, 0, 16),
		Position = UDim2.new(0, 20, 0, 9),
		BackgroundTransparency = 1,
		Text = titulo,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Tema.texto,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, tarjeta)

	nuevo("TextLabel", {
		Size = UDim2.new(1, -28, 0, 20),
		Position = UDim2.new(0, 20, 0, 26),
		BackgroundTransparency = 1,
		Text = mensaje,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = Tema.subtexto,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	}, tarjeta)

	tarjeta.BackgroundTransparency = 1
	animar(tarjeta, { BackgroundTransparency = 0 }, 0.18)

	task.spawn(function()
		task.wait(3.5)
		animar(tarjeta, { BackgroundTransparency = 1 }, 0.3)
		task.wait(0.35)
		pcall(function()
			tarjeta:Destroy()
		end)
	end)
end

--------------------------------------------------------------------
-- 7. Compatibilidad con la API anterior (_G.AutoParry)
--------------------------------------------------------------------

_G.AutoParry = _G.AutoParry or {}
local AP = _G.AutoParry

AP.version = AP.version or VERSION
AP.modules = AP.modules or {}

if type(AP.register) ~= "function" then
	function AP:register(nombre, modulo)
		self.modules[nombre] = modulo
		return modulo
	end
end

if type(AP.setEnabled) ~= "function" then
	function AP:setEnabled(estado)
		self.enabled = not not estado
		return self.enabled
	end
end

--------------------------------------------------------------------
-- 8. Barra de titulo
--------------------------------------------------------------------

local barra = nuevo("Frame", {
	Name = "BarraTitulo",
	Size = UDim2.new(1, 0, 0, 44),
	BackgroundColor3 = Tema.barra,
	BorderSizePixel = 0,
}, ventana)

nuevo("Frame", {
	Size = UDim2.new(1, 0, 0, 1),
	Position = UDim2.new(0, 0, 1, -1),
	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	BackgroundTransparency = 0.9,
	BorderSizePixel = 0,
}, barra)

nuevo("TextLabel", {
	Size = UDim2.new(0, 200, 1, 0),
	Position = UDim2.new(0, 16, 0, 0),
	BackgroundTransparency = 1,
	Text = "BROTHERHOOD",
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextColor3 = Tema.texto,
	TextXAlignment = Enum.TextXAlignment.Left,
}, barra)

nuevo("TextLabel", {
	Size = UDim2.new(0, 80, 1, 0),
	Position = UDim2.new(0, 118, 0, 0),
	BackgroundTransparency = 1,
	Text = "v" .. VERSION,
	Font = Enum.Font.Gotham,
	TextSize = 11,
	TextColor3 = Tema.subtexto,
	TextXAlignment = Enum.TextXAlignment.Left,
}, barra)

local function botonBarra(texto, xOffset, colorHover)
	local b = nuevo("TextButton", {
		Size = UDim2.new(0, 28, 0, 28),
		Position = UDim2.new(1, xOffset, 0.5, -14),
		BackgroundColor3 = Tema.barra,
		BorderSizePixel = 0,
		Text = texto,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = Tema.subtexto,
		AutoButtonColor = false,
	}, barra)

	esquinas(b, 7)

	b.MouseEnter:Connect(function()
		animar(b, { BackgroundColor3 = colorHover or Tema.tarjetaHover, TextColor3 = Tema.texto }, 0.15)
	end)
	b.MouseLeave:Connect(function()
		animar(b, { BackgroundColor3 = Tema.barra, TextColor3 = Tema.subtexto }, 0.15)
	end)

	return b
end

--------------------------------------------------------------------
-- 9. Barra lateral y paginas
--------------------------------------------------------------------

local barraLateral = nuevo("Frame", {
	Name = "BarraLateral",
	Size = UDim2.new(0, 148, 1, -44),
	Position = UDim2.new(0, 0, 0, 44),
	BackgroundColor3 = Tema.barra,
	BorderSizePixel = 0,
}, ventana)

nuevo("Frame", {
	Size = UDim2.new(0, 1, 1, 0),
	Position = UDim2.new(1, -1, 0, 0),
	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	BackgroundTransparency = 0.93,
	BorderSizePixel = 0,
}, barraLateral)

local contenido = nuevo("Frame", {
	Name = "Contenido",
	Size = UDim2.new(1, -149, 1, -60),
	Position = UDim2.new(0, 149, 0, 48),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
}, ventana)

local paginas = {}
local botonesTab = {}
local pestanaActiva = nil

local function crearPagina(nombre)
	local p = nuevo("Frame", {
		Name = nombre,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Visible = false,
	}, contenido)
	paginas[nombre] = p
	return p
end

local function mostrarPagina(nombre)
	if pestanaActiva == nombre then
		return
	end
	pestanaActiva = nombre

	for clave, pagina in pairs(paginas) do
		pagina.Visible = (clave == nombre)
	end

	for clave, boton in pairs(botonesTab) do
		local activo = (clave == nombre)
		animar(boton.fondo, {
			BackgroundColor3 = activo and Tema.tarjeta or Tema.barra,
		}, 0.16)
		animar(boton.indicador, {
			BackgroundTransparency = activo and 0 or 1,
		}, 0.16)
		boton.texto.TextColor3 = activo and Tema.texto or Tema.subtexto
	end

	local pagina = paginas[nombre]
	if pagina then
		pagina.Position = UDim2.new(0, 0, 0, 8)
		animar(pagina, { Position = UDim2.new(0, 0, 0, 0) }, 0.2)
	end
end

local function crearTab(nombre, etiqueta, orden)
	local boton = nuevo("TextButton", {
		Name = nombre,
		Size = UDim2.new(1, -16, 0, 34),
		Position = UDim2.new(0, 8, 0, (orden - 1) * 38 + 10),
		BackgroundColor3 = Tema.barra,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = orden,
	}, barraLateral)

	esquinas(boton, 8)

	local indicador = nuevo("Frame", {
		Size = UDim2.new(0, 3, 0, 18),
		Position = UDim2.new(0, 0, 0.5, -9),
		BackgroundColor3 = Tema.acento,
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
	}, boton)

	esquinas(indicador, 2)

	local texto = nuevo("TextLabel", {
		Size = UDim2.new(1, -24, 1, 0),
		Position = UDim2.new(0, 14, 0, 0),
		BackgroundTransparency = 1,
		Text = etiqueta,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = Tema.subtexto,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, boton)

	botonesTab[nombre] = { fondo = boton, indicador = indicador, texto = texto }

	boton.MouseEnter:Connect(function()
		if pestanaActiva ~= nombre then
			animar(boton, { BackgroundColor3 = Tema.tarjetaHover }, 0.15)
		end
	end)
	boton.MouseLeave:Connect(function()
		if pestanaActiva ~= nombre then
			animar(boton, { BackgroundColor3 = Tema.barra }, 0.15)
		end
	end)
	boton.MouseButton1Click:Connect(function()
		mostrarPagina(nombre)
	end)

	return boton
end

--------------------------------------------------------------------
-- 10. Componentes
--------------------------------------------------------------------

local function crearEncabezado(padre, titulo, subtitulo, y)
	nuevo("TextLabel", {
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 0, y),
		BackgroundTransparency = 1,
		Text = titulo,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = Tema.texto,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, padre)

	if subtitulo then
		nuevo("TextLabel", {
			Size = UDim2.new(1, 0, 0, 16),
			Position = UDim2.new(0, 0, 0, y + 20),
			BackgroundTransparency = 1,
			Text = subtitulo,
			Font = Enum.Font.Gotham,
			TextSize = 11,
			TextColor3 = Tema.subtexto,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, padre)
		return y + 44
	end
	return y + 28
end

local function crearToggle(padre, opciones, y)
	local fila = nuevo("Frame", {
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.new(0, 0, 0, y),
		BackgroundColor3 = Tema.tarjeta,
		BorderSizePixel = 0,
	}, padre)

	esquinas(fila, 8)

	local etiqueta = nuevo("TextLabel", {
		Size = UDim2.new(1, -70, 1, 0),
		Position = UDim2.new(0, 12, 0, 0),
		BackgroundTransparency = 1,
		Text = opciones.texto,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextColor3 = Tema.texto,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, fila)

	local pista = nuevo("Frame", {
		Size = UDim2.new(0, 38, 0, 20),
		Position = UDim2.new(1, -50, 0.5, -10),
		BackgroundColor3 = Tema.tarjetaHover,
		BorderSizePixel = 0,
	}, fila)

	esquinas(pista, 10)

	local perilla = nuevo("Frame", {
		Size = UDim2.new(0, 14, 0, 14),
		Position = UDim2.new(0, 3, 0.5, -7),
		BackgroundColor3 = Tema.subtexto,
		BorderSizePixel = 0,
	}, pista)

	esquinas(perilla, 7)

	local estado = opciones.default == true
	local ocupado = false

	local function aplicar(valor, avisar)
		estado = not not valor
		ocupado = true
		animar(pista, {
			BackgroundColor3 = estado and Tema.acentoOscuro or Tema.tarjetaHover,
		}, 0.18)
		animar(perilla, {
			Position = estado and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7),
			BackgroundColor3 = estado and Color3.fromRGB(255, 255, 255) or Tema.subtexto,
		}, 0.18)
		etiqueta.TextColor3 = estado and Tema.texto or Tema.subtexto
		ocupado = false

		if avisar and type(opciones.callback) == "function" then
			local ok, err = pcall(opciones.callback, estado)
			if not ok then
				notificar("Error", tostring(err), Tema.peligro)
			end
		end
	end

	local boton = nuevo("TextButton", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = "",
	}, fila)

	boton.MouseButton1Click:Connect(function()
		if ocupado then
			return
		end
		aplicar(not estado, true)
	end)

	fila.MouseEnter:Connect(function()
		animar(fila, { BackgroundColor3 = Tema.tarjetaHover }, 0.15)
	end)
	fila.MouseLeave:Connect(function()
		animar(fila, { BackgroundColor3 = Tema.tarjeta }, 0.15)
	end)

	aplicar(estado, false)

	return {
		fila = fila,
		valor = function()
			return estado
		end,
		definir = function(v)
			aplicar(v, false)
		end,
	}
end

local function crearSlider(padre, opciones, y)
	local minimo = opciones.min or 0
	local maximo = opciones.max or 100
	local formato = opciones.formato or "%.0f"
	local valor = math.clamp(opciones.default or minimo, minimo, maximo)

	local fila = nuevo("Frame", {
		Size = UDim2.new(1, 0, 0, 46),
		Position = UDim2.new(0, 0, 0, y),
		BackgroundColor3 = Tema.tarjeta,
		BorderSizePixel = 0,
	}, padre)

	esquinas(fila, 8)

	nuevo("TextLabel", {
		Size = UDim2.new(1, -80, 0, 18),
		Position = UDim2.new(0, 12, 0, 7),
		BackgroundTransparency = 1,
		Text = opciones.texto,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextColor3 = Tema.texto,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, fila)

	local etiquetaValor = nuevo("TextLabel", {
		Size = UDim2.new(0, 60, 0, 18),
		Position = UDim2.new(1, -72, 0, 7),
		BackgroundTransparency = 1,
		Text = string.format(formato, valor),
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = Tema.acento,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, fila)

	local pista = nuevo("Frame", {
		Size = UDim2.new(1, -24, 0, 4),
		Position = UDim2.new(0, 12, 0, 34),
		BackgroundColor3 = Tema.tarjetaHover,
		BorderSizePixel = 0,
	}, fila)

	esquinas(pista, 3)

	local relleno = nuevo("Frame", {
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Tema.acento,
		BorderSizePixel = 0,
	}, pista)

	esquinas(relleno, 3)

	local funcion = {}

	local function pintar(v, avisar)
		valor = math.clamp(v, minimo, maximo)
		local fraccion = (maximo - minimo > 0) and (valor - minimo) / (maximo - minimo) or 0
		relleno.Size = UDim2.new(fraccion, 0, 1, 0)
		etiquetaValor.Text = string.format(formato, valor)
		if avisar and type(opciones.callback) == "function" then
			local ok, err = pcall(opciones.callback, valor)
			if not ok then
				notificar("Error", tostring(err), Tema.peligro)
			end
		end
	end

	local arrastrando = false

	local function desdeX(x)
		local pos = pista.AbsolutePosition.X
		local ancho = pista.AbsoluteSize.X
		if ancho <= 0 then
			return
		end
		local fraccion = math.clamp((x - pos) / ancho, 0, 1)
		pintar(minimo + fraccion * (maximo - minimo), true)
	end

	pista.InputBegan:Connect(function(entrada)
		if entrada.UserInputType == Enum.UserInputType.MouseButton1
			or entrada.UserInputType == Enum.UserInputType.Touch then
			arrastrando = true
			desdeX(entrada.Position.X)
		end
	end)

	UserInputService.InputChanged:Connect(function(entrada)
		if not arrastrando then
			return
		end
		if entrada.UserInputType == Enum.UserInputType.MouseMovement
			or entrada.UserInputType == Enum.UserInputType.Touch then
			desdeX(entrada.Position.X)
		end
	end)

	UserInputService.InputEnded:Connect(function(entrada)
		if entrada.UserInputType == Enum.UserInputType.MouseButton1
			or entrada.UserInputType == Enum.UserInputType.Touch then
			arrastrando = false
		end
	end)

	pintar(valor, false)

	funcion.pintar = pintar
	funcion.valor = function()
		return valor
	end
	return funcion
end

local function crearBoton(padre, opciones, y, ancho)
	local b = nuevo("TextButton", {
		Size = UDim2.new(ancho or 1, ancho and -6 or 0, 0, 34),
		Position = UDim2.new(0, 0, 0, y),
		BackgroundColor3 = Tema.tarjeta,
		BorderSizePixel = 0,
		Text = opciones.texto,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextColor3 = Tema.texto,
		AutoButtonColor = false,
	}, padre)

	esquinas(b, 8)

	b.MouseEnter:Connect(function()
		animar(b, { BackgroundColor3 = Tema.acentoOscuro }, 0.15)
	end)
	b.MouseLeave:Connect(function()
		animar(b, { BackgroundColor3 = Tema.tarjeta }, 0.15)
	end)

	b.MouseButton1Click:Connect(function()
		if type(opciones.callback) == "function" then
			local ok, err = pcall(opciones.callback)
			if not ok then
				notificar("Error", tostring(err), Tema.peligro)
			end
		end
	end)

	return b
end

local function crearTexto(padre, texto, y, color)
	local t = nuevo("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.new(0, 0, 0, y),
		BackgroundTransparency = 1,
		Text = texto,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextColor3 = color or Tema.subtexto,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, padre)
	return t
end

--------------------------------------------------------------------
-- 11. Contenido de las paginas
--------------------------------------------------------------------

local config = {
	autoParry = false,
	velocidad = 50,
	retraso = 120,
	avisos = true,
	fps = false,
}

--------------------------------------------------------------------
-- Pagina: Principal
--------------------------------------------------------------------

local paginaPrincipal = crearPagina("Principal")

local y = crearEncabezado(paginaPrincipal, "Brotherhood", "Panel de control principal", 4)
y = y + 4

local estadoTexto

local toggleParry = crearToggle(paginaPrincipal, {
	texto = "Activar Auto Parry",
	default = false,
	callback = function(estado)
		config.autoParry = estado
		pcall(function()
			AP:setEnabled(estado)
		end)
		if estadoTexto then
			estadoTexto.Text = "Estado: " .. (estado and "activo" or "inactivo")
			estadoTexto.TextColor3 = estado and Tema.exito or Tema.subtexto
		end
		if config.avisos then
			notificar(
				"Auto Parry",
				estado and "Activado" or "Desactivado",
				estado and Tema.exito or Tema.peligro
			)
		end
	end,
}, y)

y = y + 48

local sliderVelocidad = crearSlider(paginaPrincipal, {
	texto = "Velocidad",
	min = 1,
	max = 100,
	default = 50,
	formato = "%.0f%%",
	callback = function(valor)
		config.velocidad = valor
	end,
}, y)

y = y + 52

estadoTexto = crearTexto(paginaPrincipal, "Estado: inactivo", y, Tema.subtexto)

--------------------------------------------------------------------
-- Pagina: Ajustes
--------------------------------------------------------------------

local paginaAjustes = crearPagina("Ajustes")

local y2 = crearEncabezado(paginaAjustes, "Ajustes", "Parametros de comportamiento", 4)
y2 = y2 + 4

local sliderRetraso = crearSlider(paginaAjustes, {
	texto = "Retraso (ms)",
	min = 20,
	max = 500,
	default = 120,
	formato = "%.0f",
	callback = function(valor)
		config.retraso = valor
	end,
}, y2)

y2 = y2 + 52

crearToggle(paginaAjustes, {
	texto = "Mostrar notificaciones",
	default = true,
	callback = function(estado)
		config.avisos = estado
	end,
}, y2)

y2 = y2 + 48

crearBoton(paginaAjustes, {
	texto = "Restablecer valores",
	callback = function()
		sliderRetraso.pintar(120, true)
		sliderVelocidad.pintar(50, true)
		config.retraso = 120
		config.velocidad = 50
		notificar("Ajustes", "Valores restablecidos", Tema.exito)
	end,
}, y2, 1)

--------------------------------------------------------------------
-- Pagina: Visuales
--------------------------------------------------------------------

local paginaVisuales = crearPagina("Visuales")

local y3 = crearEncabezado(paginaVisuales, "Visuales", "Opciones de presentacion", 4)
y3 = y3 + 4

crearToggle(paginaVisuales, {
	texto = "Contador de FPS",
	default = false,
	callback = function(estado)
		config.fps = estado
	end,
}, y3)

y3 = y3 + 48

crearToggle(paginaVisuales, {
	texto = "Resaltar ventana",
	default = false,
	callback = function(estado)
		animar(ventana, {
			BackgroundColor3 = estado and Color3.fromRGB(21, 20, 30) or Tema.fondo,
		}, 0.3)
	end,
}, y3)

--------------------------------------------------------------------
-- Pagina: Info
--------------------------------------------------------------------

local paginaInfo = crearPagina("Info")

local y4 = crearEncabezado(paginaInfo, "Informacion", "Diagnostico del entorno", 4)
y4 = y4 + 4

crearTexto(paginaInfo, "Version: " .. VERSION, y4, Tema.texto)
y4 = y4 + 18
crearTexto(paginaInfo, "Ejecutor: " .. identificarEjecutor(), y4, Tema.texto)
y4 = y4 + 18
crearTexto(paginaInfo, "Contenedor: " .. tostring(contenedorUsado), y4, Tema.texto)
y4 = y4 + 24

crearBoton(paginaInfo, {
	texto = "Copiar enlace del loader",
	callback = function()
		local enlace = "loadstring(game:HttpGet(\"https://raw.githubusercontent.com/Master77pp/Auto_Parry_CloverRPG/main/loader.lua\"))()"
		if typeof(setclipboard) == "function" then
			local ok = pcall(setclipboard, enlace)
			notificar("Portapapeles", ok and "Enlace copiado" or "No disponible", ok and Tema.exito or Tema.peligro)
		else
			notificar("Portapapeles", "setclipboard no disponible", Tema.peligro)
		end
	end,
}, y4, 1)

--------------------------------------------------------------------
-- 12. Interaccion de la ventana
--------------------------------------------------------------------

local arrastrandoVentana = false
local inicioArrastre = nil
local posicionInicial = nil

barra.InputBegan:Connect(function(entrada)
	if entrada.UserInputType == Enum.UserInputType.MouseButton1
		or entrada.UserInputType == Enum.UserInputType.Touch then
		arrastrandoVentana = true
		inicioArrastre = entrada.Position
		posicionInicial = ventana.Position
	end
end)

UserInputService.InputChanged:Connect(function(entrada)
	if not arrastrandoVentana then
		return
	end
	if entrada.UserInputType == Enum.UserInputType.MouseMovement
		or entrada.UserInputType == Enum.UserInputType.Touch then
		local delta = entrada.Position - inicioArrastre
		ventana.Position = UDim2.new(
			posicionInicial.X.Scale,
			posicionInicial.X.Offset + delta.X,
			posicionInicial.Y.Scale,
			posicionInicial.Y.Offset + delta.Y
		)
	end
end)

UserInputService.InputEnded:Connect(function(entrada)
	if entrada.UserInputType == Enum.UserInputType.MouseButton1
		or entrada.UserInputType == Enum.UserInputType.Touch then
		arrastrandoVentana = false
	end
end)

local visible = true

local function definirVisible(estado)
	visible = not not estado
	if visible then
		ventana.Visible = true
		introScale.Scale = 0.9
		animar(introScale, { Scale = 1 }, 0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	else
		animar(introScale, { Scale = 0.9 }, 0.15)
		task.delay(0.15, function()
			if not visible then
				ventana.Visible = false
			end
		end)
	end
end

local function alternarVisible()
	definirVisible(not visible)
end

local botonCerrar = botonBarra("×", -36, Tema.peligro)
botonCerrar.MouseButton1Click:Connect(function()
	definirVisible(false)
end)

local botonMin = botonBarra("–", -70, Tema.tarjetaHover)
botonMin.MouseButton1Click:Connect(function()
	definirVisible(false)
end)

UserInputService.InputBegan:Connect(function(entrada, procesadoPorJuego)
	if procesadoPorJuego then
		return
	end
	if entrada.KeyCode == Enum.KeyCode.RightShift then
		alternarVisible()
	end
end)

--------------------------------------------------------------------
-- 13. Animacion de entrada
--------------------------------------------------------------------

animar(introScale, { Scale = 1 }, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

crearTab("Principal", "Principal", 1)
crearTab("Ajustes", "Ajustes", 2)
crearTab("Visuales", "Visuales", 3)
crearTab("Info", "Info", 4)

mostrarPagina("Principal")

--------------------------------------------------------------------
-- 14. API publica
--------------------------------------------------------------------

_G.Brotherhood = {
	version = VERSION,
	gui = screenGui,
	ventana = ventana,
	config = config,
	contenedor = contenedorUsado,
	notificar = notificar,
	mostrar = function()
		definirVisible(true)
	end,
	ocultar = function()
		definirVisible(false)
	end,
	alternar = alternarVisible,
	pagina = mostrarPagina,
}

if config.avisos then
	notificar("Brotherhood", "Cargado v" .. VERSION .. " · " .. identificarEjecutor(), Tema.exito)
end

print(("[Brotherhood] v%s iniciado en %s"):format(VERSION, contenedorUsado))
