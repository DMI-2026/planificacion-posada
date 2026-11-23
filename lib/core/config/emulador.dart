/// Host donde corren los emuladores de Firebase.
///
/// - [definido] (de `--dart-define=EMULADOR_HOST=...`) manda si no está vacío.
/// - El emulador de Android ve la compu como `10.0.2.2`.
/// - En el resto (Chrome, escritorio) es `localhost`.
String hostEmulador({
  required bool esWeb,
  required bool esAndroid,
  String definido = '',
}) {
  if (definido.isNotEmpty) return definido;
  if (!esWeb && esAndroid) return '10.0.2.2';
  return 'localhost';
}
