import 'package:flutter_test/flutter_test.dart';
import 'package:planificacion_posada/features/aportaciones/repositories/fake_aportacion_repository.dart';
import 'package:planificacion_posada/features/aportaciones/viewmodels/aportaciones_view_model.dart';

import '../../helpers/sesion_prueba.dart';

void main() {
  group('Límites de aportaciones (iguales a firestore.rules)', () {
    test('acepta artículo de 100 y cantidad 999', () async {
      final vm = AportacionesViewModel(
        FakeAportacionRepository(),
        sesion: sesionPrueba(admin: true),
      );
      await Future<void>.delayed(Duration.zero);
      expect(await vm.agregar('a' * 100, 999), isTrue);
      expect(vm.error, isNull);
      vm.dispose();
    });

    test('rechaza artículo de más de 100 sin guardar', () async {
      final vm = AportacionesViewModel(
        FakeAportacionRepository(),
        sesion: sesionPrueba(admin: true),
      );
      await Future<void>.delayed(Duration.zero);
      expect(await vm.agregar('a' * 101, 1), isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(vm.error, 'El artículo no puede pasar de 100 caracteres.');
      expect(vm.aportaciones, isEmpty);
      vm.dispose();
    });

    test('rechaza cantidad mayor a 999 sin guardar', () async {
      final vm = AportacionesViewModel(
        FakeAportacionRepository(),
        sesion: sesionPrueba(admin: true),
      );
      await Future<void>.delayed(Duration.zero);
      expect(await vm.agregar('Ponche', 1000), isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(vm.error, 'La cantidad no puede pasar de 999.');
      expect(vm.aportaciones, isEmpty);
      vm.dispose();
    });
  });
}
