# Prueba de punta a punta del loader (sin red).
# Simula game:HttpGet devolviendo los archivos reales del repo y deja que
# loader.lua haga su trabajo: descarga -> modulos -> loadstring -> ejecucion.

$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $PSScriptRoot
$luau = Join-Path $env:TEMP "luau\luau.exe"

if (-not (Test-Path $luau)) {
    $zip = Join-Path $env:TEMP "luau.zip"
    $destino = Join-Path $env:TEMP "luau"
    Invoke-WebRequest -Uri "https://github.com/roblox/luau/releases/latest/download/luau-windows.zip" -OutFile $zip -UseBasicParsing
    Expand-Archive -Path $zip -DestinationPath $destino -Force
}

$mock   = [IO.File]::ReadAllText((Join-Path $raiz "tools\mock-roblox.lua"), [Text.Encoding]::UTF8)
$main   = [IO.File]::ReadAllText((Join-Path $raiz "src\main.lua"), [Text.Encoding]::UTF8)
$motor  = [IO.File]::ReadAllText((Join-Path $raiz "src\autoparry.lua"), [Text.Encoding]::UTF8)
$loader = [IO.File]::ReadAllText((Join-Path $raiz "loader.lua"), [Text.Encoding]::UTF8)
$check  = [IO.File]::ReadAllText((Join-Path $raiz "tools\check.lua"), [Text.Encoding]::UTF8)

foreach ($texto in @($main, $motor)) {
    if ($texto.Contains("]==]")) {
        throw "Un archivo fuente contiene ']==]' y rompe el delimitador del test"
    }
}

$stub = "__FUENTE_MAIN = [==[`n" + $main + "`n]==]`n" +
        "__FUENTE_MOTOR = [==[`n" + $motor + "`n]==]`n" +
        @'
rawset(game, "HttpGet", function(_, url)
	if tostring(url):find("autoparry", 1, true) then
		return __FUENTE_MOTOR
	end
	return __FUENTE_MAIN
end)
'@

$destinoRun = Join-Path $env:TEMP "brotherhood-loader-test.lua"
$contenido = $mock + "`n" + $stub + "`n" + $loader + "`n" + $check
[IO.File]::WriteAllText($destinoRun, $contenido, (New-Object Text.UTF8Encoding($false)))

& $luau $destinoRun
exit $LASTEXITCODE
