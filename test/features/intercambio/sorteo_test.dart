import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:planificacion_posada/features/intercambio/utilidades/formato.dart';
import 'package:planificacion_posada/features/intercambio/utilidades/sorteo.dart';

void main() {
  group('sortearParejas', () {
    for (var n = 2; n <= 50; n++) {
      test('n=$n: sin puntos fijos, un solo ciclo, todos incluidos', () {
        for (var semilla = 0; semilla < 20; semilla++) {
          final ids = [for (var i = 0; i < n; i++) 'u$i'];
          final r = sortearParejas(ids, Random(semilla * 31 + n));
          expect(r.keys.toSet(), ids.toSet());
          expect(r.values.toSet(), ids.toSet(), reason: 'cada quien recibe 1');
          for (final e in r.entries) {
            expect(e.value, isNot(e.key));
          }
          var actual = ids.first;
          var pasos = 0;
          do {
            actual = r[actual]!;
            pasos++;
          } while (actual != ids.first);
          expect(pasos, n, reason: 'un único ciclo');
        }
      });
    }

    test('es reproducible con la misma semilla y no depende del orden', () {
      final a = sortearParejas(['c', 'a', 'b', 'd'], Random(7));
      final b = sortearParejas(['a', 'b', 'c', 'd'], Random(7));
      expect(a, b);
    });

    test('con 2 ids se intercambian', () {
      expect(sortearParejas(['a', 'b'], Random(1)), {'a': 'b', 'b': 'a'});
    });

    test('rechaza menos de 2 ids y ids repetidos', () {
      expect(() => sortearParejas(['a'], Random(1)), throwsArgumentError);
      expect(() => sortearParejas([], Random(1)), throwsArgumentError);
      expect(() => sortearParejas(['a', 'a'], Random(1)), throwsArgumentError);
    });
  });

  group('formato', () {
    test('formatearMonto', () {
      expect(formatearMonto(0), '\$0.00');
      expect(formatearMonto(5), '\$0.05');
      expect(formatearMonto(123450), '\$1,234.50');
      expect(formatearMonto(100000000), '\$1,000,000.00');
      expect(formatearMonto(-250), '-\$2.50');
    });

    test('parsearMonto', () {
      expect(parsearMonto('250'), 25000);
      expect(parsearMonto('\$1,234.5'), 123450);
      expect(parsearMonto('99.99'), 9999);
      expect(parsearMonto(''), isNull);
      expect(parsearMonto('abc'), isNull);
      expect(parsearMonto('1.234'), isNull);
      expect(parsearMonto('-5'), isNull);
    });

    test('cuentaRegresiva y formatearFecha', () {
      final hoy = DateTime(2026, 12, 10, 15);
      expect(cuentaRegresiva(DateTime(2026, 12, 18), hoy), 'Faltan 8 días');
      expect(cuentaRegresiva(DateTime(2026, 12, 11, 1), hoy), '¡Es mañana!');
      expect(cuentaRegresiva(DateTime(2026, 12, 10, 1), hoy), '¡Es hoy!');
      expect(cuentaRegresiva(DateTime(2026, 12, 1), hoy), 'Ya pasó');
      expect(formatearFecha(DateTime(2026, 12, 18)), '18 de diciembre de 2026');
    });
  });
}
