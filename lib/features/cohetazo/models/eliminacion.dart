import 'utiles.dart';

/// Registro de una eliminación (`/cohetazo/eliminaciones/{pushId}`).
class Eliminacion {
  const Eliminacion({
    required this.victima,
    required this.autor,
    required this.t,
  });

  factory Eliminacion.fromMap(Map<Object?, Object?> m) => Eliminacion(
    victima: leerTexto(m['victima']),
    autor: leerTexto(m['autor']),
    t: leerEntero(m['t']),
  );

  final String victima;
  final String autor;
  final int t;

  /// [marcaTiempo] reemplaza `t` (p. ej. `ServerValue.timestamp`).
  Map<String, Object?> toMap({Object? marcaTiempo}) => {
    'victima': victima,
    'autor': autor,
    't': marcaTiempo ?? t,
  };
}
