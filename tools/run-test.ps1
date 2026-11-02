# Prueba de la interfaz aislada (sin loader ni red).
# Inyecta el modulo autoparry como lo haria el loader y ejecuta la UI completa.

$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $PSScriptRoot
$luau = Join-Path $env:TEMP "luau\luau.exe"

if (-not (Test-Path $luau)) {
    Write-Host "Descargando Luau..." -ForegroundColor Yellow
    $zip = Join-Path $env:TEMP "luau.zip"
    $destino = Join-Path $env:TEMP "luau"
    Invoke-WebRequest -Uri "https://github.com/roblox/luau/releases/latest/download/luau-windows.zip" -OutFile $zip -UseBasicParsing
    Expand-Archive -Path $zip -DestinationPath $destino -Force
}

$mock  = [IO.File]::ReadAllText((Join-Path $raiz "tools\mock-roblox.lua"), [Text.Encoding]::UTF8)
$motor = [IO.File]::ReadAllText((Join-Path $raiz "src\autoparry.lua"), [Text.Encoding]::UTF8)
$main  = [IO.File]::ReadAllText((Join-Path $raiz "src\main.lua"), [Text.Encoding]::UTF8)
$check = [IO.File]::ReadAllText((Join-Path $raiz "tools\check.lua"), [Text.Encoding]::UTF8)

if ($main.Contains("]==]") -or $motor.Contains("]==]")) {
    throw "Un archivo fuente contiene ']==]' y rompe el delimitador del test"
}

$inyeccion = "_G.__BH_MODULES = { autoparry = [==[`n" + $motor + "`n]==] }`n"

$destinoRun = Join-Path $env:TEMP "brotherhood-test.lua"
$contenido = $mock + "`n" + $inyeccion + $main + "`n" + $check
[IO.File]::WriteAllText($destinoRun, $contenido, (New-Object Text.UTF8Encoding($false)))

& $luau $destinoRun
exit $LASTEXITCODE
