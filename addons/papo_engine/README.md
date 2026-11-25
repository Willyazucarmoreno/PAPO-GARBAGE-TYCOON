# PAPO-GAME-ENGINE (addon Godot 4)

Núcleo reutilizable para los juegos PAPO Tycoon. Sin dependencias del juego:
todo se configura con datos (diccionarios/JSON).

| Módulo | Clase | Uso |
|---|---|---|
| Guardado | `PapoSave` | JSON atómico + `.bak` |
| Configuración/fechas | `PapoConfig` | JSON con valores por defecto, claves de día/semana |
| Formato | `PapoFormat` | 1.2K, 3.4M, tiempos |
| Economía | `PapoWallet` | monedas virtuales |
| Inventario | `PapoInventory` | objetos por índice con capacidad |
| Mejoras | `PapoUpgrades` | niveles y coste exponencial |
| Potenciadores | `PapoBoosts` | multiplicadores temporales |
| Offline | `PapoOffline` | ganancias idle con tope |
| Niveles | `PapoLevels` | XP y nivel |
| Trabajadores | `PapoRoster` | plantilla, costes, temporales |
| Misiones | `PapoMissions` | diarias/semanales por fecha |
| Eventos | `PapoEvents` | eventos de calendario |
| Publicidad | `PapoAds` | recompensados voluntarios, límite diario, anti-duplicado, consentimiento |
| Interfaz/animación | `PapoUI` | tema táctil, filas, pop, textos flotantes |

Reutilizar: copia `addons/papo_engine/` a otro proyecto Godot 4.3+
(o sepáralo en el repo PAPO-GAME-ENGINE con `git subtree split -P addons/papo_engine`).
