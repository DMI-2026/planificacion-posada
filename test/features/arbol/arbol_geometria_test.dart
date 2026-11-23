import 'package:flutter_test/flutter_test.dart';
import 'package:planificacion_posada/features/arbol/geometria/arbol_geometria.dart';

void main() {
  group('dentroDelArbol', () {
    test('el centro del tronco de copa está dentro', () {
      expect(dentroDelArbol(0.5, 0.3), isTrue);
      expect(dentroDelArbol(0.5, 0.7), isTrue);
    });

    test('fuera del cuadro 0..1 o sobre el cielo no es árbol', () {
      expect(dentroDelArbol(-0.1, 0.5), isFalse);
      expect(dentroDelArbol(1.1, 0.5), isFalse);
      expect(dentroDelArbol(0.5, 0.0), isFalse);
      expect(dentroDelArbol(0.5, 1.0), isFalse);
    });

    test('el piso de abajo es el más ancho', () {
      expect(dentroDelArbol(0.1, 0.85), isTrue);
      expect(dentroDelArbol(0.9, 0.85), isTrue);
      expect(dentroDelArbol(0.1, 0.2), isFalse);
      expect(dentroDelArbol(0.9, 0.2), isFalse);
    });

    test('la punta es angosta', () {
      expect(dentroDelArbol(0.5, 0.08), isTrue);
      expect(dentroDelArbol(0.6, 0.08), isFalse);
    });

    test('NaN e infinito no están dentro', () {
      expect(dentroDelArbol(double.nan, 0.5), isFalse);
      expect(dentroDelArbol(0.5, double.infinity), isFalse);
    });
  });

  group('ajustarAlArbol', () {
    test('un punto bien dentro no se mueve', () {
      final p = ajustarAlArbol(0.52, 0.7);
      expect(p.dx, 0.52);
      expect(p.dy, 0.7);
    });

    test('siempre devuelve un punto dentro del árbol (malla de puntos)', () {
      for (var i = -2; i <= 12; i++) {
        for (var j = -2; j <= 12; j++) {
          final p = ajustarAlArbol(i / 10, j / 10);
          expect(dentroDelArbol(p.dx, p.dy), isTrue, reason: '($i,$j) -> $p');
        }
      }
    });

    test('es idempotente', () {
      final a = ajustarAlArbol(0.95, 0.4);
      final b = ajustarAlArbol(a.dx, a.dy);
      expect(b.dx, closeTo(a.dx, 1e-12));
      expect(b.dy, closeTo(a.dy, 1e-12));
    });

    test('lleva un punto lejano a la silueta del mismo lado', () {
      final izq = ajustarAlArbol(0.0, 0.2);
      final der = ajustarAlArbol(1.0, 0.2);
      expect(izq.dx, lessThan(0.5));
      expect(der.dx, greaterThan(0.5));
      expect(izq.dy, 0.2);
      expect(0.5 - izq.dx, closeTo(der.dx - 0.5, 1e-12));
    });

    test('un punto muy arriba o muy abajo se sube/baja al árbol', () {
      expect(ajustarAlArbol(0.5, -1).dy, greaterThanOrEqualTo(arbolYMin));
      expect(ajustarAlArbol(0.5, 2).dy, lessThanOrEqualTo(arbolYMax));
    });

    test('valores no finitos van al centro', () {
      final p = ajustarAlArbol(double.nan, double.infinity);
      expect(p.dx, 0.5);
      expect(p.dy, 0.5);
    });
  });

  test('los pisos coinciden con semiAnchoArbol', () {
    expect(semiAnchoArbol(0.0), isNull);
    expect(semiAnchoArbol(0.95), isNull);
    expect(semiAnchoArbol(0.9), closeTo(0.45, 1e-12));
    // En el solape (piso 2 y 3 a y = 0.55) manda el piso más ancho.
    expect(semiAnchoArbol(0.55), closeTo(pisosArbol[1].anchoEn(0.55), 1e-12));
    expect(semiAnchoArbol(0.55), greaterThan(pisosArbol[2].anchoEn(0.55)));
  });
}
