import 'package:flutter_test/flutter_test.dart';
import 'package:planificacion_posada/features/aportaciones/models/aportacion.dart';
import 'package:planificacion_posada/features/aportaciones/repositories/fake_aportacion_repository.dart';
import 'package:planificacion_posada/features/aportaciones/viewmodels/aportaciones_view_model.dart';
import 'package:planificacion_posada/features/participantes/models/participante.dart';

Future<void> _pausa() => Future<void>.delayed(Duration.zero);

void main() {
  group('Aportacion', () {
    test('toMap y fromMap usan los campos de Firestore', () {
      const a = Aportacion(
        id: 'a1',
        articulo: 'Ponche',
        cantidad: 3,
        responsableId: 'p1',
        lista: true,
      );
      expect(a.toMap(), {
        'articulo': 'Ponche',
        'cantidad': 3,
        'responsable_id': 'p1',
        'lista': true,
      });
      final c = Aportacion.fromMap('a1', a.toMap());
      expect(c.id, 'a1');
      expect(c.articulo, 'Ponche');
      expect(c.cantidad, 3);
      expect(c.responsableId, 'p1');
      expect(c.lista, isTrue);
    });

    test('fromMap sin responsable ni lista usa null y false', () {
      final c = Aportacion.fromMap('a', {'articulo': 'X', 'cantidad': 1});
      expect(c.responsableId, isNull);
      expect(c.lista, isFalse);
    });

    test('cantidad menor a 1 no es válida', () {
      expect(
        () => Aportacion(id: 'a', articulo: 'X', cantidad: 0),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('AportacionesViewModel', () {
    test('empieza cargando y luego queda vacío', () async {
      final vm = AportacionesViewModel(FakeAportacionRepository());
      expect(vm.cargando, isTrue);
      await _pausa();
      expect(vm.cargando, isFalse);
      expect(vm.vacio, isTrue);
      vm.dispose();
    });

    test(
      'agregar recorta el artículo; empieza sin responsable y pendiente',
      () async {
        final vm = AportacionesViewModel(FakeAportacionRepository());
        await _pausa();
        expect(await vm.agregar('  Piñata ', 2), isTrue);
        await _pausa();
        final a = vm.aportaciones.single;
        expect(a.articulo, 'Piñata');
        expect(a.cantidad, 2);
        expect(a.responsableId, isNull);
        expect(a.lista, isFalse);
        vm.dispose();
      },
    );

    test('rechaza artículo vacío', () async {
      final vm = AportacionesViewModel(FakeAportacionRepository());
      await _pausa();
      expect(await vm.agregar('  ', 1), isFalse);
      await _pausa();
      expect(vm.error, 'El artículo no puede estar vacío.');
      expect(vm.aportaciones, isEmpty);
      vm.dispose();
    });

    test('rechaza cantidad menor a 1', () async {
      final vm = AportacionesViewModel(FakeAportacionRepository());
      await _pausa();
      expect(await vm.agregar('Ponche', 0), isFalse);
      await _pausa();
      expect(vm.error, 'La cantidad debe ser al menos 1.');
      expect(vm.aportaciones, isEmpty);
      vm.dispose();
    });

    test('asignar, marcarLista y conteos', () async {
      final vm = AportacionesViewModel(FakeAportacionRepository());
      await _pausa();
      await vm.agregar('A', 1);
      await vm.agregar('B', 1);
      await _pausa();
      expect(vm.pendientes, 2);
      expect(vm.listas, 0);
      await vm.asignar(vm.aportaciones[0].id, 'p1');
      await vm.marcarLista(vm.aportaciones[0].id, true);
      await _pausa();
      expect(vm.aportaciones[0].responsableId, 'p1');
      expect(vm.pendientes, 1);
      expect(vm.listas, 1);
      await vm.asignar(vm.aportaciones[0].id, null);
      await _pausa();
      expect(vm.aportaciones[0].responsableId, isNull);
      vm.dispose();
    });

    test('eliminar quita la aportación', () async {
      final vm = AportacionesViewModel(FakeAportacionRepository());
      await _pausa();
      await vm.agregar('A', 1);
      await _pausa();
      await vm.eliminar(vm.aportaciones.single.id);
      await _pausa();
      expect(vm.aportaciones, isEmpty);
      vm.dispose();
    });

    test('nombreResponsable resuelve con la lista de participantes', () async {
      final vm = AportacionesViewModel(FakeAportacionRepository());
      await _pausa();
      await vm.agregar('A', 1);
      await _pausa();
      const ana = Participante(
        id: 'p1',
        nombre: 'Ana',
        asistencia: Asistencia.si,
      );
      final a = vm.aportaciones.single;
      expect(vm.nombreResponsable(a, [ana]), 'Sin asignar');
      await vm.asignar(a.id, 'p1');
      await _pausa();
      expect(vm.nombreResponsable(vm.aportaciones.single, [ana]), 'Ana');
      expect(
        vm.nombreResponsable(vm.aportaciones.single, const []),
        'Sin asignar',
      );
      vm.dispose();
    });

    test('un error del stream deja mensaje', () async {
      final repo = FakeAportacionRepository();
      final vm = AportacionesViewModel(repo);
      repo.emitirError(Exception('x'));
      await _pausa();
      expect(vm.cargando, isFalse);
      expect(vm.error, contains('No pudimos cargar las aportaciones'));
      vm.dispose();
    });

    test('dispose cancela la suscripción', () async {
      final repo = FakeAportacionRepository();
      final vm = AportacionesViewModel(repo);
      await _pausa();
      vm.dispose();
      expect(repo.escuchas, 0);
    });
  });
}
