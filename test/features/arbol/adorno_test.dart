import 'package:flutter_test/flutter_test.dart';
import 'package:planificacion_posada/features/arbol/models/adorno.dart';

void main() {
  group('Adorno', () {
    test('esfera: toMap tiene las claves exactas y no lleva fechas', () {
      const a = Adorno(
        id: 'u1_3',
        tipo: TipoAdorno.esfera,
        autorId: 'u1',
        color: '#D62839',
        patron: PatronEsfera.rayas,
        mensaje: 'Hola',
        x: 0.5,
        y: 0.25,
      );
      expect(a.toMap(), {
        'tipo': 'esfera',
        'autor_id': 'u1',
        'color': '#D62839',
        'patron': 'rayas',
        'mensaje': 'Hola',
        'x': 0.5,
        'y': 0.25,
      });
    });

    test('regalo: toMap lleva color_mono y no patron', () {
      const a = Adorno(
        id: 'u1_0',
        tipo: TipoAdorno.regalo,
        autorId: 'u1',
        color: '#FFC857',
        colorMono: '#2FBF71',
        x: 0.4,
        y: 0.7,
      );
      expect(a.toMap().keys.toSet(), {
        'tipo',
        'autor_id',
        'color',
        'color_mono',
        'mensaje',
        'x',
        'y',
      });
      expect(a.toMap()['mensaje'], '');
    });

    test('fromMap lee los campos, acepta enteros y fechas', () {
      final c = DateTime(2026, 12, 1);
      final a = Adorno.fromMap('u2_7', {
        'tipo': 'esfera',
        'autor_id': 'u2',
        'color': '#2EE6C8',
        'patron': 'estrellas',
        'mensaje': 'Feliz',
        'x': 1,
        'y': 0.3,
      }, creado: c);
      expect(a.id, 'u2_7');
      expect(a.slot, 7);
      expect(a.patron, PatronEsfera.estrellas);
      expect(a.x, 1.0);
      expect(a.creado, c);
      expect(a.actualizado, isNull);
    });

    test(
      'fromMap con datos incompletos o desconocidos lanza FormatException',
      () {
        expect(
          () => Adorno.fromMap('a_0', {'tipo': 'estrella'}),
          throwsFormatException,
        );
        expect(
          () => Adorno.fromMap('a_0', {
            'tipo': 'esfera',
            'autor_id': 'a',
            'color': '#D62839',
            'patron': 'lunares',
            'x': 0.1,
            'y': 0.1,
          }),
          throwsFormatException,
        );
        expect(
          () => Adorno.fromMap('a_0', {'tipo': 'esfera', 'autor_id': 'a'}),
          throwsFormatException,
        );
      },
    );

    test('esfera sin patrón no es válida (assert)', () {
      expect(
        () => Adorno(
          id: 'a_0',
          tipo: TipoAdorno.esfera,
          autorId: 'a',
          color: '#D62839',
          x: 0,
          y: 0,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('idDe y slot', () {
      expect(Adorno.idDe('abc', 4), 'abc_4');
      expect(
        const Adorno(
          id: 'abc_4',
          tipo: TipoAdorno.regalo,
          autorId: 'abc',
          color: '#D62839',
          colorMono: '#FFC857',
          x: 0,
          y: 0,
        ).slot,
        4,
      );
    });

    test('copyWith conserva tipo, autor e id', () {
      const a = Adorno(
        id: 'u1_1',
        tipo: TipoAdorno.regalo,
        autorId: 'u1',
        color: '#D62839',
        colorMono: '#FFC857',
        x: 0.1,
        y: 0.2,
      );
      final b = a.copyWith(x: 0.9, patron: PatronEsfera.liso);
      expect(b.x, 0.9);
      expect(b.patron, isNull);
      expect(b.id, 'u1_1');
      expect(b.colorMono, '#FFC857');
    });

    test('la paleta tiene 10 colores únicos en formato #RRGGBB', () {
      expect(PaletaArbol.colores.length, 10);
      expect(PaletaArbol.colores.toSet().length, 10);
      final formato = RegExp(r'^#[0-9A-F]{6}$');
      expect(PaletaArbol.colores.every(formato.hasMatch), isTrue);
      expect(PaletaArbol.esValido('#D62839'), isTrue);
      expect(PaletaArbol.esValido('#123456'), isFalse);
      expect(PaletaArbol.esValido(null), isFalse);
    });
  });
}
