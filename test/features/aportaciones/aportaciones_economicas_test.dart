import 'package:flutter_test/flutter_test.dart';
import 'package:planificacion_posada/features/aportaciones/models/aportacion.dart';
import 'package:planificacion_posada/features/aportaciones/repositories/fake_aportacion_repository.dart';
import 'package:planificacion_posada/features/aportaciones/utils/dinero.dart';
import 'package:planificacion_posada/features/aportaciones/viewmodels/aportaciones_view_model.dart';

import '../../helpers/sesion_prueba.dart';

Future<void> _pausa() => Future<void>.delayed(Duration.zero);

void main() {
  group('formatoDinero', () {
    test('formatea centavos con miles y dos decimales', () {
      expect(formatoDinero(123450), r'$1,234.50');
      expect(formatoDinero(0), r'$0.00');
      expect(formatoDinero(5), r'$0.05');
      expect(formatoDinero(100), r'$1.00');
      expect(formatoDinero(10000000), r'$100,000.00');
      expect(formatoDinero(123456789), r'$1,234,567.89');
      expect(formatoDinero(-250), r'-$2.50');
    });
  });

  group('centavosDeTexto', () {
    test('lee montos válidos', () {
      expect(centavosDeTexto('12'), 1200);
      expect(centavosDeTexto('12.5'), 1250);
      expect(centavosDeTexto(r' $1,234.05 '), 123405);
    });
    test('rechaza montos inválidos', () {
      for (final t in ['', 'abc', '1.234', '-5', '1e3', '.5', '1.']) {
        expect(centavosDeTexto(t), isNull, reason: t);
      }
    });
  });

  group('Aportacion económica', () {
    test('toMap y fromMap', () {
      const a = Aportacion.economica(
        id: 'e1',
        responsableId: 'u-1',
        montoCentavos: 5000,
        recibido: true,
      );
      expect(a.toMap(), {
        'tipo': 'economica',
        'responsable_id': 'u-1',
        'monto_centavos': 5000,
        'recibido': true,
      });
      final c = Aportacion.fromMap('e1', a.toMap());
      expect(c.tipo, TipoAportacion.economica);
      expect(c.esEconomica, isTrue);
      expect(c.responsableId, 'u-1');
      expect(c.montoCentavos, 5000);
      expect(c.recibido, isTrue);
    });

    test('fromMap sin tipo es material (documentos anteriores)', () {
      final c = Aportacion.fromMap('a', {
        'articulo': 'X',
        'cantidad': 2,
        'responsable_id': null,
        'lista': false,
      });
      expect(c.tipo, TipoAportacion.material);
      expect(c.esMaterial, isTrue);
    });

    test('monto menor a 1 no es válido', () {
      expect(
        () =>
            Aportacion.economica(id: 'e', responsableId: 'u', montoCentavos: 0),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('AportacionesViewModel económicas', () {
    const e1 = Aportacion.economica(
      id: 'e-1',
      responsableId: 'u-1',
      montoCentavos: 10000,
    );
    const e2 = Aportacion.economica(
      id: 'e-2',
      responsableId: 'u-2',
      montoCentavos: 5000,
      recibido: true,
    );
    const m1 = Aportacion(id: 'm-1', articulo: 'Ponche', cantidad: 1);

    Future<(AportacionesViewModel, FakeAportacionRepository)> crear({
      bool admin = false,
      int? meta,
      List<Aportacion> inicial = const [m1, e1, e2],
    }) async {
      final repo = FakeAportacionRepository(
        inicial: inicial,
        metaInicial: meta,
      );
      final vm = AportacionesViewModel(
        repo,
        sesion: sesionPrueba(admin: admin),
      );
      await _pausa();
      return (vm, repo);
    }

    test('separa listas y calcula totales y progreso', () async {
      final (vm, _) = await crear(meta: 30000);
      expect(vm.materiales.map((a) => a.id), ['m-1']);
      expect(vm.economicas.map((a) => a.id), ['e-1', 'e-2']);
      expect(vm.totalComprometido, 15000);
      expect(vm.totalRecibido, 5000);
      expect(vm.meta, 30000);
      expect(vm.progreso, closeTo(5000 / 30000, 1e-9));
      expect(vm.metaAlcanzada, isFalse);
      vm.dispose();
    });

    test('sin meta el progreso es 0; meta alcanzada se acota a 1', () async {
      final (vm, repo) = await crear();
      expect(vm.meta, isNull);
      expect(vm.progreso, 0);
      expect(vm.metaAlcanzada, isFalse);
      await repo.guardarMeta(4000);
      await _pausa();
      expect(vm.progreso, 1);
      expect(vm.metaAlcanzada, isTrue);
      await repo.guardarMeta(0);
      await _pausa();
      expect(vm.progreso, 0);
      expect(vm.metaAlcanzada, isFalse);
      vm.dispose();
    });

    test('no admin registra la suya, sin recibir', () async {
      final (vm, repo) = await crear(inicial: const []);
      expect(await vm.agregarEconomica(2550), isTrue);
      await _pausa();
      final a = vm.economicas.single;
      expect(a.responsableId, 'u-1');
      expect(a.montoCentavos, 2550);
      expect(a.recibido, isFalse);
      expect(repo.escrituras, 1);
      vm.dispose();
    });

    test('no admin no registra para otro', () async {
      final (vm, repo) = await crear(inicial: const []);
      expect(await vm.agregarEconomica(2550, responsableId: 'u-2'), isFalse);
      await _pausa();
      expect(vm.error, 'Solo puedes registrar tus propias aportaciones.');
      expect(vm.economicas, isEmpty);
      expect(repo.escrituras, 0);
      vm.dispose();
    });

    test('admin registra para cualquiera', () async {
      final (vm, _) = await crear(admin: true, inicial: const []);
      expect(await vm.agregarEconomica(100, responsableId: 'u-2'), isTrue);
      await _pausa();
      expect(vm.economicas.single.responsableId, 'u-2');
      vm.dispose();
    });

    test('valida el monto (1 centavo a \$100,000.00) sin escribir', () async {
      final (vm, repo) = await crear(inicial: const []);
      expect(await vm.agregarEconomica(0), isFalse);
      expect(vm.error, r'El monto debe ser de al menos $0.01.');
      expect(await vm.agregarEconomica(10000001), isFalse);
      expect(vm.error, r'El monto no puede pasar de $100,000.00.');
      expect(repo.escrituras, 0);
      expect(await vm.agregarEconomica(10000000), isTrue);
      expect(await vm.agregarEconomica(1), isTrue);
      expect(repo.escrituras, 2);
      vm.dispose();
    });

    test('responsable edita y elimina la suya mientras no se recibe', () async {
      final (vm, _) = await crear();
      expect(vm.puedeEditarEconomica(e1), isTrue);
      expect(vm.puedeEliminarAportacion(e1), isTrue);
      expect(await vm.editarMonto('e-1', 2000), isTrue);
      await _pausa();
      expect(vm.economicas.first.montoCentavos, 2000);
      expect(await vm.editarMonto('e-1', 0), isFalse);
      expect(vm.error, r'El monto debe ser de al menos $0.01.');
      expect(await vm.eliminar('e-1'), isTrue);
      await _pausa();
      expect(vm.economicas.map((a) => a.id), ['e-2']);
      vm.dispose();
    });

    test('no admin no toca la de otro ni la ya recibida', () async {
      final (vm, repo) = await crear(
        inicial: const [
          e1,
          e2,
          Aportacion.economica(
            id: 'e-3',
            responsableId: 'u-1',
            montoCentavos: 700,
            recibido: true,
          ),
        ],
      );
      expect(vm.puedeEditarEconomica(e2), isFalse);
      expect(vm.puedeEditarEconomica(vm.economicas.last), isFalse);
      expect(await vm.editarMonto('e-2', 1), isFalse);
      expect(await vm.editarMonto('e-3', 1), isFalse);
      expect(vm.error, contains('ya fue recibida'));
      expect(await vm.eliminar('e-2'), isFalse);
      expect(await vm.eliminar('e-3'), isFalse);
      expect(repo.escrituras, 0);
      await _pausa();
      expect(vm.economicas, hasLength(3));
      vm.dispose();
    });

    test('solo el admin marca recibido', () async {
      final (vm, repo) = await crear();
      expect(vm.puedeMarcarRecibido, isFalse);
      expect(await vm.marcarRecibido('e-1', true), isFalse);
      expect(
        vm.error,
        'Solo el organizador puede marcar aportaciones como recibidas.',
      );
      expect(repo.escrituras, 0);
      vm.dispose();
      final (admin, _) = await crear(admin: true);
      expect(await admin.marcarRecibido('e-1', true), isTrue);
      await _pausa();
      expect(admin.totalRecibido, 15000);
      expect(await admin.editarMonto('e-1', 3000), isTrue);
      expect(await admin.eliminar('e-2'), isTrue);
      admin.dispose();
    });

    test('solo el admin guarda la meta', () async {
      final (vm, repo) = await crear();
      expect(await vm.guardarMeta(1000), isFalse);
      expect(vm.error, 'Solo el organizador puede cambiar la meta.');
      expect(repo.escrituras, 0);
      vm.dispose();
      final (admin, _) = await crear(admin: true);
      expect(await admin.guardarMeta(-1), isFalse);
      expect(admin.error, 'La meta no puede ser negativa.');
      expect(await admin.guardarMeta(50000), isTrue);
      await _pausa();
      expect(admin.meta, 50000);
      expect(await admin.guardarMeta(null), isTrue);
      await _pausa();
      expect(admin.meta, isNull);
      admin.dispose();
    });

    test('asignar y marcarLista no aplican a económicas', () async {
      final (vm, repo) = await crear(admin: true);
      expect(await vm.asignar('e-1', 'u-2'), isFalse);
      expect(await vm.marcarLista('e-1', true), isFalse);
      expect(repo.escrituras, 0);
      vm.dispose();
    });

    test('dispose cancela las dos suscripciones', () async {
      final (vm, repo) = await crear();
      expect(repo.escuchas, 2);
      vm.dispose();
      expect(repo.escuchas, 0);
    });
  });
}
