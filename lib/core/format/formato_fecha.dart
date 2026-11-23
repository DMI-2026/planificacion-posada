/// Formatea [fecha] como `dd/MM/yyyy HH:mm` (sin depender de `intl`).
String formatearFechaHora(DateTime fecha) {
  String dos(int n) => n.toString().padLeft(2, '0');
  final anio = fecha.year.toString().padLeft(4, '0');
  return '${dos(fecha.day)}/${dos(fecha.month)}/$anio '
      '${dos(fecha.hour)}:${dos(fecha.minute)}';
}
