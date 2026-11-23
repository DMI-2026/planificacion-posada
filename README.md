# Planificación Posada

App para organizar la posada de Navidad de la clase. Proyecto de la clase DMI-2026.

## Módulos

1. **Inicio:** cuenta regresiva y datos de la posada.
2. **Participantes:** quién se registró y si asiste (sí / no / tal vez).
3. **Comida (votación):** se proponen platillos y cada quien vota por uno; el admin cierra la votación.
4. **Itinerario:** actividades de la noche en orden, con hora, duración y responsable.
5. **Aportaciones:** material (quién lleva qué) y económicas (cuotas, con meta de recaudación).
6. **Árbol virtual:** cada quien crea esferas y regalos y los cuelga; todos los ven en tiempo real.
7. **Intercambio de regalos:** inscripción con lista de deseos, sorteo y revelación de a quién le regalas.

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
firestore.rules           # reglas de seguridad (única fuente; un bloque por colección)
```

Features actuales: `auth`, `evento` (Inicio), `participantes`, `votacion`, `itinerario`, `aportaciones`, `arbol`, `intercambio`. Para colaborar lee [CONTRIBUTING.md](CONTRIBUTING.md).
