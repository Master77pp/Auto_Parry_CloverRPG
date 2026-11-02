# Auto Parry — Clover RPG

Bootstrap loader para ejecutar el script desde GitHub con un único enlace estable.

## Uso

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Master77pp/Auto_Parry_CloverRPG/main/loader.lua"))()
```

Ese enlace **no cambia nunca**. Las actualizaciones se publican dentro del repo.

## Estructura

```
.
├── loader.lua          # bootstrap con URL estable (VERSION + ?v= para la caché)
├── src/
│   └── main.lua        # punto de entrada de la lógica
├── .gitignore
└── README.md
```

## Cómo publicar una actualización

1. Edita lo que haga falta en `src/`.
2. Sube `VERSION` en `loader.lua` (por ejemplo `1.0.0` → `1.0.1`).
3. Commit y push.

```powershell
git add -A
git commit -m "feat: descripcion del cambio"
git push
```

El `?v=VERSION` fuerza a GitHub a servir la versión nueva en lugar de la cacheada.

## Diagnóstico rápido

| Síntoma | Causa habitual |
|---|---|
| `404: Not Found` | Repo privado, rama equivocada o ruta mal escrita |
| Sigue cargando la versión vieja | No subiste `VERSION` en `loader.lua` |
| `Error de sintaxis` | El archivo de `src/` tiene un error de Lua/Luau |

## Aviso

El uso de ejecutores y automatización va contra los Términos de Servicio de Roblox
y puede provocar el baneo de la cuenta. Uso bajo tu propia responsabilidad.
