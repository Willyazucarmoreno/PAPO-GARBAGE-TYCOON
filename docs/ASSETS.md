# Cómo añadir los modelos KayKit (y otros GLB)

El juego busca archivos en `assets/models/` con estos nombres. Si existe el
archivo lo usa; si no, dibuja la versión low poly procedural. No hace falta
tocar código.

| Archivo (`.glb` o `.gltf`) | Sugerencia de origen |
|---|---|
| `player` | KayKit Adventurers / Character Pack (personaje con animaciones `Idle`, `Walking_A`, `Running_A`) |
| `worker_recolector`, `worker_clasificador`, `worker_operador`, `worker_supervisor`, `worker_gerente` | Personajes KayKit con distinto color |
| `worker_conductor` | Vehículo KayKit City Builder (camioneta) |
| `worker_robot` | KayKit Space Base (robot) |
| `house_1`, `house_2`, `house_3` | KayKit City Builder Bits / Medieval houses |
| `tree_1`, `tree_2` | KayKit Forest / Nature |
| `car` | KayKit City Builder (car) |
| `recycling_center` | Edificio de KayKit City Builder |
| `cart`, `bicycle`, `tricycle`, `motorcycle`, `pickup`, `van`, `small_truck`, `garbage_truck` | Vehículos KayKit / Kenney Car Kit / Quaternius |

Pasos:
1. Descarga el paquete gratuito (itch.io permite precio $0).
2. Copia el `.glb` (o `.gltf` + `.bin` + texturas) a `assets/models/` con el nombre de la tabla.
3. Copia la licencia del paquete a `assets/licenses/` y añade una fila en `CREDITS.md`.
4. Haz commit y push: GitHub Actions recompila web y APK.

Si un modelo sale demasiado grande o girado, se puede envolver en una escena
`.tscn` con el mismo nombre (p. ej. `assets/models/house_1.tscn`) ajustando
escala y rotación; el cargador también acepta `.tscn`.
