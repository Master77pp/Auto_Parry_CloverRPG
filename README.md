# Brotherhood

Interfaz y motor de **Auto Parry** para el ejecutor **Xeno** (Windows), servidos desde
este repositorio.

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
├── loader.lua              # bootstrap: descarga, compila y ejecuta (hilo propio)
├── src/
│   ├── main.lua            # interfaz (ventana, 5 pestanas, diagnostico)
│   └── autoparry.lua       # motor de deteccion, tiempos y pulsacion de F
├── docs/
│   ├── XENO.md             # matriz de compatibilidad y checklist manual
│   └── CALIBRACION.md      # como capturar los datos reales de lobo y Dire Wolf
├── tools/
│   ├── mock-roblox.lua         # mock de las APIs de Roblox
│   ├── check.lua               # 24 comprobaciones de la interfaz
│   ├── check-parry.lua         # 173 comprobaciones del motor
│   ├── run-test.ps1            # interfaz aislada
│   ├── run-parry-test.ps1      # motor con enemigos y animaciones simulados
│   ├── run-loader-test.ps1     # loader de punta a punta
│   └── run-loader-errors.ps1   # 404 y fallback de descarga
├── .gitignore
└── README.md
```

## Que incluye la interfaz

- Ventana arrastrable, con animacion de entrada y de cierre.
- Barra lateral con 5 pestanas: **Principal**, **Parry**, **Ajustes**, **Visuales**,
  **Info**.
- Componentes: `toggle`, `slider`, `boton`, textos, notificaciones en cascada.
- Animaciones con `TweenService`, escalado segun el viewport.
- Atajo **RightShift** para mostrar u ocultar.
- API publica `_G.Brotherhood` (`parry`, `activarParry`, `captura`) y compatibilidad
  conservada con `_G.AutoParry` (`register` y `setEnabled`).

## Auto Parry: como funciona

El motor no contiene **ni un solo AnimationId ni un tiempo de ataque escrito a mano**.
Todo sale de datos del juego en tiempo de ejecucion:

1. **Deteccion de enemigos.** Se buscan `Model` con `Humanoid` cuyo nombre coincide con
   un perfil (`Wolf`/`Lobo` o `Dire Wolf`). `Dire Wolf` tiene prioridad sobre `Wolf`
   para que nunca herede el perfil equivocado.
2. **Deteccion de ataque.** Se escucha `Animator.AnimationPlayed`. Una animacion es
   ataque si su nombre/ID contiene palabras de ataque (`attack`, `bite`, `claw`,
   `lunge`, `maul`, `pounce`...) y no contiene palabras de movimiento (`idle`, `walk`,
   `run`, `howl`, `death`...). Caminar o aullar no dispara nada.
3. **Estimacion del impacto.** `impacto = duracion_real_del_track × porcentaje`
   (50 % por defecto, ajustable por enemigo) o un `impactoMs` calibrado a mano. La
   pestana Parry muestra de donde sale cada tiempo (`estimado` o `calibrado`).
4. **Ejecucion.** Al llegar al impacto se pulsa `F` durante 60 ms (parry, no bloqueo
   mantenido). Orden de intentos: `keypress`/`keyrelease` → `VirtualInputManager`.
   Si ninguno funciona, el evento lo dice: `fallo de entrada`.
5. **Filtros antes de pulsar.** Motor activo, arma equipada (se puede desactivar),
   enemigo dentro de alcance, personaje en un estado que permita bloquear y cooldown
   por enemigo. Sin ataque real no se pulsa nada.
6. **Verificacion honesta.** Se observa `Humanoid.HealthChanged` durante 0,9 s. Si
   baja la vida: `fallo (recibiste dano)`. Si no baja: `probable exito (sin dano)`.
   Nunca se afirma "exito" a secas.

### Lo que el motor NO hace (todavia)

- No conoce los nombres reales de las animaciones de Clover RPG ni sus tiempos.
  Esos datos no se han podido capturar en este entorno.
- No tiene ataques marcados como no bloqueables. El mecanismo existe
  (`ataquesNoBloqueables` en cada perfil), pero la lista está vacía a propósito
  hasta capturar datos reales.
- No distingue varios ataques distintos del mismo enemigo con tiempos propios; usa un
  porcentaje por perfil. Cuando se capturen los nombres, se pueden declarar patrones y
  tiempos por ataque.

## Calibrar con datos reales

El procedimiento completo está en **[docs/CALIBRACION.md](docs/CALIBRACION.md)**. En
resumen:

1. Carga el script y ve a Hunting Ground (junto a Kamo).
2. En la pestana **Parry**, deja el motor **apagado** y pulsa **Redetectar enemigos**.
3. Déjate atacar varias veces. El registro anota nombre real, `AnimationId`, duración y
   clasificación de cada animación.
4. Pulsa **Copiar captura (calibrar)** y guarda el texto.
5. Repite junto al **Dire Wolf**, probando sus distintos ataques y anotando cuáles se
   pueden bloquear.
6. Con esa captura se rellenan `patronesAnimacion`, `impactoMs` y
   `ataquesNoBloqueables` de cada perfil.

## Publicar una actualizacion

1. Edita `src/main.lua` y/o `src/autoparry.lua`.
2. Sube `VERSION` en `loader.lua` y en `src/main.lua` (por ejemplo `2.2.0` -> `2.3.0`).
3. Commit y push.

El parametro `?v=VERSION` evita que la cache de GitHub (~5 minutos) sirva el archivo
viejo.

## Pruebas locales

No necesitas Roblox ni Xeno: las pruebas usan el compilador oficial de Luau y un mock
de las APIs del juego.

```powershell
powershell -ExecutionPolicy Bypass -File tools\run-parry-test.ps1
powershell -ExecutionPolicy Bypass -File tools\run-test.ps1
powershell -ExecutionPolicy Bypass -File tools\run-loader-test.ps1
powershell -ExecutionPolicy Bypass -File tools\run-loader-errors.ps1
```

| Suite | Cobertura | Resultado actual |
|---|---|---|
| `run-parry-test.ps1` | deteccion, tiempos, cooldown, arma, alcance, perfiles, no bloqueable, verificacion, captura | **173 comprobaciones OK** |
| `run-test.ps1` | interfaz aislada, 5 pestanas, API publica | **24 comprobaciones, 171 nodos OK** |
| `run-loader-test.ps1` | descarga -> modulos -> `loadstring` -> GUI | **OK** |
| `run-loader-errors.ps1` | 404 -> `request`; sin red -> error controlado | **OK** |

Estas pruebas demuestran la **logica** con datos simulados. No demuestran que el parry
funcione en Clover RPG: eso exige el checklist manual de `docs/XENO.md` y una captura
real.

## Aviso

Los ejecutores y la automatizacion van contra los Terminos de Servicio de Roblox y
pueden provocar el baneo de la cuenta. Uso bajo tu propia responsabilidad.
