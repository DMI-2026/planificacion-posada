import 'package:flutter_test/flutter_test.dart';
import 'package:planificacion_posada/features/evento/models/evento.dart';
import 'package:planificacion_posada/features/evento/repositories/fake_evento_repository.dart';
import 'package:planificacion_posada/features/evento/viewmodels/evento_view_model.dart';

void main() {
  final fecha = DateTime(2026, 12, 18, 19);

  group('Evento', () {
    test('toMap y fromMap son inversos y usan los campos de Firestore', () {
      final evento = Evento(
        nombre: 'Posada DMI',
        fecha: fecha,
        lugar: 'Aula 5',
        notas: 'Traer ponche',
      );
      final mapa = evento.toMap();
      expect(mapa, {
        'nombre': 'Posada DMI',
        'fecha': fecha,
        'lugar': 'Aula 5',
        'notas': 'Traer ponche',
      });
      final copia = Evento.fromMap(mapa);
      expect(copia.nombre, 'Posada DMI');
      expect(copia.fecha, fecha);
      expect(copia.lugar, 'Aula 5');
      expect(copia.notas, 'Traer ponche');
    });

    test('fromMap tolera lugar y notas ausentes', () {
      final e = Evento.fromMap({'nombre': 'X', 'fecha': fecha});
      expect(e.lugar, '');
      expect(e.notas, '');
    });
  });

  group('EventoViewModel', () {
    test('empieza cargando y luego expone el evento', () async {
      final repo = FakeEventoRepository();
      final vm = EventoViewModel(repo);
      expect(vm.cargando, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(vm.cargando, isFalse);
      expect(vm.evento, isNull);
      expect(vm.error, isNull);
      vm.dispose();
    });

    test('guardar actualiza el evento y notifica', () async {
      final vm = EventoViewModel(FakeEventoRepository());
      await Future<void>.delayed(Duration.zero);
      final ok = await vm.guardar(
        nombre: '  Posada  ',
        fecha: fecha,
        lugar: 'Aula',
        notas: '',
      );
      await Future<void>.delayed(Duration.zero);
      expect(ok, isTrue);
      expect(vm.evento!.nombre, 'Posada');
      expect(vm.error, isNull);
      vm.dispose();
    });

    test('rechaza un nombre vacío sin guardar', () async {
      final repo = FakeEventoRepository();
      final vm = EventoViewModel(repo);
      await Future<void>.delayed(Duration.zero);
      final ok = await vm.guardar(
        nombre: '   ',
        fecha: fecha,
        lugar: '',
        notas: '',
      );
      await Future<void>.delayed(Duration.zero);
      expect(ok, isFalse);
      expect(vm.error, 'El nombre del evento no puede estar vacío.');
      expect(vm.evento, isNull);
      vm.dispose();
    });

    test('un fallo del repositorio deja un error', () async {
      final repo = FakeEventoRepository()..falla = true;
      final vm = EventoViewModel(repo);
      await Future<void>.delayed(Duration.zero);
      final ok = await vm.guardar(
        nombre: 'A',
        fecha: fecha,
        lugar: '',
        notas: '',
      );
      expect(ok, isFalse);
      expect(vm.error, contains('No pudimos guardar el evento'));
      vm.dispose();
    });

    test('un error en el stream deja error y quita cargando', () async {
      final repo = FakeEventoRepository();
      final vm = EventoViewModel(repo);
      repo.emitirError(Exception('x'));
      await Future<void>.delayed(Duration.zero);
      expect(vm.cargando, isFalse);
      expect(vm.error, contains('No pudimos cargar el evento'));
      vm.dispose();
    });
  });
}
