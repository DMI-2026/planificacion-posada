import 'package:flutter_test/flutter_test.dart';
import 'package:planificacion_posada/features/evento/repositories/fake_evento_repository.dart';
import 'package:planificacion_posada/features/evento/viewmodels/evento_view_model.dart';

void main() {
  final fecha = DateTime(2026, 12, 18, 19);

  Future<(EventoViewModel, bool)> guardar({
    String nombre = 'Posada',
    String lugar = '',
    String notas = '',
  }) async {
    final vm = EventoViewModel(FakeEventoRepository());
    await Future<void>.delayed(Duration.zero);
    final ok = await vm.guardar(
      nombre: nombre,
      fecha: fecha,
      lugar: lugar,
      notas: notas,
    );
    await Future<void>.delayed(Duration.zero);
    return (vm, ok);
  }

  group('Límites del evento (iguales a firestore.rules)', () {
    test('acepta nombre de 100, lugar de 200 y notas de 1000', () async {
      final (vm, ok) = await guardar(
        nombre: 'n' * 100,
        lugar: 'l' * 200,
        notas: 'x' * 1000,
      );
      expect(ok, isTrue);
      expect(vm.error, isNull);
      vm.dispose();
    });

    test('rechaza nombre de más de 100', () async {
      final (vm, ok) = await guardar(nombre: 'n' * 101);
      expect(ok, isFalse);
      expect(vm.error, 'El nombre no puede pasar de 100 caracteres.');
      expect(vm.evento?.nombre, isNot('n' * 101));
      vm.dispose();
    });

    test('rechaza lugar de más de 200', () async {
      final (vm, ok) = await guardar(lugar: 'l' * 201);
      expect(ok, isFalse);
      expect(vm.error, 'El lugar no puede pasar de 200 caracteres.');
      vm.dispose();
    });

    test('rechaza notas de más de 1000', () async {
      final (vm, ok) = await guardar(notas: 'x' * 1001);
      expect(ok, isFalse);
      expect(vm.error, 'Las notas no pueden pasar de 1000 caracteres.');
      vm.dispose();
    });
  });
}
