import 'package:flutter_test/flutter_test.dart';
import 'package:planificacion_posada/features/participantes/repositories/fake_participante_repository.dart';
import 'package:planificacion_posada/features/participantes/viewmodels/participantes_view_model.dart';

void main() {
  group('Límites de participantes (iguales a firestore.rules)', () {
    test('acepta nombre de 100 caracteres', () async {
      final vm = ParticipantesViewModel(FakeParticipanteRepository());
      await Future<void>.delayed(Duration.zero);
      expect(await vm.agregar('n' * 100), isTrue);
      expect(vm.error, isNull);
      vm.dispose();
    });

    test('rechaza nombre de más de 100 sin guardar', () async {
      final vm = ParticipantesViewModel(FakeParticipanteRepository());
      await Future<void>.delayed(Duration.zero);
      expect(await vm.agregar('n' * 101), isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(vm.error, 'El nombre no puede pasar de 100 caracteres.');
      expect(vm.participantes, isEmpty);
      vm.dispose();
    });
  });
}
