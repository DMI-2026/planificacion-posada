import 'utiles.dart';

/// Cohete colocado (`/cohetazo/cohetes/{id}`).
class Cohete {
  const Cohete({
    required this.id,
    required this.uid,
    required this.x,
    required this.y,
    required this.alcance,
    required this.colocado,
  });

  factory Cohete.fromMap(String id, Map<Object?, Object?> m) => Cohete(
    id: id,
    uid: leerTexto(m['uid']),
    x: leerEntero(m['x']),
    y: leerEntero(m['y']),
    alcance: leerEntero(m['alcance'], 2),
    colocado: leerEntero(m['colocado']),
  );

  final String id;
  final String uid;
  final int x;
  final int y;
  final int alcance;

  /// Hora del servidor (ms) en que se colocó.
  final int colocado;

  (int, int) get celda => (x, y);

  /// [marcaTiempo] reemplaza `colocado` (p. ej. `ServerValue.timestamp`).
  Map<String, Object?> toMap({Object? marcaTiempo}) => {
    'uid': uid,
    'x': x,
    'y': y,
    'alcance': alcance,
    'colocado': marcaTiempo ?? colocado,
  };
}
