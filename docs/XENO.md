# Compatibilidad con Xeno

Documento de referencia: qué funciones usa Brotherhood, cuáles se han verificado y
cuáles se evitan a propósito.

## Funciones utilizadas

| Funcion | Uso en Brotherhood | Si no existe |
|---|---|---|
| `loadstring(fuente, nombre)` | compilar `src/main.lua` en el loader | el loader aborta con mensaje claro |
| `game:HttpGet(url)` | metodo principal de descarga | pasa a `request` |
| `request({Url=..,Method="GET"})` | respaldo UNC de descarga | pasa a `http_request` |
| `http_request({...})` | segundo respaldo | aborta con error controlado |
| `gethui()` | contenedor de la GUI | `CoreGui` |
| `task.spawn` / `task.wait` / `task.delay` | hilo propio para no bloquear el runner | — (Luau estandar) |
| `TweenService` | todas las animaciones | — (servicio del juego) |
| `UserInputService` | arrastre, atajo RightShift, sliders | — (servicio del juego) |
| `identifyexecutor()` | linea de diagnostico | muestra "Desconocido" |
| `setclipboard(texto)` | boton "Copiar enlace" | avisa de que no esta disponible |
| `_G` | publicar `_G.Brotherhood` y `_G.AutoParry` | — |

Todas las opcionales se comprueban con `typeof(...) == "function"` antes de usarse y
se invocan dentro de `pcall`. Ninguna se da por hecha.

## Funciones evitadas a proposito

| Funcion | Motivo |
|---|---|
| `Drawing` | no verificada en Xeno; la UI se construye solo con `ScreenGui` |
| `setthreadidentity` / `getthreadidentity` | Xeno no aplica identidad de Roblox al hilo del runner |
| `syn.*`, `syn.protect_gui` | API de otro ejecutor, no disponible |
| `hookfunction`, `hookmetamethod` | innecesarias para una GUI y sensibles a la version |
| `getconnections`, `firesignal` | sin uso en esta interfaz |
| `protect_gui` | sin verificar; se sustituye por la cascada de contenedores |

## Dos restricciones reales del entorno

1. **El hilo del runner no soporta ceder (yield).**
   Por eso `loader.lua` ejecuta la interfaz dentro de `task.spawn`, y todo el trabajo
   con esperas ocurre en ese hilo aparte. La alternativa (ejecutar directamente)
   congela o rompe la carga.

2. **El hilo del runner no tiene identidad de Roblox.**
   Por eso el contenedor de la GUI se resuelve en cascada:

   ```
   gethui()  ->  CoreGui  ->  PlayerGui
   ```

   Cada intento va en `pcall` y se comprueba que el `Parent` se asigno de verdad.
   La pestana **Info** muestra qué contenedor se uso.

## Checklist de prueba manual en Xeno

No se puede ejecutar Xeno desde este entorno, así que la última milla es tuya:

1. Abre Roblox y entra a un juego cualquiera.
2. Inyecta Xeno y abre su consola.
3. Pega el comando del README y ejecuta.
4. En la consola deben aparecer 6 lineas de diagnostico:
   ```
   [Brotherhood] ejecutor:    Xeno
   [Brotherhood] descarga via: game:HttpGet
   [Brotherhood] bytes:       <n>
   [Brotherhood] loadstring:   true
   [Brotherhood] gethui:       true
   [Brotherhood] setclipboard: true
   ```
5. Comprueba en la interfaz:
   - [ ] Aparece la ventana centrada y la notificacion de carga.
   - [ ] Arrastrar la ventana funciona.
   - [ ] Las 4 pestanas cambian de pagina con animacion.
   - [ ] El toggle "Activar Auto Parry" cambia de color y actualiza "Estado:".
   - [ ] Los sliders se arrastran y muestran el valor.
   - [ ] **RightShift** oculta y muestra la ventana.
   - [ ] El boton X cierra con animacion.
   - [ ] En **Info**, el ejecutor dice `Xeno` y el contenedor es `gethui()`.

### Si algo falla

| Sintoma | Causa probable | Solucion |
|---|---|---|
| `404: Not Found` en consola | repo privado o rama distinta | el repo debe ser publico y la rama `main` |
| `sin metodos de descarga disponibles` | el ejecutor no expone HTTP | actualizar Xeno |
| La ventana no aparece | contenedor de GUI denegado | mira la pestana Info; si dice `PlayerGui`, revisa que `gethui` exista |
| Se queda la version anterior | cache de GitHub | subir `VERSION` en `loader.lua` |
| `error en ejecucion: ...` | fallo concreto | el mensaje se muestra en notificacion y consola |

## Pruebas automatizadas ya ejecutadas

| Prueba | Resultado |
|---|---|
| Compilacion Luau de `loader.lua` | OK |
| Compilacion Luau de `src/main.lua` | OK |
| GUI aislada con mock (21 asserts, 103 nodos) | OK |
| Loader de punta a punta (`HttpGet` -> `loadstring` -> GUI) | OK |
| Fallback 404 -> `request` | OK |
| Sin red -> error controlado | OK |

Lo que **no** cubren estas pruebas: el renderizado real de Roblox y las particularidades
del inyector de Xeno. Eso solo se valida con el checklist de arriba.
