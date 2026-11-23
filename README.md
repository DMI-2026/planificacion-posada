# Planificación Posada

App para organizar la posada de la clase: evento (nombre, fecha, lugar, notas), participantes con su asistencia y aportaciones (quién lleva qué). Proyecto de la clase DMI-2026: cada equipo agrega una feature.

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

Guía completa (Android, teléfono físico, problemas comunes): [docs/como-correr.md](docs/como-correr.md).

## Pruebas

```bash
flutter analyze
flutter test
# Reglas de Firestore (requiere firebase-tools, Node 20+ y Java 21+)
firebase emulators:exec --only firestore --project demo-posada "node test/firestore_rules/rest_rules_test.js"
```

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
firestore.rules           # reglas de seguridad (una por colección)
```

Features actuales: `auth`, `evento`, `participantes`, `aportaciones`. Para colaborar lee [CONTRIBUTING.md](CONTRIBUTING.md).
