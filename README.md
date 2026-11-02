# Brotherhood

Interfaz para el ejecutor **Xeno** (Windows), servida desde este repositorio.

> El repositorio conserva su nombre original (`Auto_Parry_CloverRPG`) por indicación
> expresa; el proyecto que contiene es Brotherhood.

## Comando de carga

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Master77pp/Auto_Parry_CloverRPG/main/loader.lua"))()
```

Pégalo en la consola de Xeno con el juego ya inyectado. Ese enlace no cambia nunca:
las actualizaciones se publican dentro del repo.

## Estructura

```
.
├── loader.lua          # bootstrap: descarga, compila y ejecuta (hilo propio)
├── src/
│   └── main.lua        # interfaz completa (ventana, pestanas, componentes)
├── docs/
│   └── XENO.md         # matriz de compatibilidad y checklist de pruebas
├── tools/
│   ├── mock-roblox.lua     # mock de las APIs de Roblox para probar sin juego
│   ├── check.lua           # 21 comprobaciones automaticas
│   ├── run-test.ps1        # prueba la interfaz aislada
│   ├── run-loader-test.ps1 # prueba el loader de punta a punta
│   └── run-loader-errors.ps1 # prueba 404 y fallback de descarga
├── .gitignore
└── README.md
```

## Que incluye la interfaz

- Ventana arrastrable, con animacion de entrada y de cierre.
- Barra lateral con 4 pestanas: **Principal**, **Ajustes**, **Visuales**, **Info**.
- Componentes: `toggle`, `slider`, `boton`, textos, notificaciones en cascada.
- Animaciones con `TweenService` (hover, indicador de pestana, perilla del toggle).
- Escalado automatico segun el tamano del viewport.
- Atajo **RightShift** para mostrar u ocultar.
- API publica `_G.Brotherhood` y compatibilidad conservada con `_G.AutoParry`
  (`register` y `setEnabled` siguen existiendo y funcionando).

## Publicar una actualizacion

1. Edita `src/main.lua`.
2. Sube `VERSION` en `loader.lua` (por ejemplo `2.0.0` -> `2.1.0`).
3. Commit y push.

El parametro `?v=VERSION` evita que la cache de GitHub (~5 minutos) sirva el archivo viejo.

## Pruebas locales

No necesitas Roblox ni Xeno: las pruebas usan el compilador oficial de Luau y un mock
de las APIs del juego.

```powershell
powershell -ExecutionPolicy Bypass -File tools\run-test.ps1
powershell -ExecutionPolicy Bypass -File tools\run-loader-test.ps1
powershell -ExecutionPolicy Bypass -File tools\run-loader-errors.ps1
```

`run-test.ps1` descarga Luau automaticamente la primera vez.

## Aviso

Los ejecutores y la automatizacion van contra los Terminos de Servicio de Roblox y
pueden provocar el baneo de la cuenta. Uso bajo tu propia responsabilidad.
