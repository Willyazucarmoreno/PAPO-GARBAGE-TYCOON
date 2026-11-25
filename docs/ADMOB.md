# Publicidad (AdMob) — solo anuncios recompensados voluntarios

Estado: la lógica está lista (`addons/papo_engine/ads/papo_ads.gd`, límites en `config/game_config.json`).
En navegador y sin plugin se muestra un **anuncio simulado** de 4 s para probar
el flujo. Los IDs del código son los **IDs de prueba oficiales de Google**.

Recompensas: venta x2, offline x2, producción x2 (10 min), velocidad x2 (5 min),
EcoCoins, trabajador temporal, camión especial, materiales extra y diaria extra.
Máximo 10 al día y 30 s de espera (configurable). La recompensa solo se entrega
cuando el SDK confirma; cada solicitud se recompensa una sola vez. Nunca se muestran anuncios sin que el
jugador pulse un botón.

## Para activar anuncios reales (requiere tu cuenta, gratuita)
1. Crea una cuenta en AdMob y una app Android → obtén App ID y un bloque
   "Recompensado".
2. Instala un plugin de AdMob para Godot 4 compatible con Android
   (p. ej. *Poing Studios godot-admob-plugin*) siguiendo sus instrucciones;
   necesita `gradle_build/use_gradle_build=true` en `export_presets.cfg`.
3. Sustituye `app_id` y `rewarded_id` en `config/game_config.json`.
   Si el plugin usa otros nombres de señales/métodos, adáptalos en la
   sección "integración plugin real" de ese archivo.
4. Mantén los IDs de prueba hasta publicar: hacer clic en tus propios anuncios
   reales puede suspender la cuenta.
5. Google Play exige política de privacidad y formulario de consentimiento (UMP)
   para usuarios de la UE.

No se ha contratado ni activado ningún servicio de pago.
