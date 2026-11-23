# Cómo correr la app

Guía para alumnos y profesor. Elige el **Modo A** (datos reales) o el **Modo B** (emuladores locales, recomendado para desarrollar).

## 1. Requisitos

| Herramienta | Versión | Para qué |
|---|---|---|
| Flutter | **3.47 o superior** (trae Dart 3.13.5+, que exige `pubspec.yaml`) | siempre |
| Google Chrome | reciente | correr la app en web |
| Android Studio + un emulador (AVD) | opcional | correr en Android |
| Teléfono con depuración USB | opcional | alternativa al emulador |
| Node.js | **20 o superior** | solo Modo B |
| Java (JDK) | **21 o superior** | solo Modo B (lo usa el emulador de Firestore) |
| `firebase-tools` | `npm install -g firebase-tools` | solo Modo B |

Verifica tu instalación:

```bash
flutter doctor
```

## 2. Clonar e instalar dependencias

```bash
git clone https://github.com/DMI-2026/planificacion-posada.git
cd planificacion-posada
flutter pub get
```

## 3. Modo A: nube (datos reales de la clase)

```bash
flutter run -d chrome
```

Android: lista tus dispositivos y corre en el que quieras.

```bash
flutter devices
flutter run -d <id>
```

> **Nota para el profesor:** la configuración en la nube es reproducible desde el repositorio: `firebase deploy --only firestore,auth --project posada-dmi-2026` crea la base de datos de Firestore (`northamerica-south1`) si no existe, despliega las reglas (`firestore.rules`) y habilita el acceso por Email/Password.

Los datos son compartidos: no borres ni cambies lo que no sea tuyo.

## 4. Modo B: emuladores locales (no toca datos reales)

No necesitas `firebase login`: si no has iniciado sesión solo verás un aviso, y el emulador funciona igual. El proyecto ya está configurado en `.firebaserc` y `firebase.json`. La primera vez se descarga el emulador de Firestore (hace falta internet).

**Terminal 1** (déjala abierta):

```bash
firebase emulators:start
```

Espera el mensaje `All emulators ready!`. Interfaz del emulador: <http://localhost:4000>.

**Terminal 2**, según dónde corras la app:

| Dónde | Comando |
|---|---|
| Chrome | `flutter run -d chrome --dart-define=USAR_EMULADOR=true` |
| Emulador de Android | `flutter run -d <id> --dart-define=USAR_EMULADOR=true` (usa `10.0.2.2` solo) |
| Teléfono físico | `flutter run -d <id> --dart-define=USAR_EMULADOR=true --dart-define=EMULADOR_HOST=<IP de tu compu>` |

El teléfono y la computadora deben estar en la **misma red Wi-Fi**.

Cómo encontrar la IP de tu computadora:

- **macOS:** `ipconfig getifaddr en0` (si está vacío, prueba `en1`)
- **Windows:** `ipconfig` y busca "Dirección IPv4"
- **Linux:** `hostname -I`

**Primer paso en la app:** los emuladores empiezan vacíos. Crea una cuenta en la pantalla de registro (cada cuenta aparece sola en **Participantes**). Los datos se borran al detener el emulador salvo que lo inicies con `--import`/`--export-on-exit`.

## 5. Modo clase (los alumnos se conectan a tu máquina)

Para dar clase: tu computadora corre los emuladores, compila la app web y la sirve en la red; cada alumno solo abre una URL en Chrome. El script lo hace todo (detecta tu IP, reutiliza emuladores que ya estén corriendo o los inicia, compila y sirve):

```bash
./scripts/servir-clase.sh                          # normal
./scripts/servir-clase.sh --auto                   # recompila solo al cambiar lib/
IP=192.168.1.20 PUERTO=8001 ./scripts/servir-clase.sh   # IP y puerto a mano
```

Teclas: `Enter` o `r` recompila, `q` sale (detiene el servidor y, si los inició el script, los emuladores guardando sus datos en `datos-emulador/`). Los logs quedan en `.servir-clase/`.

**Qué hacen los alumnos:** conectarse a la **misma Wi-Fi**, abrir `http://<tu IP>:8000` en Chrome y registrar su cuenta (los emuladores solo tienen los datos de prueba). Tras cada recompilación deben recargar con `Ctrl+Shift+R`.

