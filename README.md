# Planificación Posada

App para organizar la posada de Navidad de la clase. Proyecto de la clase DMI-2026.

## Módulos

1. **Inicio:** cuenta regresiva y datos de la posada.
2. **Participantes:** quién se registró y si asiste (sí / no / tal vez).
3. **Comida (votación):** se proponen platillos y cada quien vota por uno; el admin cierra la votación.
4. **Itinerario:** actividades de la noche en orden, con hora, duración y responsable.
5. **Aportaciones:** material (quién lleva qué) y económicas (cuotas, con meta de recaudación).
6. **Árbol virtual:** cada quien crea esferas y regalos y los cuelga; todos los ven en tiempo real. Las esferas pueden llevar una foto tomada con la cámara (patrón «Foto»). En el árbol suena «Jingle Bells» en loop (botón de nota musical para silenciar).
7. **Intercambio de regalos:** inscripción con lista de deseos, sorteo y revelación de a quién le regalas.
8. **Cohetazo navideño:** juego multijugador en tiempo real (ver [Cohetazo navideño](#cohetazo-navideño)).

- **Plataformas:** Android y Chrome (web).
- **Stack:** Flutter, Firebase Auth + Firestore (proyecto `posada-dmi-2026`), estado con `ChangeNotifier` (MVVM).

## Cómo correr

```bash
flutter pub get
flutter run -d chrome
```

Con emuladores locales (no toca datos reales):

```bash
firebase emulators:start                                  # terminal 1
flutter run -d chrome --dart-define=USAR_EMULADOR=true    # terminal 2
```

Para dar clase con los alumnos conectados a tu máquina: [Modo clase](docs/como-correr.md#5-modo-clase-los-alumnos-se-conectan-a-tu-máquina) (`./scripts/servir-clase.sh`).

Despliegue web en un servidor Dokploy: [docs/despliegue-dokploy.md](docs/despliegue-dokploy.md).

Guía completa (Android, teléfono físico, problemas comunes): [docs/como-correr.md](docs/como-correr.md).

## Pruebas

```bash
flutter analyze
flutter test
# Reglas de Firestore (requiere firebase-tools, Node 20+ y Java 21+): un archivo por módulo
firebase emulators:exec --only firestore --project demo-posada "node test/firestore_rules/rest_rules_test.js"
# Reglas de Realtime Database (Cohetazo)
firebase emulators:exec --only database --project demo-posada "node test/database_rules/cohetazo_rules_test.js"
```

## Realtime Database (Cohetazo)

El juego Cohetazo usa Firebase Realtime Database. Las reglas están en `database.rules.json` (referenciado desde `firebase.json`) y el emulador corre en el puerto 9000 junto con los demás (`firebase emulators:start`; con `USAR_EMULADOR=true` la app se conecta solo). La instancia **debe crearse en la consola de Firebase (o con `firebase database:instances:create`) antes de producción**, y su URL debe coincidir con `databaseURL` en `lib/firebase_options.dart` (hoy `https://posada-dmi-2026-default-rtdb.firebaseio.com`). Después se publican las reglas con `firebase deploy --only database`.

## Cohetazo navideño

Arena nevada siempre abierta para todas las personas con sesión: laberinto de hielo y ladrillo, cajas de regalo que se rompen y sueltan mejoras, y **cohetes** en vez de bombas. Original, sin marcas ni arte de terceros.

- **Entrar:** destino «Cohetazo» del menú (en el teléfono, bajo «Más»). Se pide una **foto de avatar con la cámara** (miniatura de 96 px, JPEG base64 ≤ 20000 caracteres en `/cohetazo/avatares/<uid>`; reutiliza la captura de las esferas). Sin cámara, sin permiso o en http aparece el motivo, **Reintentar** y la opción «Jugar con mis iniciales» (avatar de iniciales, rotulado como tal).
- **Controles:** flechas o WASD para moverte (mientras se mantienen) y **barra espaciadora** para colocar un cohete. En pantallas angostas y en teléfonos aparecen el **D-pad** y el botón del cohete; el botón del mando de la barra superior los muestra u oculta en cualquier pantalla.
- **Reglas:** el cohete explota a los 2,5 s en cruz (alcance base 2); el fuego se detiene en los muros y en la primera caja (que se rompe) y dura 0,6 s; el fuego enciende los cohetes que toca (reacción en cadena). Las cajas rotas rebrotan a los 30 s y 3 de cada 10 sueltan una mejora: **alcance** (+1, máx. 6), **cohetes** (+1, máx. 5) o **velocidad** (+1 celda/s, máx. 3). Quien es alcanzado reaparece a los 3 s con 1,5 s de invulnerabilidad y pierde las mejoras. Marcador: +1 por eliminar a otra persona, -1 por autoeliminarse (se deriva del registro de eliminaciones).
- **Cliente autoritativo:** cada cliente decide su propia muerte y escribe sus cajas rotas (sistema de honor). Al salir de la pantalla se borra al jugador de la arena (y `onDisconnect` lo hace si se cierra la pestaña).
- **Requisitos:** Realtime Database (ver arriba; el módulo no funciona hasta que la instancia exista y las reglas estén publicadas). La cámara en web exige **https o `localhost`**; en el Modo clase (http) usa el avatar de iniciales o sirve la app por https.
- **Código:** `lib/features/cohetazo/` (`juego/` y `models/` reglas puras y deterministas; `repositories/` RTDB + fake; `viewmodels/` bucle local; `views/` pantalla de entrada, arena con `CustomPainter`, marcador y controles).

## Música del árbol

La vista del árbol reproduce «Jingle Bells» (dominio público, sintetizada con `tool/generar_jingle_bells.dart`, sin grabaciones de terceros) en loop a volumen bajo. Los navegadores bloquean el audio hasta que hay una interacción: si no arranca al abrir, empieza con el primer toque dentro del árbol. El botón de nota musical la silencia o la activa, y se detiene al salir de la vista. Para regenerar el WAV: `dart run tool/generar_jingle_bells.dart`.

## Estructura

```
lib/
  core/                 # compartido: navegacion, theme, widgets, validacion, format, errors
  features/<feature>/
    models/             # datos con toMap/fromMap
    repositories/       # abstracto + fake (pruebas) + firestore
    viewmodels/         # ChangeNotifier
    views/              # pantallas y widgets
test/features/<feature>/  # pruebas de cada feature
test/firestore_rules/     # pruebas de firestore.rules
firestore.rules           # reglas de seguridad (única fuente; un bloque por colección)
```

Features actuales: `auth`, `evento` (Inicio), `participantes`, `votacion`, `itinerario`, `aportaciones`, `arbol`, `intercambio`, `cohetazo`. Para colaborar lee [CONTRIBUTING.md](CONTRIBUTING.md).
