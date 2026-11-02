# Pruebas del motor de Auto Parry con enemigos y animaciones simulados.
# No sustituye a una prueba real en Clover RPG: valida la logica de deteccion,
# temporizacion, cooldown, arma, alcance y perfiles por enemigo.

$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $PSScriptRoot
$luau = Join-Path $env:TEMP "luau\luau.exe"

if (-not (Test-Path $luau)) {
    $zip = Join-Path $env:TEMP "luau.zip"
    $destino = Join-Path $env:TEMP "luau"
    Invoke-WebRequest -Uri "https://github.com/roblox/luau/releases/latest/download/luau-windows.zip" -OutFile $zip -UseBasicParsing
    Expand-Archive -Path $zip -DestinationPath $destino -Force
}

$mock  = [IO.File]::ReadAllText((Join-Path $raiz "tools\mock-roblox.lua"), [Text.Encoding]::UTF8)
$motor = [IO.File]::ReadAllText((Join-Path $raiz "src\autoparry.lua"), [Text.Encoding]::UTF8)
$check = [IO.File]::ReadAllText((Join-Path $raiz "tools\check-parry.lua"), [Text.Encoding]::UTF8)

$destinoRun = Join-Path $env:TEMP "brotherhood-parry-test.lua"
$contenido = $mock + "`n" +
             "local AutoParry = (function()`n" + $motor + "`nend)()`n" +
             $check

[IO.File]::WriteAllText($destinoRun, $contenido, (New-Object Text.UTF8Encoding($false)))

& $luau $destinoRun
exit $LASTEXITCODE