**Qué cambio necesita qué:**

| Cambio | Acción |
|---|---|
| Código en `lib/` | Recompilar (`r`, o `--auto`) y que los alumnos recarguen |
| `firestore.rules` | Nada: el emulador recarga las reglas solo |
| `firebase.json` | Reiniciar los emuladores (y el script) |

**Problemas frecuentes:**

| Síntoma | Solución |
|---|---|
| El puerto 5000 no funciona | En macOS lo usa AirPlay; por eso se usa el 8000. |
| Los alumnos no conectan en redes de escuela | Muchas redes aíslan a los clientes entre sí; usa tu hotspot o un router propio. |
| Dejó de funcionar al cambiar de red | La IP cambió; detén el script y vuelve a correrlo (recompila con la IP nueva). |
| El firewall bloquea la conexión | Permite conexiones entrantes a `java`, `node` y `python3`. |

**Advertencia:** cualquiera en esa red puede leer y escribir en los emuladores. Usa solo datos de prueba.

## 6. Roles: participantes y admin

- **Participantes = cuentas registradas.** Al registrarse o iniciar sesión, la app crea el documento `participantes/<uid>` (solo `nombre` y `asistencia`, sin correo) si no existe. No hay invitados sin cuenta ni botón de agregar. Cada quien cambia **su propia** asistencia.
- **Admin:** quien tiene un documento `admins/<uid>`. Puede editar el evento, cambiar la asistencia de cualquiera, quitar participantes y gestionar (asignar, marcar lista, eliminar) todas las aportaciones. Los demás solo asignarse o soltar aportaciones suyas/libres y marcar como lista las que llevan ellos.
- **Quitar a alguien** de la lista borra su documento `participantes/<uid>`; si esa persona vuelve a iniciar sesión, reaparece (sigue teniendo cuenta).

### Cómo nombrar admin

1. La persona **se registra primero** en la app (así existe su cuenta y su uid).
2. Busca su **uid** en la pestaña **Authentication** (consola de Firebase o <http://localhost:4000/auth> en el emulador): columna "User UID".
3. Crea un documento con ese uid como **ID**, en la colección `admins`. No necesita campos; sirve `{}` o `{"nota": "organizador"}`:
   - **Nube:** consola de Firebase → Firestore Database → *Iniciar colección* (o agregar documento) → colección `admins`, ID de documento = el uid.
   - **Emulador:** <http://localhost:4000/firestore> → *Start collection* → `admins`, Document ID = el uid.
4. La persona cierra sesión y vuelve a entrar para que la app lea su rol.

Las reglas impiden que la app cree o edite `admins`: solo se hace a mano. Cada persona solo puede leer su propio documento de `admins`. En el emulador los datos se pierden al detenerlo, así que hay que repetirlo (o usar `--export-on-exit`).

## 7. Pruebas

```bash
flutter analyze
flutter test
# Reglas de Firestore (requiere Modo B: Node y Java)
firebase emulators:exec --only firestore --project demo-posada "node test/firestore_rules/rest_rules_test.js"
```

La prueba de reglas usa `FIRESTORE_EMULATOR_HOST` (lo define `emulators:exec`); sin esa variable apunta a `127.0.0.1:8080`.

## 8. Problemas comunes

| Síntoma | Solución |
|---|---|
| `flutter run` se cierra solo | Ejecútalo en una terminal interactiva (no en un script ni con la salida redirigida). |
| Error de puerto ocupado (8080, 9099 o 4000) | Cierra el otro emulador o programa que use ese puerto, o detén el `firebase emulators:start` anterior. |
| Java no encontrado / versión incompatible | Instala JDK 21+ y revisa con `java -version`. |
| `flutter pub get` falla por versión | Actualiza Flutter (`flutter upgrade`); necesitas 3.47+. |
| En Android: "cleartext not permitted" o no conecta | Solo funciona en builds **debug** (`flutter run` lo es). Si usas teléfono físico, revisa `EMULADOR_HOST` y que estén en la misma Wi-Fi. |
| La app muestra error de permisos | Inicia sesión (las reglas exigen sesión). En la nube, avisa al profesor si las reglas no están desplegadas. |
| No aparecen los botones de admin | Tu uid no tiene documento en `admins`; mira "Cómo nombrar admin" y vuelve a iniciar sesión. |
