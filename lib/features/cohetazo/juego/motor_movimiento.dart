import '../models/direccion.dart';
import 'reglas_cohetazo.dart';

/// Avanza la posición del jugador local de celda en celda.
///
/// La celda lógica (`x`, `y`) cambia al llegar al centro de la celda destino;
/// la vista interpola con [xVisual] / [yVisual]. Velocidad: 4 + nivel
/// celdas por segundo.
class MotorMovimiento {
  MotorMovimiento({
    required this.x,
    required this.y,
    this.dir = Direccion.abajo,
  });

  int x;
  int y;
  Direccion dir;

  Direccion? _destino;
  double _progreso = 0;

  bool get enMovimiento => _destino != null;

  /// Fracción (0..1) recorrida hacia la celda destino.
  double get progreso => _progreso;

  double get xVisual => x + (_destino?.dx ?? 0) * _progreso;
  double get yVisual => y + (_destino?.dy ?? 0) * _progreso;

  /// Coloca al jugador en una celda (reaparición), cancelando el movimiento.
  void teletransportar(int nx, int ny) {
    x = nx;
    y = ny;
    _destino = null;
    _progreso = 0;
  }

  /// Avanza [dtSeg] segundos con [sostenida] como tecla actual (null si
  /// ninguna). Devuelve las celdas a las que se llegó, en orden. Un paso ya
  /// empezado se completa aunque se suelte la tecla.
  List<(int, int)> avanzar({
    required Direccion? sostenida,
    required int velocidad,
    required double dtSeg,
    required bool Function(int x, int y) puedeMoverA,
  }) {
    final pasos = <(int, int)>[];
    var presupuesto = dtSeg * ReglasCohetazo.celdasPorSegundo(velocidad);
    while (presupuesto > 1e-12) {
      if (_destino == null) {
        if (sostenida == null) break;
        dir = sostenida;
        if (!puedeMoverA(x + sostenida.dx, y + sostenida.dy)) break;
        _destino = sostenida;
        _progreso = 0;
      }
      final falta = 1 - _progreso;
      if (presupuesto >= falta - 1e-12) {
        presupuesto -= falta;
        x += _destino!.dx;
        y += _destino!.dy;
        _destino = null;
        _progreso = 0;
        pasos.add((x, y));
      } else {
        _progreso += presupuesto;
        presupuesto = 0;
      }
    }
    return pasos;
  }
}
