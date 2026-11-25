# Arquitectura

```
addons/papo_engine/        PAPO-GAME-ENGINE (reutilizable, ver su README)
  core/   PapoSave, PapoConfig, PapoFormat
  economy/ PapoWallet, PapoInventory, PapoUpgrades, PapoBoosts, PapoOffline
  progression/ PapoLevels      workers/ PapoRoster
  missions/ PapoMissions       events/ PapoEvents
  ads/    PapoAds (autoload AdManager)   ui/ PapoUI (tema, filas, animaciones)
config/game_config.json    límites de anuncios (10/día), offline 8 h, evento forzado
scripts/autoload/
  game_data.gd   datos: materiales, niveles, mejoras, trabajadores, zonas, logros,
                 misiones, eventos, cosméticos, recompensas de anuncios
  game_state.gd  estado del juego sobre el motor; guardado v2 (lee v1)
  asset_lib.gd   carga GLB de assets/models/ o primitivas low poly
scripts/world/  world.gd (zonas, basura, suciedad, eventos, cámara) · player.gd · worker.gd
scripts/ui/     ui.gd (HUD + 8 menús + diálogos en cola) · joystick.gd
tests/smoke.gd  prueba integral (se activa con `-- --smoke`)
.github/workflows/build.yml  prueba → web (Pages) + APK debug
```

Flujo: autoloads GameData → AdManager → GameState → AssetLib; escena `scenes/main.tscn` = World,
que crea Player, Workers y GameUI por código. Señales de GameState refrescan mundo/UI.

Nuevo juego con el motor: copiar `addons/papo_engine`, crear su `game_data.gd`/`game_state.gd`
y su mundo; los sistemas (ads, misiones, offline, guardado, UI) se configuran con datos.
