# Calibracion de Auto Parry

El motor no inventa animaciones ni tiempos: los deduce de lo que el juego expone en
tiempo de ejecucion. Para pasar de "logica correcta" a "funciona en Clover RPG" hacen
falta datos reales de lobo y Dire Wolf. Esta es la lista exacta.

## Datos que necesitamos

| Dato | Por que | Como se obtiene |
|---|---|---|
| Nombre real de cada animacion de ataque | el motor clasifica por nombre/ID | `Animator.AnimationPlayed` (lo registra la pestana Parry) |
| `AnimationId` de cada ataque | evita confusiones entre ataques con nombre parecido | idem |
| Duracion (`AnimationTrack.Length`) | base del calculo de impacto | idem |
| Momento del golpe dentro de la animacion | sincronizar el parry | observacion o grabacion |
| Si `F` bloquea ese ataque | descartar ataques no bloqueables | prueba manual |
| Si el parry se registro | validar la ventana | registro de la pestana Parry |
| Arma/estilo equipado | el motor exige arma por defecto | inventario del personaje |
| Ping y FPS aproximados | explain latencia de entrada | medidor del juego/ejecutor |

## Procedimiento de captura (motor apagado)

1. Carga Brotherhood y ve a **Hunting Ground**, junto a Kamo.
2. Equipa el arma o estilo de combate con el que piensas bloquear.
3. Abre la pestana **Parry** y deja **Motor activo** en gris (apagado).
4. Pulsa **Redetectar enemigos** para que empiece a vigilar a los lobos cercanos.
5. Deja que los lobos te ataquen **5-10 veces**. No hace falta pulsar F.
6. Pulsa **Copiar captura (calibrar)**. El texto tambien se imprime en la consola.
7. Guardalo y repite el proceso junto al **Dire Wolf**, provocando sus distintos
   ataques.

Con el motor apagado no se pulsa ninguna tecla: solo se observa. Es la forma segura de
grabar sin que el script interfiera con la pelea.

### Que contiene la captura

```
Wolf | "WolfBite" | rbxassetid://123456 | 1.00s | ATAQUE (palabra clave: bite)
Wolf | "WolfWalk" | rbxassetid://789012 | 1.20s | no ataque (palabra ignorada)
```

Eso es exactamente lo que no se puede adivinar desde fuera del juego.

## Calibrar el momento del impacto

El impacto se calcula como **porcentaje de la duracion real** de la animacion. El
mismo porcentaje sirve para ataques de distinta duracion.

- Empieza en **50 %**.
- Si el golpe llega **antes** de que se pulse F (recibes dano con el parry "enviado"),
  **baja** el porcentaje (por ejemplo 40 %).
- Si el parry se pulsa **demasiado pronto** y el golpe entra despues, **sube** el
  porcentaje.
- Si conoces el fotograma exacto, graba a 60 FPS y cuenta los fotogramas desde que
  empieza la animacion hasta que baja la vida: `ms = fotogramas / 60 × 1000`.

Ajusta **Lobo** y **Dire Wolf** por separado: son sliders independientes.

**Anticipacion** compensa la latencia de entrada. Si el parry siempre sale tarde aun
con el porcentaje correcto, sube 30-60 ms. No lo uses para "arreglar" un porcentaje mal
calibrado.

El cooldown por enemigo (0,9 s por defecto) evita pulsar dos veces por el mismo ataque.
Si un ataque del Dire Wolf es multi-golpe, probablemente haya que bajarlo; avísame y lo
ajusto con datos.

## Marcar ataques no bloqueables

Cuando confirmes que un ataque **no se puede bloquear** (hay que esquivar con
`Q + direccion`), se añade su nombre a la lista del perfil en `src/autoparry.lua`:

```lua
direwolf = {
    ...
    ataquesNoBloqueables = { "NombreExactoDelAtaque" },
}
```

El motor dejara de pulsar `F` para ese ataque y lo anotara como
`NO BLOQUEABLE; usa Q + direccion`.

## Plantilla para enviar los datos

Copia y rellena una linea por ataque:

```
Enemigo:        Wolf | Dire Wolf
Animacion:      <nombre exacto de la captura>
AnimationId:    <id de la captura>
Duracion:       <segundos>
Golpe percibido:<segundos desde el inicio, o %>
Bloqueable con F: si | no | no estoy seguro
Parry exitoso:  si | no | no verificable
Arma:           <nombre>
Ping / FPS:     <ms> / <fps>
```

Si en la pestana Parry aparece `fallo de entrada (no se pudo pulsar F)` o el metodo de
tecla queda vacio, dilo: significa que Xeno no esta dejando enviar la tecla y hay que
cambiar el adaptador de entrada, no los tiempos.

## Lo que no se puede deducir solo con nombres

- Si un ataque es una finta, un multi-golpe o un area.
- Si el dano se aplica en el servidor con retraso adicional.
- Si el juego acepta `F` durante la recuperacion o solo en una ventana concreta.

Por eso la verificacion del motor es **probabilistica**: "sin dano durante la ventana"
se registra como `probable exito`, nunca como exito garantizado.
