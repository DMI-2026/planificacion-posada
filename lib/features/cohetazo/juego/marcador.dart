import '../models/eliminacion.dart';

/// Puntaje por uid derivado del registro de eliminaciones: +1 al autor por
/// eliminar a otro jugador, -1 por autoeliminación. Las víctimas sin puntos
/// aparecen con 0.
Map<String, int> marcador(Iterable<Eliminacion> eliminaciones) {
  final puntos = <String, int>{};
  for (final e in eliminaciones) {
    puntos.putIfAbsent(e.victima, () => 0);
    puntos[e.autor] = (puntos[e.autor] ?? 0) + (e.autor == e.victima ? -1 : 1);
  }
  return puntos;
}
