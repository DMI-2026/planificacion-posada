# Esferas con foto de webcam y Jingle Bells en loop
Las esferas del árbol pueden llevar una foto tomada con la webcam (miniatura guardada en el propio documento) y el árbol reproduce «Jingle Bells» en loop con botón de silencio.

## Specs
- S1: "Puedes hacer una feature para que las esferas tengan una imagen tomada con la webcam"
- S2: decisión del usuario sobre el almacenamiento: "Miniatura en Firestore (Recomendado)" — foto recortada a cuadrado y reducida a ~160x160 JPEG, guardada en base64 en el propio documento del adorno (~15 KB); sin Storage ni Blaze; las reglas validan el tamaño máximo.
- S3: decisión del usuario sobre el diseño: "Nuevo patrón «foto» (Recomendado)" — en el taller de esferas un nuevo patrón «foto» abre la webcam; la foto llena la esfera con brillo y un aro del color elegido.
- S4: "Puedes tambien poner que ponga gingle bells en loop?"
- S5: valor por defecto del parent para S4 (el usuario puede cambiarlo): suena en loop en la vista del árbol con un botón de silenciar/activar; empieza con la primera interacción porque los navegadores bloquean el autoplay; la melodía (dominio público) se sintetiza con un script y se guarda como asset, sin grabaciones de terceros.

## Tasks
- [x] T1 (S1-S3) esfera con foto de webcam — worker
- [x] T2 (S4-S5) Jingle Bells en loop en el árbol — worker
- [x] T3 verificación independiente de reglas — parent
- [ ] T4 PR — decisión del usuario

## Log
- L1: "Puedes hacer una feature para que las esferas tengan una imagen tomada con la webcam"
- L2: "Puedes tambien poner que ponga gingle bells en loop?"
- L3: T1 (S1-S3) observado: `flutter analyze` sin problemas; `flutter test` 371 pasan (98 en test/features/arbol, 0 fallos); `flutter build web` OK; reglas en emulador aislado: arbol 95 PASS / 0 FAIL (65 previos + 30 de foto), rest 129 / 0 fallos. Dependencias nuevas: `camera ^0.12.2`, `image ^4.13.1`. minSdk de `camera` (23) cubierto por el 24 del proyecto; permiso CAMERA agregado al manifiesto. Sin verificar en cámara real (solo captura falsa en pruebas).
- L4: T2 (S4-S5) observado: `dart run tool/generar_jingle_bells.dart` -> assets/audio/jingle_bells.wav 1012580 bytes, 22.96 s (mono 16-bit 22050 Hz); `flutter pub get` OK (audioplayers ^6.8.1); `flutter analyze` sin problemas; `flutter test` 378 pasan (371 previos + 7 de música), 0 fallos; `flutter build web` OK. Sin verificar audible en navegador/dispositivo real (solo servicio falso en pruebas); comportamiento real del autoplay bloqueado en web no probado.
- L5: T3 verificación independiente de reglas: pasa. arbol 95/0, rest 129/0, 36 sondas propias 0 fallos. Avisos: el tamaño se cuenta en caracteres UTF-16 (<=~120 KB, seguro); el contenido de `foto` no se valida como base64 (la decodificación del cliente tiene respaldo); las versiones antiguas de la app omiten los documentos con foto. Se agregaron 9 casos de regresión (editar rayas/puntos/foto, foto como bytes, color fuera de paleta, creado de cliente): arbol 104 PASS / 0 FAIL en emulador.
