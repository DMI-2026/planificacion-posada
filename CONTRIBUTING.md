# Cómo contribuir

Para correr la app, mira [docs/como-correr.md](docs/como-correr.md); para desarrollar tu feature usa el **Modo B** (emuladores locales).

## Flujo por equipo
1. Cada equipo hace **una feature** en `lib/features/<feature>/`.
2. Crea tu rama desde `main`: `feat/<equipo>-<feature>` (ej. `feat/equipo3-cooperacion`).
3. Commits con [Conventional Commits](https://www.conventionalcommits.org/): `feat: ...`, `fix: ...`, `docs: ...`, `test: ...`.
4. Abre un PR a `main` y pide revisión. No hagas push directo a `main`.
5. Antes del PR: `flutter analyze` y `flutter test` en verde (y las pruebas de `test/firestore_rules/` si tocaste `firestore.rules`).

## Checklist para agregar una feature
Usa `lib/features/participantes/` como ejemplo.

1. **Modelo** en `models/` con `toMap()` y `fromMap()`.
2. **Repositorio** en `repositories/`: clase abstracta, `fake_*` (en memoria, para pruebas) y `firestore_*`.
3. **ViewModel** en `viewmodels/`: `ChangeNotifier` con `cargando`, `error` y mensajes en español. Escribe sus pruebas en `test/features/<feature>/`.
4. **Vista** en `views/`.
5. **Destino de navegación:** agrega UNA entrada a la lista `destinos` en `lib/core/navegacion/destinos.dart` (etiqueta, iconos y `builder`).
6. **ViewModel de la sesión** (si tu vista lo lee con `PosadaScope.of(context)`), en estos dos archivos. Si tu viewmodel necesita saber si la persona es admin o participante, mira cómo `sesion_activa.dart` crea los de `ModulosScope` (se recrean cuando cambia el rol):
   - `lib/core/navegacion/sesion_activa.dart`: agrega el repositorio como parámetro de `SesionActiva`, declara `late final MiViewModel _mio;`, créalo en `initState()` y llama `_mio.dispose()` en `dispose()`; pásalo a `PosadaScope(...)` en `build`.
   - `lib/core/navegacion/posada_scope.dart`: agrega el campo (`required this.mio` y `final MiViewModel mio;`) y compáralo en `updateShouldNotify`.
   - Pasa tu repositorio Firestore (y el fake en pruebas) donde se construye `SesionActiva` (busca su uso en `lib/`, p. ej. `main.dart`).
   - Alternativa simple: crear el viewmodel dentro de tu propia vista.
7. **Reglas:** `firestore.rules` es la única fuente (no dejes fragmentos `.rules` sueltos en `lib/`). Agrega ahí un bloque `match /<coleccion>/{id}` con validación de forma (campos permitidos, tipos y límites), con nombres de funciones auxiliares propios de tu módulo (prefijo) para no chocar con los demás, y un archivo de pruebas `test/firestore_rules/<feature>_rules_test.js` (mira los existentes; se corre con `firebase emulators:exec`). Si tocas un documento de `config/`, usa `match /config/<tu-documento>` y no un comodín (las reglas se suman con OR) y agrega un caso en `config_rules_test.js`. Si pones límites de texto, defínelos en `lib/core/validacion/limites.dart` (o en los límites de tu feature) iguales a los de las reglas.
8. `flutter analyze` y `flutter test` en verde.

## Roles (admin)
Hay un rol de admin: quien tiene un documento `admins/<uid>` administra el evento, los participantes, la votación, el itinerario, las aportaciones, el árbol y el intercambio; los demás solo lo suyo (tabla por módulo en [docs/como-correr.md](docs/como-correr.md)). Para nombrar admin, mira "Cómo nombrar admin" en [docs/como-correr.md](docs/como-correr.md). Si tu feature escribe datos, decide qué puede hacer cada rol en `firestore.rules` (función `esAdmin()`) y pruébalo en el archivo de reglas de tu feature en `test/firestore_rules/`.

## Ideas de features (solo sugerencias)
- Lista de tareas de decoración.
- Galería / avisos.
