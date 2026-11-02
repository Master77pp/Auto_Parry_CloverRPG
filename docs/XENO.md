# Compatibilidad con Xeno

Documento de referencia: qué funciones usa Brotherhood, cuáles se han verificado y
cuáles se evitan a propósito.

## Funciones utilizadas

| Funcion | Uso en Brotherhood | Si no existe / falla |
|---|---|---|
| `loadstring(fuente, nombre)` | compilar `src/main.lua` y `src/autoparry.lua` | el loader aborta o avisa; la UI arranca sin motor |
| `game:HttpGet(url)` | metodo principal de descarga | pasa a `request` |
| `request({Url=..,Method="GET"})` | respaldo UNC de descarga | pasa a `http_request` |
| `http_request({...})` | segundo respaldo | aborta con error controlado |
| `gethui()` | contenedor de la GUI | `CoreGui` → `PlayerGui` |
| `task.spawn` / `task.wait` / `task.delay` / `task.defer` | hilos y tiempos del motor | — (Luau estandar) |
| `TweenService` | todas las animaciones | — (servicio del juego) |
| `UserInputService` | arrastre, atajo RightShift, sliders | — (servicio del juego) |
| `workspace.DescendantAdded` | detectar enemigos nuevos | queda el boton "Redetectar enemigos" |
| `Animator.AnimationPlayed` | detectar el inicio de un ataque | sin esto el enemigo no se vigila |
| `AnimationTrack.Length` | base del calculo de impacto | impacto 0 → se registra sin pulsar |
| `Humanoid.HealthChanged` | verificar si el parry evito dano | se muestrea `Humanoid.Health` como respaldo |
| `keypress` / `keyrelease` | pulsar `F` (API UNC) | pasa a `VirtualInputManager` |
| `VirtualInputManager:SendKeyEvent` | respaldo para pulsar `F` | el evento queda como `fallo de entrada` |
| `identifyexecutor()` | linea de diagnostico | muestra "Desconocido" |
| `setclipboard(texto)` | copiar enlace y captura de calibracion | imprime la captura en consola |
| `_G` | publicar `_G.Brotherhood`, `_G.AutoParry` y `_G.__BH_MODULES` | — |

Todas las opcionales se comprueban con `typeof(...) == "function"` antes de usarse y se
invocan dentro de `pcall`. Ninguna se da por hecha.

## Funciones evitadas a proposito

| Funcion | Motivo |
|---|---|
| `Drawing` | no verificada en Xeno; la UI se construye solo con `ScreenGui` |
| `setthreadidentity` / `getthreadidentity` | Xeno no aplica identidad de Roblox al hilo del runner |
| `syn.*`, `syn.protect_gui` | API de otro ejecutor, no disponible |
| `hookfunction`, `hookmetamethod` | innecesarias para este motor y sensibles a la version |
| `getconnections`, `firesignal` | sin uso; el motor usa senales publicas |
| `protect_gui` | sin verificar; se sustituye por la cascada de contenedores |

## Tres restricciones reales del entorno

1. **El hilo del runner no soporta ceder (yield).**
   Por eso `loader.lua` ejecuta la interfaz dentro de `task.spawn`, y todo el trabajo
   con esperas ocurre en ese hilo aparte.

2. **El hilo del runner no tiene identidad de Roblox.**
   Por eso el contenedor de la GUI se resuelve en cascada:

   ```
   gethui()  ->  CoreGui  ->  PlayerGui
   ```

   Cada intento va en `pcall` y se comprueba que el `Parent` se asigno de verdad.

3. **La entrada de teclado depende del ejecutor.**
   El motor intenta `keypress`/`keyrelease` y, si falla, `VirtualInputManager`. No hay
   una tercera via fiable sin APIs de ejecutor. Si ambas fallan, la pestana Parry lo
   muestra como `fallo de entrada`; no se finge que el parry se hizo.

## Checklist de prueba manual en Xeno

No se puede ejecutar Xeno desde este entorno, así que la última milla es tuya:

1. Abre Roblox y entra a Clover RPG.
2. Inyecta Xeno y abre su consola.
3. Pega el comando del README y ejecuta.
4. En la consola deben aparecer estas lineas de diagnostico:
   ```
   [Brotherhood] modulo autoparry cargado via game:HttpGet (<n> bytes)
   [Brotherhood] ejecutor:    Xeno
   [Brotherhood] descarga via: game:HttpGet
   [Brotherhood] bytes:       <n>
   [Brotherhood] loadstring:   true
   [Brotherhood] gethui:       true
   [Brotherhood] setclipboard: true
   [Brotherhood] keypress:     true|false
   [Brotherhood] modulos:      1/1
   ```
