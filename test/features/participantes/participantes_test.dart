import 'package:flutter_test/flutter_test.dart';
import 'package:planificacion_posada/features/participantes/models/participante.dart';
import 'package:planificacion_posada/features/participantes/repositories/fake_participante_repository.dart';
import 'package:planificacion_posada/features/participantes/viewmodels/participantes_view_model.dart';

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

  group('ParticipantesViewModel', () {
    test('empieza cargando y luego queda vacío', () async {
      final vm = ParticipantesViewModel(FakeParticipanteRepository());
      expect(vm.cargando, isTrue);
      await _pausa();
      expect(vm.cargando, isFalse);
      expect(vm.participantes, isEmpty);
      expect(vm.vacio, isTrue);
      vm.dispose();
    });

    test('agregar recorta el nombre y empieza en talVez', () async {
      final vm = ParticipantesViewModel(FakeParticipanteRepository());
      await _pausa();
      expect(await vm.agregar('  Ana  '), isTrue);
      await _pausa();
      expect(vm.participantes.single.nombre, 'Ana');
      expect(vm.participantes.single.asistencia, Asistencia.talVez);
      vm.dispose();
    });

    test('rechaza nombre vacío o de espacios', () async {
      final vm = ParticipantesViewModel(FakeParticipanteRepository());
      await _pausa();
      expect(await vm.agregar('   '), isFalse);
      await _pausa();
      expect(vm.error, 'El nombre del participante no puede estar vacío.');
      expect(vm.participantes, isEmpty);
      vm.dispose();
    });

    test('un agregado válido limpia el error previo', () async {
      final vm = ParticipantesViewModel(FakeParticipanteRepository());
      await _pausa();
      await vm.agregar('');
      await vm.agregar('Ana');
      expect(vm.error, isNull);
      vm.dispose();
    });

    test('cambiarAsistencia y conteos por Asistencia', () async {
      final vm = ParticipantesViewModel(FakeParticipanteRepository());
      await _pausa();
      await vm.agregar('Ana');
      await vm.agregar('Beto');
      await vm.agregar('Caro');
      await _pausa();
      await vm.cambiarAsistencia(vm.participantes[0].id, Asistencia.si);
      await vm.cambiarAsistencia(vm.participantes[1].id, Asistencia.no);
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

    test('eliminar quita al participante', () async {
      final vm = ParticipantesViewModel(FakeParticipanteRepository());
      await _pausa();
      await vm.agregar('Ana');
      await _pausa();
      await vm.eliminar(vm.participantes.single.id);
      await _pausa();
      expect(vm.participantes, isEmpty);
      vm.dispose();
    });

    test('un error del stream deja mensaje', () async {
      final repo = FakeParticipanteRepository();
      final vm = ParticipantesViewModel(repo);
      repo.emitirError(Exception('x'));
      await _pausa();
      expect(vm.cargando, isFalse);
      expect(vm.error, contains('No pudimos cargar los participantes'));
      vm.dispose();
    });

    test('dispose cancela la suscripción', () async {
      final repo = FakeParticipanteRepository();
      final vm = ParticipantesViewModel(repo);
      await _pausa();
      vm.dispose();
      expect(repo.escuchas, 0);
    });
  });
}
