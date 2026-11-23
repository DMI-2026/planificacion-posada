# Posada MVP
App Flutter (Android + Chrome) para organizar la posada de la clase, con Firestore del proyecto Firebase propio `posada-dmi-2026`.
Convención: MVVM como proyecto-clase (models / repositories abstract+fake+firestore / viewmodels ChangeNotifier / views / components), identificadores en español.
Estructura feature-first: cada equipo agrega su feature en lib/features/<feature>/.

## Specs
- S1: "quiero que este proyecto sea un proyecto de flutter solo para android y chrome"
- S2: "la idea es que sea un proyecto para mi clase para la organizacion de la posada"
- S3: "Podemos usar un servicio en la nube de firestore pidemos reutilizar el que ya usamos en /Users/carsimax/Documents/cmx_teach/cursos/2026-sep-dic/desarrollo-movil-integral-10/proyecto-clase"
- S4: ~~(reemplazada por S8)~~ Reglas: "Misma base, reglas unidas" (colecciones con prefijo posada_ en la base (default); reglas agregadas al firestore.rules del proyecto-clase y desplegadas solo desde ahí)
- S8: Firestore: "Proyecto Firebase nuevo (Spark)" (reemplaza S4; proyecto posada-dmi-2026, reglas propias en este repo)
- S9: GitHub: "planificacion-posada, público"; teams: "Write (Recommended)"
- S5: Paquete: "mx.edu.utez.planificacion_posada"
- S6: Estado: "ChangeNotifier"
- S7: Alcance: "Solo un MVP menor" (evento, participantes y aportaciones; cooperación e intercambio después)

## Tasks
- [x] T1 (S1, S5) cambiar paquete Android a mx.edu.utez.planificacion_posada — worker
- [x] T2 (S2, S6, S7) modelos, repositorios abstractos + fake, viewmodels y tests — worker
- [x] T3 (S2, S7) vistas y componentes con repos fake — worker
- [x] T4 (S3, S8) dependencias Firebase, repos Firestore, auth (login/registro) y main — worker
- [x] T5 (S8) firestore.rules propias + firebase.json (reglas y emuladores) — worker; escrito, no desplegado; despliegue tras verificación
- [x] T6 (S3, S5, S8) flutterfire configure --project=posada-dmi-2026 — worker
- [x] T7 (S9) git local, repo DMI-2026/planificacion-posada público, teams con write — parent
- [x] T8 (S8) límites de captura alineados con reglas + prueba de reglas en repo — worker
- [x] T9 (L4) README y CONTRIBUTING para equipos — worker

## Log
- L1: "Hola quiero que este proyecto sea un proyecto de flutter solo para android y chrome, la idea es que sea un proyecto para mi clase para la organizacion de la posada"
- L2: "Podemos usar un servicio en la nube de firestore pidemos reutilizar el que ya usamos en /Users/carsimax/Documents/cmx_teach/cursos/2026-sep-dic/desarrollo-movil-integral-10/proyecto-clase"
- L3: respuestas: Misma base, reglas unidas; mx.edu.utez.planificacion_posada; ChangeNotifier; Solo un MVP menor
- L4: "La idea es unir esta app tambien con temas de clase es hacer el mvp, y por equipo haga un feature, este repo sera partre de la organizacion https://github.com/DMI-2026 ahi ya tenemos los teams y el espacio para el grupo"
- L5: T1 flutter analyze OK (No issues found); paquete mx.edu.utez.planificacion_posada en build.gradle.kts y MainActivity.kt
- L6: T2 flutter analyze OK, flutter test 29 passed (feature-first: lib/features/{evento,participantes,aportaciones})
- L7: T6 flutterfire configure (proyecto anterior, descartado por S8) OK: created lib/firebase_options.dart, android/app/google-services.json, firebase.json; gradle google-services plugin added in android/settings.gradle.kts and android/app/build.gradle.kts; appIds android 1:223866053428:android:74664b3e5b4b0312de3b61, web 1:223866053428:web:9f2dfb3718edea5ede3b61; flutter analyze: 5 errors, all in firebase_options.dart (firebase_core not yet a dependency)
- T3: vistas + shell (NavigationBar/Rail) con repos fake; flutter analyze limpio, flutter test 34 pass (5 nuevos widget tests), flutter build web OK.
- L8: respuestas: "Proyecto Firebase nuevo (Spark)"; "planificacion-posada, público"; "Write (Recommended)". Proyecto posada-dmi-2026 creado; base nombrada rechazada por requerir facturación.
- L9: T6 flutterfire configure --project=posada-dmi-2026 OK; appIds android 1:387658564854:android:2be02e8235d49d7ecf18d7, web 1:387658564854:web:ea98ba456b161077cf18d7; sin cadenas del proyecto anterior en el repo.
- L10: T4 auth (login/registro/puerta de sesión), repos Firestore (evento/actual, participantes, aportaciones), main con Firebase y USAR_EMULADOR; flutter analyze limpio, flutter test 51 pass, flutter build web OK.
- L11: T5 firestore.rules + firebase.json (emuladores) + .firebaserc escritos, NO desplegados; el emulador de Firestore carga las reglas sin errores (pruebas de reglas pendientes).
- T8: límites en lib/core/validacion/limites.dart (nombre/artículo 100, lugar 200, notas 1000, cantidad 999) usados en viewmodels y maxLength de vistas; RED 6 pruebas fallaron, luego flutter analyze limpio, flutter test 60 pass; reglas: firebase emulators:exec ... rest_rules_test.js TOTAL pass=75 fail=0
- T9: README.md y CONTRIBUTING.md escritos (L4)
- L12: T3 verificado por el parent (flutter test 34 OK, analyze limpio, build web OK); casilla restaurada.
- L13: Verificación independiente de reglas (odd-verify): 75/75 casos en emulador, sin diferencias con las escrituras de la app.
- L14: T7 parcial: repo DMI-2026/planificacion-posada creado (público), team-1..team-5 con permiso push; git local en rama feat/mvp-posada. Push pendiente de autorización.
- L15: Pendiente del usuario: crear Firestore (northamerica-south1) y activar Email/Password en la consola de posada-dmi-2026; luego desplegar reglas. App Android sobrante en cafeteria-carsi pendiente de decisión.
- L16: "Sí, súbelo a main" — MVP publicado como main en https://github.com/DMI-2026/planificacion-posada (push por el parent).
