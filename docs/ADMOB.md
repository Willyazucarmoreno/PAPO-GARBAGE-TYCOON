# Publicidad (AdMob) — solo anuncios recompensados voluntarios

Estado: la lógica del juego está lista (`scripts/autoload/ad_manager.gd`).
En navegador y sin plugin se muestra un **anuncio simulado** de 4 s para probar
el flujo. Los IDs del código son los **IDs de prueba oficiales de Google**.

Recompensas: +5 EcoCoins, dinero x2 durante 3 min, dinero instantáneo o x2 de
ganancias offline. Enfriamiento de 45 s. Nunca se muestran anuncios sin que el
jugador pulse un botón.

## Para activar anuncios reales (requiere tu cuenta, gratuita)
1. Crea una cuenta en AdMob y una app Android → obtén App ID y un bloque
   "Recompensado".
2. Instala un plugin de AdMob para Godot 4 compatible con Android
   (p. ej. *Poing Studios godot-admob-plugin*) siguiendo sus instrucciones;
   necesita `gradle_build/use_gradle_build=true` en `export_presets.cfg`.
3. Sustituye `ANDROID_APP_ID` y `ANDROID_REWARDED_ID` en `ad_manager.gd`.
   Si el plugin usa otros nombres de señales/métodos, adáptalos en la
   sección "integración plugin real" de ese archivo.
4. Mantén los IDs de prueba hasta publicar: hacer clic en tus propios anuncios
   reales puede suspender la cuenta.
5. Google Play exige política de privacidad y formulario de consentimiento (UMP)
   para usuarios de la UE.

No se ha contratado ni activado ningún servicio de pago.
