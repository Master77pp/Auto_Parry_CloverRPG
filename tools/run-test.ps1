# Herramienta de prueba local
# Concatena mock + interfaz + asserts y lo ejecuta con el Luau oficial.
# Uso:  powershell -ExecutionPolicy Bypass -File tools\run-test.ps1

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

$archivos = @(
    (Join-Path $raiz "tools\mock-roblox.lua"),
    (Join-Path $raiz "src\main.lua"),
    (Join-Path $raiz "tools\check.lua")
)

$destinoRun = Join-Path $env:TEMP "brotherhood-test.lua"
$contenido = ($archivos | ForEach-Object { Get-Content -Path $_ -Raw -Encoding UTF8 }) -join "`n"
[IO.File]::WriteAllText($destinoRun, $contenido, (New-Object Text.UTF8Encoding($false)))

& $luau $destinoRun
exit $LASTEXITCODE
