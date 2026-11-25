# Progreso (actualizado 2026-11-25, v0.2)

Verificado con `tests/smoke.gd` (SMOKE OK) + capturas reales + CI (web y APK compilan).

| Fase | Estado |
|---|---|
| 1 Jugable: barrio, personaje animado (procedural), joystick, basura, recogida, mochila, venta, dinero, mejoras, guardado | ✅ |
| 2 Expansión: 13 vehículos/niveles, 7 trabajadores, automatización, 12 materiales, 12 territorios | ✅ |
| 3 Empresa: misiones diarias/semanales, 19 logros, offline 8 h (pasivo + trabajadores), nivel/XP | ✅ (plantas de reciclaje físicas: pendiente) |
| 4 Monetización: 9 recompensas por anuncio, límite 10/día (config), anti-duplicado, consentimiento propio, solo con confirmación | ✅ simulado · ❌ plugin AdMob real |
| 5 Contenido: eventos (Halloween, Navidad, Año Nuevo, Día de la Tierra), personalización (uniforme, gorra, pintura), limpieza visual de zonas, recompensa diaria | ✅ parcial (sin modelos KayKit, sin sonido) |
| 6 Publicación | ❌ |

Motor PAPO-GAME-ENGINE: `addons/papo_engine/` (14 módulos). Juego usa todos.
