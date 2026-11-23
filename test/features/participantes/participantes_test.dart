import 'package:flutter_test/flutter_test.dart';
import 'package:planificacion_posada/features/participantes/models/participante.dart';
import 'package:planificacion_posada/features/participantes/repositories/fake_participante_repository.dart';
import 'package:planificacion_posada/features/participantes/viewmodels/participantes_view_model.dart';

import '../../helpers/sesion_prueba.dart';

Future<void> _pausa() => Future<void>.delayed(Duration.zero);

void main() {
  group('Participante', () {
    test('toMap y fromMap usan si, no y tal_vez', () {
      for (final (a, texto) in [
        (Asistencia.si, 'si'),
        (Asistencia.no, 'no'),
        (Asistencia.talVez, 'tal_vez'),
      ]) {
        final p = Participante(id: 'p1', nombre: 'Ana', asistencia: a);
        expect(p.toMap(), {'nombre': 'Ana', 'asistencia': texto});
        final copia = Participante.fromMap('p1', p.toMap());
        expect(copia.id, 'p1');
        expect(copia.nombre, 'Ana');
        expect(copia.asistencia, a);
      }
    });

    test('fromMap con asistencia desconocida usa talVez', () {
      final p = Participante.fromMap('p', {'nombre': 'A', 'asistencia': 'zzz'});
      expect(p.asistencia, Asistencia.talVez);
    });
  });

  const ana = Participante(id: 'u-1', nombre: 'Ana');
  const beto = Participante(id: 'u-2', nombre: 'Beto');
  const caro = Participante(id: 'u-3', nombre: 'Caro');

  Future<ParticipantesViewModel> crear({
    bool admin = false,
    FakeParticipanteRepository? repo,
  }) async {
    final vm = ParticipantesViewModel(
      repo ?? FakeParticipanteRepository(inicial: [ana, beto, caro]),
      sesion: sesionPrueba(admin: admin),
    );
    await _pausa();
    return vm;
  }

  group('ParticipantesViewModel', () {
    test('empieza cargando y luego queda vacío', () async {
      final vm = ParticipantesViewModel(
        FakeParticipanteRepository(),
        sesion: sesionPrueba(),
      );
      expect(vm.cargando, isTrue);
      await _pausa();
      expect(vm.cargando, isFalse);
      expect(vm.participantes, isEmpty);
      expect(vm.vacio, isTrue);
      vm.dispose();
    });

    test('lista a todos los registrados', () async {
      final vm = await crear();
      expect(vm.participantes.map((p) => p.id), ['u-1', 'u-2', 'u-3']);
      vm.dispose();
    });

    test('no expone agregar: la lista son las cuentas registradas', () async {
      final repo = FakeParticipanteRepository();
      final vm = await crear(repo: repo);
      expect(vm.participantes, isEmpty);
      await repo.asegurar('u-9', 'Nueva');
      await _pausa();
      expect(vm.participantes.single.id, 'u-9');
      vm.dispose();
    });

    test('no admin: cambia solo su propia asistencia', () async {
      final vm = await crear();
      expect(vm.puedeCambiarAsistencia('u-1'), isTrue);
      expect(vm.puedeCambiarAsistencia('u-2'), isFalse);
      expect(await vm.cambiarAsistencia('u-1', Asistencia.si), isTrue);
      await _pausa();
      expect(vm.participantes.first.asistencia, Asistencia.si);
      vm.dispose();
    });

    test(
      'no admin: no puede cambiar la de otro (guarda del viewmodel)',
      () async {
        final vm = await crear();
        expect(await vm.cambiarAsistencia('u-2', Asistencia.si), isFalse);
        await _pausa();
        expect(vm.error, 'Solo puedes cambiar tu propia asistencia.');
        expect(vm.participantes[1].asistencia, Asistencia.talVez);
        vm.dispose();
      },
    );

    test('admin: cambia la asistencia de cualquiera', () async {
      final vm = await crear(admin: true);
      expect(vm.puedeCambiarAsistencia('u-2'), isTrue);
      expect(await vm.cambiarAsistencia('u-2', Asistencia.no), isTrue);
      await _pausa();
      expect(vm.participantes[1].asistencia, Asistencia.no);
      vm.dispose();
    });

    test('conteos por Asistencia', () async {
      final vm = await crear(admin: true);
      await vm.cambiarAsistencia('u-1', Asistencia.si);
      await vm.cambiarAsistencia('u-2', Asistencia.no);
      await _pausa();
      expect(vm.conteo(Asistencia.si), 1);
      expect(vm.conteo(Asistencia.no), 1);
      expect(vm.conteo(Asistencia.talVez), 1);
      expect(vm.conteos, {
        Asistencia.si: 1,
        Asistencia.no: 1,
        Asistencia.talVez: 1,
      });
      vm.dispose();
    });

    test('solo el admin puede quitar de la lista', () async {
      final vm = await crear();
      expect(vm.puedeEliminar, isFalse);
      expect(await vm.eliminar('u-2'), isFalse);
      await _pausa();
      expect(vm.error, 'Solo el organizador puede quitar participantes.');
      expect(vm.participantes, hasLength(3));
      vm.dispose();

      final admin = await crear(admin: true);
      expect(admin.puedeEliminar, isTrue);
      expect(await admin.eliminar('u-2'), isTrue);
      await _pausa();
      expect(admin.participantes.map((p) => p.id), ['u-1', 'u-3']);
      admin.dispose();
    });

    test('esYo identifica la fila de la persona con sesión', () async {
      final vm = await crear();
      expect(vm.esYo('u-1'), isTrue);
      expect(vm.esYo('u-2'), isFalse);
      vm.dispose();
    });

    test('un error del stream deja mensaje', () async {
      final repo = FakeParticipanteRepository();
      final vm = ParticipantesViewModel(repo, sesion: sesionPrueba());
      repo.emitirError(Exception('x'));
      await _pausa();
      expect(vm.cargando, isFalse);
      expect(vm.error, contains('No pudimos cargar los participantes'));
      vm.dispose();
    });

    test('dispose cancela la suscripción', () async {
      final repo = FakeParticipanteRepository();
      final vm = ParticipantesViewModel(repo, sesion: sesionPrueba());
      await _pausa();
      vm.dispose();
      expect(repo.escuchas, 0);
    });
  });
}
