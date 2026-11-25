import 'package:flutter_test/flutter_test.dart';
import 'package:planificacion_posada/features/arbol/models/adorno.dart';
import 'package:planificacion_posada/features/arbol/repositories/fake_arbol_repository.dart';
import 'package:planificacion_posada/features/arbol/viewmodels/arbol_view_model.dart';

const _foto = '/9j/4AAQSkZJRg==';

Adorno _conFoto({String foto = _foto}) => Adorno(
  id: 'u1_0',
  tipo: TipoAdorno.esfera,
  autorId: 'u1',
  color: '#D62839',
  patron: PatronEsfera.foto,
  foto: foto,
  x: 0.5,
  y: 0.5,
);

const _rayas = Adorno(
  id: 'u1_1',
  tipo: TipoAdorno.esfera,
  autorId: 'u1',
  color: '#D62839',
  patron: PatronEsfera.rayas,
  x: 0.5,
  y: 0.5,
);

Future<void> _pausa() => Future<void>.delayed(Duration.zero);

void main() {
  group('Adorno con foto', () {
    test('límites: 160 px y 40000 caracteres', () {
      expect(LimitesArbol.ladoFoto, 160);
      expect(LimitesArbol.maxFotoBase64, 40000);
    });

    test('toMap lleva foto y patron foto', () {
      expect(_conFoto().toMap(), {
        'tipo': 'esfera',
        'autor_id': 'u1',
        'color': '#D62839',
        'patron': 'foto',
        'foto': _foto,
        'mensaje': '',
        'x': 0.5,
        'y': 0.5,
      });
    });

    test('una esfera sin foto no lleva la clave foto', () {
      expect(_rayas.toMap().containsKey('foto'), isFalse);
    });

    test('fromMap lee la foto y toMap la devuelve igual', () {
      final a = Adorno.fromMap('u1_0', _conFoto().toMap());
      expect(a.patron, PatronEsfera.foto);
      expect(a.foto, _foto);
      expect(a.toMap(), _conFoto().toMap());
    });

    test('fromMap sigue leyendo esferas viejas sin foto', () {
      final a = Adorno.fromMap('u1_1', _rayas.toMap());
      expect(a.patron, PatronEsfera.rayas);
      expect(a.foto, isNull);
    });

    test('fromMap rechaza patron foto sin foto, vacía o que no es texto', () {
      for (final f in <Object?>[null, '', 5]) {
        final m = {..._conFoto().toMap(), 'foto': f};
        expect(() => Adorno.fromMap('u1_0', m), throwsFormatException);
      }
    });

    test('fromMap ignora una foto en una esfera con otro patrón', () {
      final a = Adorno.fromMap('u1_1', {..._rayas.toMap(), 'foto': _foto});
      expect(a.foto, isNull);
      expect(a.toMap().containsKey('foto'), isFalse);
    });

    test('fromMap: un regalo nunca tiene foto', () {
      final a = Adorno.fromMap('u1_2', {
        'tipo': 'regalo',
        'autor_id': 'u1',
        'color': '#FFC857',
        'color_mono': '#2FBF71',
        'foto': _foto,
        'x': 0.4,
        'y': 0.7,
      });
      expect(a.foto, isNull);
      expect(a.toMap().containsKey('foto'), isFalse);
    });

    test('copyWith conserva la foto y la quita al cambiar de patrón', () {
      final a = _conFoto();
      expect(a.copyWith(color: '#FFC857').foto, _foto);
      final b = a.copyWith(patron: PatronEsfera.rayas);
      expect(b.patron, PatronEsfera.rayas);
      expect(b.foto, isNull);
      expect(b.toMap().containsKey('foto'), isFalse);
      expect(
        _rayas.copyWith(patron: PatronEsfera.foto, foto: 'abc').foto,
        'abc',
      );
    });

    test('invariante: foto solo con patron foto y nunca en regalos', () {
      expect(
        () => Adorno(
          id: 'u1_0',
          tipo: TipoAdorno.esfera,
          autorId: 'u1',
          color: '#D62839',
          patron: PatronEsfera.foto,
          x: 0,
          y: 0,
        ),
        throwsAssertionError,
      );
      expect(
        () => Adorno(
          id: 'u1_0',
          tipo: TipoAdorno.esfera,
          autorId: 'u1',
          color: '#D62839',
          patron: PatronEsfera.liso,
          foto: _foto,
          x: 0,
          y: 0,
        ),
        throwsAssertionError,
      );
      expect(
        () => Adorno(
          id: 'u1_0',
          tipo: TipoAdorno.regalo,
          autorId: 'u1',
          color: '#D62839',
          colorMono: '#2FBF71',
          foto: _foto,
          x: 0,
          y: 0,
        ),
        throwsAssertionError,
      );
    });

    test('PatronEsfera.foto tiene clave foto', () {
      expect(PatronEsfera.desdeClave('foto'), PatronEsfera.foto);
      expect(PatronEsfera.foto.clave, 'foto');
    });
  });

  group('ArbolViewModel con foto', () {
    ArbolViewModel vm(FakeArbolRepository repo) =>
        ArbolViewModel(repo, uid: 'u1', esAdmin: false, esParticipante: true);

    test('crearEsfera con patron foto guarda la foto', () async {
      final repo = FakeArbolRepository();
      final v = vm(repo);
      await _pausa();
      expect(
        await v.crearEsfera(
          color: '#D62839',
          patron: PatronEsfera.foto,
          foto: _foto,
        ),
        isTrue,
      );
      await _pausa();
      expect(v.adornos.single.foto, _foto);
      expect(v.adornos.single.patron, PatronEsfera.foto);
      v.dispose();
    });

    test(
      'patron foto sin foto, vacía o enorme se rechaza sin guardar',
      () async {
        final repo = FakeArbolRepository();
        final v = vm(repo);
        await _pausa();
        for (final (f, msg) in [
          (null, 'Toma una foto para la esfera.'),
          ('', 'Toma una foto para la esfera.'),
          (
            'a' * (LimitesArbol.maxFotoBase64 + 1),
            'La foto es demasiado grande. Toma otra.',
          ),
        ]) {
          expect(
            await v.crearEsfera(
              color: '#D62839',
              patron: PatronEsfera.foto,
              foto: f,
            ),
            isFalse,
          );
          expect(v.error, msg);
        }
        expect(v.adornos, isEmpty);
        v.dispose();
      },
    );

    test('una foto de exactamente el límite se acepta', () async {
      final v = vm(FakeArbolRepository());
      await _pausa();
      expect(
        await v.crearEsfera(
          color: '#D62839',
          patron: PatronEsfera.foto,
          foto: 'a' * LimitesArbol.maxFotoBase64,
        ),
        isTrue,
      );
      v.dispose();
    });

    test('foto con otro patrón se descarta al crear', () async {
      final v = vm(FakeArbolRepository());
      await _pausa();
      await v.crearEsfera(
        color: '#D62839',
        patron: PatronEsfera.liso,
        foto: _foto,
      );
      await _pausa();
      expect(v.adornos.single.foto, isNull);
      v.dispose();
    });

    test('editar: conserva la foto, y la quita al cambiar de patrón', () async {
      final repo = FakeArbolRepository(inicial: [_conFoto()]);
      final v = vm(repo);
      await _pausa();
      expect(await v.editar('u1_0', color: '#FFC857'), isTrue);
      await _pausa();
      expect(v.adornos.single.foto, _foto);
      await _pausa();
      expect(v.adornos.single.color, '#FFC857');

      expect(await v.editar('u1_0', patron: PatronEsfera.rayas), isTrue);
      await _pausa();
      expect(v.adornos.single.patron, PatronEsfera.rayas);
      await _pausa();
      expect(v.adornos.single.foto, isNull);
      v.dispose();
    });

    test(
      'editar: cambiar a patron foto exige foto y guarda la nueva',
      () async {
        final repo = FakeArbolRepository(inicial: [_rayas]);
        final v = vm(repo);
        await _pausa();
        expect(await v.editar('u1_1', patron: PatronEsfera.foto), isFalse);
        expect(v.error, 'Toma una foto para la esfera.');
        expect(v.adornos.single.patron, PatronEsfera.rayas);

        expect(
          await v.editar('u1_1', patron: PatronEsfera.foto, foto: 'nueva'),
          isTrue,
        );
        await _pausa();
        expect(v.adornos.single.foto, 'nueva');
        v.dispose();
      },
    );
  });
}
