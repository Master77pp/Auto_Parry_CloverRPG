--!nocheck
-- Asserts que se ejecutan DESPUES de src/main.lua (ver tools/run-test.ps1)

local comprobaciones = 0

local function afirmar(condicion, mensaje)
	comprobaciones = comprobaciones + 1
	if not condicion then
		error("[TEST] FALLO: " .. mensaje, 0)
	end
end

-- 1. La interfaz se construyo
afirmar(_G.Brotherhood ~= nil, "_G.Brotherhood no fue publicado")
afirmar(_G.Brotherhood.gui ~= nil, "ScreenGui ausente")
afirmar(_G.Brotherhood.ventana ~= nil, "Ventana ausente")
afirmar(_G.Brotherhood.contenedor == "CoreGui", "contenedor inesperado: " .. tostring(_G.Brotherhood.contenedor))
afirmar(_G.Brotherhood.parry ~= nil, "el motor de parry no quedo expuesto en la API")
afirmar(type(_G.Brotherhood.activarParry) == "function", "activarParry no expuesto")
afirmar(type(_G.Brotherhood.captura) == "function", "captura no expuesta")
afirmar(_G.Brotherhood.version == "2.2.0", "version incorrecta")

-- 2. La API anterior sigue viva
afirmar(type(_G.AutoParry) == "table", "_G.AutoParry ausente")
afirmar(type(_G.AutoParry.register) == "function", "AP:register perdido")
afirmar(type(_G.AutoParry.setEnabled) == "function", "AP:setEnabled perdido")
afirmar(_G.AutoParry:setEnabled(true) == true, "AP:setEnabled no devuelve true")
afirmar(_G.AutoParry.enabled == true, "AP.enabled no se actualizo")
_G.AutoParry:setEnabled(false)

local modulo = _G.AutoParry:register("prueba", { ok = true })
afirmar(modulo.ok == true, "AP:register no devuelve el modulo")
afirmar(_G.AutoParry.modules.prueba.ok == true, "AP.modules no guarda el modulo")

-- 3. Arbol de la GUI
local function recorrer(inst, acc)
	table.insert(acc, inst)
	for _, hijo in ipairs(inst:GetChildren()) do
		recorrer(hijo, acc)
	end
	return acc
end

local nodos = recorrer(_G.Brotherhood.ventana, {})
afirmar(#nodos > 60, "arbol demasiado pequeno: " .. tostring(#nodos) .. " nodos")

-- 4. Los toggles existen y responden
local toggles = {}
for _, n in ipairs(nodos) do
	if n.ClassName == "TextButton" and n.Text == "" and n.Size and n.Size.X.Scale == 1 and n.Size.Y.Scale == 1 then
		table.insert(toggles, n)
	end
end
afirmar(#toggles >= 3, "se esperaban 3+ toggles, hay " .. tostring(#toggles))

toggles[1].MouseButton1Click:Fire()
afirmar(_G.Brotherhood.config.autoParry == true, "el toggle no actualizo config.autoParry")
afirmar(_G.AutoParry.enabled == true, "el toggle no activo AutoParry")

-- 5. Navegacion entre pestanas
local tabAjustes = nil
for _, n in ipairs(nodos) do
	if n.ClassName == "TextButton" and n.Name == "Ajustes" then
		tabAjustes = n
	end
end
afirmar(tabAjustes ~= nil, "no se encontro la pestana Ajustes")
tabAjustes.MouseButton1Click:Fire()

local paginaAjustes = nil
for _, n in ipairs(nodos) do
	if n.ClassName == "Frame" and n.Name == "Ajustes" then
		paginaAjustes = n
	end
end
afirmar(paginaAjustes ~= nil, "pagina Ajustes ausente")
afirmar(paginaAjustes.Visible == true, "la pagina Ajustes no se hizo visible")

-- 6. API publica
afirmar(type(_G.Brotherhood.notificar) == "function", "notificar ausente")
_G.Brotherhood.notificar("Test", "Mensaje de prueba")
_G.Brotherhood.ocultar()
_G.Brotherhood.mostrar()

-- 7. Ningun nodo quedo sin padre (excepto la raiz)
local huerfanos = 0
for _, n in ipairs(nodos) do
	if n ~= _G.Brotherhood.ventana and n.Parent == nil then
		huerfanos = huerfanos + 1
	end
end
afirmar(huerfanos == 0, "nodos huerfanos: " .. tostring(huerfanos))

print(("[TEST] OK: %d comprobaciones, %d nodos en el arbol"):format(comprobaciones, #nodos))
