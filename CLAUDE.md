# CLAUDE.md — instrucciones permanentes (leer primero)

Proyecto: PAPO Garbage Tycoon (Godot 4.3, GDScript, Android vertical + web).
Repo: Willyazucarmoreno/PAPO-GARBAGE-TYCOON (rama `main`). NO tocar PAPO-ANIMATION.

## Ahorro de tokens (obligatorio)
- Recuperar contexto SOLO con: PROGRESO.md, PENDIENTES.md, ARQUITECTURA.md, ERRORES.md.
- No leer archivos que no cambian ni analizar todo el repo. Usar `grep -n` y leer rangos.
- Respuestas breves, en español. No pegar bloques grandes de código en el chat.
- Cambios pequeños y verificables; no regenerar sistemas que funcionan.
- No cargar binarios/modelos/imágenes en contexto (salvo capturas de verificación pequeñas).

## Reglas
- Código reutilizable → `addons/papo_engine/` (PAPO-GAME-ENGINE, sin dependencias del juego).
- Código/datos del juego → `scripts/` y `config/game_config.json`.
- Balance en `scripts/autoload/game_data.gd`. Anuncios: solo recompensados voluntarios, IDs de prueba.
- No afirmar "terminado" sin pasar la prueba: `make test` (o tests/smoke.gd, imprime `SMOKE OK`).
- No publicar apps, contratar servicios ni pagar sin autorización.
- Al terminar sesión: actualizar PROGRESO.md / PENDIENTES.md / ERRORES.md, commit y push a `main`.

## Comandos
- Prueba: `godot --headless --path . -- --smoke` (CI lo ejecuta en cada push).
- Capturas: `xvfb-run godot --path . --rendering-driver opengl3 -- --smoke --shots=DIR`.
- Web: `make web` · APK: GitHub Actions (artefacto `PAPO-Garbage-Tycoon-APK`).
