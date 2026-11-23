/// Límites de las aportaciones económicas.
///
/// IMPORTANTE: deben coincidir con `aportaciones.rules` (y con
/// `test/firestore_rules/aportaciones_rules_test.js`).
abstract final class LimitesAportaciones {
  static const int montoMinimoCentavos = 1;
  static const int montoMaximoCentavos = 10000000;
}

/// Da formato de dinero a [centavos]: `123450` -> `$1,234.50`.
String formatoDinero(int centavos) {
  final negativo = centavos < 0;
  final abs = centavos.abs();
  final enteros = (abs ~/ 100).toString();
  final cents = (abs % 100).toString().padLeft(2, '0');
  final sb = StringBuffer();
  for (var i = 0; i < enteros.length; i++) {
    if (i > 0 && (enteros.length - i) % 3 == 0) sb.write(',');
    sb.write(enteros[i]);
  }
  return '${negativo ? '-' : ''}\$$sb.$cents';
}

/// Lee un monto escrito por una persona (`1234.5`, `$1,234.50`) como
/// centavos; `null` si no es un monto válido (máximo 2 decimales).
int? centavosDeTexto(String texto) {
  final limpio = texto.replaceAll(RegExp(r'[\s,\$]'), '');
  final m = RegExp(r'^(\d{1,9})(?:\.(\d{1,2}))?$').firstMatch(limpio);
  if (m == null) return null;
  final cents = (m.group(2) ?? '').padRight(2, '0');
  return int.parse(m.group(1)!) * 100 + int.parse(cents);
}
