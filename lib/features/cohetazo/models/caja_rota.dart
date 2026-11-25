import 'utiles.dart';

/// Caja de regalo destruida (`/cohetazo/cajas/{x}_{y}`).
class CajaRota {
  const CajaRota({
    required this.x,
    required this.y,
    required this.rota,
    required this.por,
  });

  /// [clave] tiene la forma `x_y`.
  factory CajaRota.fromMap(String clave, Map<Object?, Object?> m) {
    final partes = clave.split('_');
    return CajaRota(
      x: partes.length == 2 ? int.tryParse(partes[0]) ?? 0 : 0,
      y: partes.length == 2 ? int.tryParse(partes[1]) ?? 0 : 0,
      rota: leerEntero(m['rota']),
      por: leerTexto(m['por']),
    );
  }

  final int x;
  final int y;

  /// Hora del servidor (ms) en que se rompió.
  final int rota;
  final String por;

  String get clave => claveCaja(x, y);

  /// Clave de la mejora que suelta esta caja.
  String get claveDeMejora => claveMejora(x, y, rota);

  /// [marcaTiempo] reemplaza `rota` (p. ej. `ServerValue.timestamp`).
  Map<String, Object?> toMap({Object? marcaTiempo}) => {
    'rota': marcaTiempo ?? rota,
    'por': por,
  };

  static String claveCaja(int x, int y) => '${x}_$y';

  /// `/cohetazo/mejoras/{x}_{y}_{rota}`.
  static String claveMejora(int x, int y, int rota) => '${x}_${y}_$rota';
}
