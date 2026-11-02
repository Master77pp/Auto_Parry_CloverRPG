# Prueba de los caminos de error del loader:
#   A) game:HttpGet devuelve 404 -> debe caer al respaldo `request` y cargar.
#   B) todos los metodos fallan    -> debe abortar con mensaje claro.

$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $PSScriptRoot
$luau = Join-Path $env:TEMP "luau\luau.exe"

$mock   = [IO.File]::ReadAllText((Join-Path $raiz "tools\mock-roblox.lua"), [Text.Encoding]::UTF8)
$main   = [IO.File]::ReadAllText((Join-Path $raiz "src\main.lua"), [Text.Encoding]::UTF8)
$motor  = [IO.File]::ReadAllText((Join-Path $raiz "src\autoparry.lua"), [Text.Encoding]::UTF8)
$loader = [IO.File]::ReadAllText((Join-Path $raiz "loader.lua"), [Text.Encoding]::UTF8)

$literales = "__FUENTE_MAIN = [==[`n" + $main + "`n]==]`n" +
             "__FUENTE_MOTOR = [==[`n" + $motor + "`n]==]`n"

$casoA = $literales + @'
rawset(game, "HttpGet", function() return "404: Not Found" end)
request = function(tabla)
	if tostring(tabla.Url):find("autoparry", 1, true) then
		return { Body = __FUENTE_MOTOR }
	end
	return { Body = __FUENTE_MAIN }
end
local ok, err = pcall(function()
'@ + "`n" + $loader + @'
end)
assert(ok, "el loader fallo con fallback disponible: " .. tostring(err))
assert(_G.Brotherhood ~= nil, "la GUI no se construyo tras el fallback")
assert(_G.Brotherhood.parry ~= nil, "el motor de parry no se monto tras el fallback")
print("[TEST] A OK: 404 -> fallback request -> GUI + motor cargados")
'@

$casoB = $literales + @'
rawset(game, "HttpGet", function() return "404: Not Found" end)
request = function() return { Body = "" } end
http_request = function() return nil end
local ok, err = pcall(function()
'@ + "`n" + $loader + @'
end)
assert(not ok, "el loader debio abortar")
local texto = tostring(err)
assert(texto:find("descarga fallida") ~= nil, "mensaje inesperado: " .. texto)
print("[TEST] B OK: sin red -> error controlado (" .. texto .. ")")
'@

foreach ($caso in @(@{ nombre = "A"; codigo = $casoA }, @{ nombre = "B"; codigo = $casoB })) {
    $archivo = Join-Path $env:TEMP ("brotherhood-loadertest-" + $caso.nombre + ".lua")
    [IO.File]::WriteAllText($archivo, $mock + "`n" + $caso.codigo, (New-Object Text.UTF8Encoding($false)))
    Write-Host ("--- caso " + $caso.nombre + " ---")
    & $luau $archivo
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
