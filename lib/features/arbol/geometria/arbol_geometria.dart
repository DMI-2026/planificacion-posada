import 'dart:math' as math;
import 'dart:ui' show Offset;

/// Un piso (triángulo) de la silueta del árbol, en coordenadas normalizadas
/// (0..1) del área del árbol. El ancho es el semiancho respecto a x = 0.5.
class PisoArbol {
  const PisoArbol({
    required this.arriba,
    required this.abajo,
    required this.anchoArriba,
    required this.anchoAbajo,
  });

  final double arriba;
  final double abajo;
  final double anchoArriba;
  final double anchoAbajo;

  /// Semiancho del piso a la altura [y] (solo válido entre [arriba] y [abajo]).
  double anchoEn(double y) {
    final t = ((y - arriba) / (abajo - arriba)).clamp(0.0, 1.0);
    return anchoArriba + (anchoAbajo - anchoArriba) * t;
  }
}

/// Los tres pisos del árbol; se solapan un poco. El pintor del árbol usa esta
/// misma lista, así lo dibujado y lo permitido coinciden.
const List<PisoArbol> pisosArbol = [
  PisoArbol(arriba: 0.06, abajo: 0.36, anchoArriba: 0.02, anchoAbajo: 0.20),
  PisoArbol(arriba: 0.26, abajo: 0.62, anchoArriba: 0.08, anchoAbajo: 0.31),
  PisoArbol(arriba: 0.50, abajo: 0.90, anchoArriba: 0.12, anchoAbajo: 0.45),
];

const double arbolYMin = 0.06;
const double arbolYMax = 0.90;

/// Semiancho de la silueta a la altura [y], o `null` si [y] cae fuera del árbol.
double? semiAnchoArbol(double y) {
  double? mejor;
  for (final p in pisosArbol) {
    if (y >= p.arriba && y <= p.abajo) {
      mejor = math.max(mejor ?? 0, p.anchoEn(y));
    }
  }
  return mejor;
}

const double _epsilon = 1e-9;

/// `true` si el punto normalizado ([x], [y]) está dentro de la silueta.
bool dentroDelArbol(double x, double y) {
  if (!x.isFinite || !y.isFinite) return false;
  final ancho = semiAnchoArbol(y);
  return ancho != null && (x - 0.5).abs() <= ancho + _epsilon;
}

/// Lleva ([x], [y]) al punto más cercano dentro del árbol (a [margen] del
/// borde, para que el adorno no quede medio fuera). Un punto ya dentro y a más
/// de [margen] del borde no se mueve. Valores no finitos van al centro.
Offset ajustarAlArbol(double x, double y, {double margen = 0.015}) {
  if (!x.isFinite || !y.isFinite) return const Offset(0.5, 0.5);
  final yy = y.clamp(arbolYMin + 0.02, arbolYMax - 0.02);
  final limite = math.max(0.0, (semiAnchoArbol(yy) ?? 0) - margen);
  final xx = x.clamp(0.5 - limite, 0.5 + limite);
  return Offset(xx, yy);
}
