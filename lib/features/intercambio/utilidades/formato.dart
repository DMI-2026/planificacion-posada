/// Centavos -> "$1,234.50".
String formatearMonto(int centavos) {
  final negativo = centavos < 0;
  final abs = centavos.abs();
  final enteros = (abs ~/ 100).toString();
  final buffer = StringBuffer();
  for (var i = 0; i < enteros.length; i++) {
    if (i > 0 && (enteros.length - i) % 3 == 0) buffer.write(',');
    buffer.write(enteros[i]);
  }
  final cts = (abs % 100).toString().padLeft(2, '0');
  return '${negativo ? '-' : ''}\$$buffer.$cts';
}

/// Texto escrito por una persona ("250", "1,234.5", "\$99.99") -> centavos,
/// o `null` si no es un monto válido.
int? parsearMonto(String texto) {
  final limpio = texto.replaceAll(RegExp(r'[\s,$]'), '');
  final m = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(limpio);
  if (m == null) return null;
  final enteros = int.tryParse(m.group(1)!);
  if (enteros == null) return null;
  final cts = int.parse((m.group(2) ?? '0').padRight(2, '0'));
  return enteros * 100 + cts;
}

const _meses = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// "18 de diciembre de 2026".
String formatearFecha(DateTime f) =>
    '${f.day} de ${_meses[f.month - 1]} de ${f.year}';

/// "Faltan 5 días", "¡Es mañana!", "¡Es hoy!" o "Ya pasó".
String cuentaRegresiva(DateTime fecha, DateTime ahora) {
  final dias = DateTime(
    fecha.year,
    fecha.month,
    fecha.day,
  ).difference(DateTime(ahora.year, ahora.month, ahora.day)).inDays;
  if (dias < 0) return 'Ya pasó';
  if (dias == 0) return '¡Es hoy!';
  if (dias == 1) return '¡Es mañana!';
  return 'Faltan $dias días';
}
