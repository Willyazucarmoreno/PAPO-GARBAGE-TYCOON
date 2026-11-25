# PAPO Garbage Tycoon

Simulador 3D low poly de recolección de basura, reciclaje y gestión empresarial.
Android (vertical) y navegador. Godot 4.3 + GDScript. Gratis, sin conexión
(excepto anuncios voluntarios) y con guardado automático.

## Cómo se juega
1. Arrastra el dedo por la pantalla: aparece un joystick y el personaje camina.
2. Acércate a la basura: se recoge sola por proximidad.
3. Pisa el círculo verde **VENDER** del centro de reciclaje.
4. Compra mejoras y vehículos, contrata personal y desbloquea territorios.

## Contenido actual (v0.1)
| Sistema | Estado |
|---|---|
| 12 materiales ($1 papel … $100 oro) | Hecho |
| Dinero + EcoCoins (sin valor real) | Hecho |
| 14 niveles: bolsa → mochila → carrito → bicicleta → triciclo → moto → camioneta → furgoneta → camión pequeño → camión recolector → centro de reciclaje → planta industrial → empresa nacional → empresa internacional | Hecho |
| Mejoras: velocidad, capacidad, precio, almacenamiento, producción, automatización | Hecho |
| 7 trabajadores (recolector, conductor, clasificador, operador, supervisor, gerente, robot) con niveles 1-10 | Hecho |
| 12 territorios desbloqueables con decoración propia | Hecho |
| 19 logros/misiones con premio en EcoCoins | Hecho |
| Anuncios recompensados voluntarios (simulados en web, AdMob en Android) | Interfaz lista, falta plugin AdMob |
| Guardado automático cada 10 s + ganancias offline (máx. 8 h) | Hecho |
| Modelos KayKit | Carga automática al copiarlos en `assets/models/` (ver `docs/ASSETS.md`) |

## Probar
- **Navegador (tablet):** cada push a `main` publica el juego en GitHub Pages:
  `https://<usuario>.github.io/PAPO-GARBAGE-TYCOON/`
- **APK Android:** pestaña *Actions* → última ejecución → artefacto
  `PAPO-Garbage-Tycoon-APK` (APK de depuración firmado, instalable directamente).
- **Codespaces:** `.devcontainer/` instala Godot 4.3 y las plantillas.
  `make web` exporta y `make serve` lo sirve en el puerto 8060.

## Estructura
```
scripts/autoload/game_data.gd   balance: precios, niveles, trabajadores, zonas, logros
scripts/autoload/game_state.gd  economía, guardado, offline, recompensas
scripts/autoload/ad_manager.gd  anuncios recompensados (AdMob / simulado)
scripts/autoload/asset_lib.gd   carga GLB de KayKit o geometría low poly de reserva
scripts/world/                  mundo, jugador, trabajadores
scripts/ui/                     HUD, menús y joystick táctil
tests/smoke.gd                  prueba automática (se ejecuta en CI)
```

## Licencias
Código: MIT (ver `LICENSE`). Recursos de terceros: ver `CREDITS.md`.
