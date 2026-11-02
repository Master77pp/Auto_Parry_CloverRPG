# Prueba de punta a punta del loader (sin red).
# Simula game:HttpGet devolviendo el contenido real de src/main.lua y deja que
# loader.lua haga su trabajo: descarga -> loadstring -> ejecucion.

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
$fuente = [IO.File]::ReadAllText((Join-Path $raiz "src\main.lua"), [Text.Encoding]::UTF8)
$loader = [IO.File]::ReadAllText((Join-Path $raiz "loader.lua"), [Text.Encoding]::UTF8)
$check  = [IO.File]::ReadAllText((Join-Path $raiz "tools\check.lua"), [Text.Encoding]::UTF8)

if ($fuente.Contains("]==]")) {
    throw "src/main.lua contiene ']==]' y rompe el delimitador del test"
}

$stub = "__FUENTE = [==[`n" + $fuente + "`n]==]`n" +
        "rawset(game, `"HttpGet`", function() return __FUENTE end)`n" +
        "rawset(game, `"HttpGetAsync`", function() return __FUENTE end)`n"

$destinoRun = Join-Path $env:TEMP "brotherhood-loader-test.lua"
$contenido = $mock + "`n" + $stub + "`n" + $loader + "`n" + $check
[IO.File]::WriteAllText($destinoRun, $contenido, (New-Object Text.UTF8Encoding($false)))

& $luau $destinoRun
exit $LASTEXITCODE
