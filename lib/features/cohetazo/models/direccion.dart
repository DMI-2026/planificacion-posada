/// Dirección de movimiento / mirada de un jugador.
enum Direccion {
  arriba(0, -1),
  abajo(0, 1),
  izquierda(-1, 0),
  derecha(1, 0);

  const Direccion(this.dx, this.dy);

  final int dx;
  final int dy;

  /// Valor guardado en RTDB (`dir`).
  String get clave => name;

  static Direccion desdeClave(Object? valor) {
    for (final d in values) {
      if (d.name == valor) return d;
    }
    return abajo;
  }
}