5. Comprueba en la interfaz:
   - [ ] Aparece la ventana centrada y la notificacion de carga.
   - [ ] Arrastrar la ventana funciona.
   - [ ] Las **5 pestanas** cambian de pagina con animacion.
   - [ ] El toggle "Activar Auto Parry" de **Principal** y el de **Parry** quedan
         sincronizados.
   - [ ] Los sliders se arrastran y muestran el valor.
   - [ ] **RightShift** oculta y muestra la ventana.
   - [ ] En **Info**, el ejecutor dice `Xeno` y el contenedor es `gethui()`.

### Prueba con lobos (motor apagado primero)

1. Ve a Hunting Ground, junto a Kamo, con el arma equipada.
2. Pestana **Parry** → **Redetectar enemigos**. Debe avisar de los lobos vigilados.
3. Sin activar el motor, deja que ataquen. En el registro deben aparecer sus
   animaciones con nombre, duracion y clasificacion.
4. Pulsa **Copiar captura (calibrar)** y guarda el texto.

### Prueba con lobos (motor encendido)

1. Activa **Motor activo**.
2. Deja que un lobo ataque. Debe aparecer una linea `ATK ... impacto X.XXs`.
3. Tras 0,9 s debe resolverse como `OK` (sin dano) o `FAIL` (recibiste dano).
4. Si dice `fallo de entrada`, el problema es el envio de `F`, no el tiempo.
5. Si dice `omitido (sin arma equipada)`, equipa un arma o desactiva esa exigencia.
6. Si dice `omitido (fuera de alcance)`, el modelo del lobo esta lejos; acercate.

### Prueba con el Dire Wolf

1. Repite la captura con el motor apagado y provoca **todos** sus ataques.
2. Comprueba que el registro dice `Dire Wolf`, nunca `Lobo normal`.
3. Anota que ataques se pueden bloquear y cuales exigen `Q + direccion`.
4. Con esos datos se rellenan `impactoMs` y `ataquesNoBloqueables`.

El protocolo detallado esta en **[CALIBRACION.md](CALIBRACION.md)**.

## Pruebas automatizadas ya ejecutadas

| Prueba | Resultado |
|---|---|
| Compilacion Luau de `loader.lua` | OK |
| Compilacion Luau de `src/main.lua` | OK |
| Compilacion Luau de `src/autoparry.lua` | OK |
| Motor con enemigos simulados (`run-parry-test.ps1`) | **173 comprobaciones OK** |
| GUI aislada con mock (`run-test.ps1`) | **24 comprobaciones, 171 nodos OK** |
| Loader de punta a punta (`HttpGet` → `loadstring` → GUI) | OK |
| Fallback 404 → `request` | OK |
| Sin red → error controlado | OK |

Lo que **no** cubren estas pruebas: el renderizado real, el inyector de Xeno, los
nombres reales de las animaciones de Clover RPG, sus tiempos de impacto y si `F`
bloquea o no cada ataque. Eso solo se valida con el checklist y la captura de arriba.

## Si algo falla

| Sintoma | Causa probable | Solucion |
|---|---|---|
| `404: Not Found` en consola | repo privado o rama distinta | el repo debe ser publico y la rama `main` |
| `sin metodos de descarga disponibles` | el ejecutor no expone HTTP | actualizar Xeno |
| La ventana no aparece | contenedor de GUI denegado | mira la pestana Info; si dice `PlayerGui`, revisa que `gethui` exista |
| Se queda la version anterior | cache de GitHub | subir `VERSION` en `loader.lua` y `main.lua` |
| `fallo de entrada (no se pudo pulsar F)` | `keypress` y `VirtualInputManager` bloqueados | reportarlo: hay que cambiar el adaptador de entrada |
| `omitido (cooldown)` en cada ataque | dos animaciones de ataque por golpe | subir el cooldown o filtrar el segundo patron |
| Nunca aparece `ATK` | las animaciones no contienen palabras de ataque | capturar los nombres reales y añadirlos a `patronesAnimacion` |
