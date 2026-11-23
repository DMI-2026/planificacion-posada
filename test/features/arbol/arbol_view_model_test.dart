import 'package:flutter_test/flutter_test.dart';
import 'package:planificacion_posada/features/arbol/geometria/arbol_geometria.dart';
import 'package:planificacion_posada/features/arbol/models/adorno.dart';
import 'package:planificacion_posada/features/arbol/repositories/fake_arbol_repository.dart';
import 'package:planificacion_posada/features/arbol/viewmodels/arbol_view_model.dart';

Future<void> _pausa() => Future<void>.delayed(Duration.zero);

Adorno _esfera(String uid, int slot, {double x = 0.5, double y = 0.5}) =>
    Adorno(
      id: Adorno.idDe(uid, slot),
      tipo: TipoAdorno.esfera,
      autorId: uid,
      color: '#D62839',
      patron: PatronEsfera.liso,
      x: x,
      y: y,
    );

ArbolViewModel _vm(
  FakeArbolRepository repo, {
  String uid = 'u1',
  bool admin = false,
  bool participante = true,
  Duration intervalo = const Duration(milliseconds: 250),
}) => ArbolViewModel(
  repo,
  uid: uid,
  esAdmin: admin,
  esParticipante: participante,
  nombres: const {'u1': 'Ana', 'u2': 'Beto'},
  intervaloMovimiento: intervalo,
);

void main() {
  group('lectura', () {
    test('empieza cargando y luego queda vacío', () async {
      final vm = _vm(FakeArbolRepository());
      expect(vm.cargando, isTrue);
      await _pausa();
      expect(vm.cargando, isFalse);
      expect(vm.vacio, isTrue);
      expect(vm.slotsLibres, 10);
      vm.dispose();
    });

    test('cuenta mis adornos y los slots libres', () async {
      final repo = FakeArbolRepository(
        inicial: [_esfera('u1', 0), _esfera('u1', 3), _esfera('u2', 0)],
      );
      final vm = _vm(repo);
      await _pausa();
      expect(vm.adornos.length, 3);
      expect(vm.cantidadMios, 2);
      expect(vm.misAdornos.every((a) => a.autorId == 'u1'), isTrue);
      expect(vm.slotsLibres, 8);
      expect(vm.puedeCrear, isTrue);
      vm.dispose();
    });

    test('un cambio remoto llega en tiempo real', () async {
      final repo = FakeArbolRepository();
      final vm = _vm(repo);
      await _pausa();
      var avisos = 0;
      vm.addListener(() => avisos++);
      repo.simularRemoto(_esfera('u2', 1, x: 0.4));
      await _pausa();
      expect(vm.adornos.single.id, 'u2_1');
      expect(avisos, 1);
      repo.simularRemoto(_esfera('u2', 1, x: 0.6));
      await _pausa();
      expect(vm.adornos.single.x, 0.6);
      vm.dispose();
    });

    test('un error del stream deja un mensaje en español', () async {
      final repo = FakeArbolRepository();
      final vm = _vm(repo);
      await _pausa();
      repo.emitirError(Exception('x'));
      await _pausa();
      expect(vm.error, 'No pudimos cargar el árbol. Intenta de nuevo.');
      vm.dispose();
    });

    test('nombreAutor usa el mapa y un texto genérico si falta', () async {
      final vm = _vm(FakeArbolRepository());
      expect(vm.nombreAutor('u2'), 'Beto');
      expect(vm.nombreAutor('zz'), 'Alguien de la clase');
      vm.actualizarNombres({'zz': 'Zoe'});
      expect(vm.nombreAutor('zz'), 'Zoe');
      vm.dispose();
    });

    test('dispose cancela la suscripción', () async {
      final repo = FakeArbolRepository();
      final vm = _vm(repo);
      await _pausa();
      expect(repo.escuchas, 1);
      vm.dispose();
      expect(repo.escuchas, 0);
    });
  });

  group('crear', () {
    test(
      'crearEsfera usa el primer slot libre y queda dentro del árbol',
      () async {
        final repo = FakeArbolRepository(
          inicial: [_esfera('u1', 0), _esfera('u1', 2)],
        );
        final vm = _vm(repo);
        await _pausa();
        final ok = await vm.crearEsfera(
          color: '#2EE6C8',
          patron: PatronEsfera.puntos,
          mensaje: '  Hola  ',
        );
        await _pausa();
        expect(ok, isTrue);
        final nuevo = vm.adornos.firstWhere((a) => a.id == 'u1_1');
        expect(nuevo.tipo, TipoAdorno.esfera);
        expect(nuevo.mensaje, 'Hola');
        expect(nuevo.patron, PatronEsfera.puntos);
        expect(dentroDelArbol(nuevo.x, nuevo.y), isTrue);
        expect(nuevo.y, lessThan(0.5));
        expect(vm.cantidadMios, 3);
        vm.dispose();
      },
    );

    test('crearRegalo guarda color y listón', () async {
      final vm = _vm(FakeArbolRepository());
      await _pausa();
      expect(
        await vm.crearRegalo(color: '#FFC857', colorMono: '#D62839'),
        isTrue,
      );
      await _pausa();
      final r = vm.adornos.single;
      expect(r.tipo, TipoAdorno.regalo);
      expect(r.colorMono, '#D62839');
      expect(r.id, 'u1_0');
      vm.dispose();
    });

    test('los nuevos adornos no se encimen en el mismo punto', () async {
      final vm = _vm(FakeArbolRepository());
      await _pausa();
      for (var i = 0; i < 3; i++) {
        await vm.crearEsfera(color: '#D62839', patron: PatronEsfera.liso);
        await _pausa();
      }
      final pts = {for (final a in vm.adornos) (a.x, a.y)};
      expect(pts.length, 3);
      vm.dispose();
    });

    test('el límite es de 10 y el undécimo se rechaza', () async {
      final repo = FakeArbolRepository(
        inicial: [for (var s = 0; s < 10; s++) _esfera('u1', s)],
      );
      final vm = _vm(repo);
      await _pausa();
      expect(vm.slotsLibres, 0);
      expect(vm.puedeCrear, isFalse);
      final ok = await vm.crearEsfera(
        color: '#D62839',
        patron: PatronEsfera.liso,
      );
      expect(ok, isFalse);
      expect(
        vm.error,
        'Ya colgaste tus 10 adornos. Quita uno para colgar otro.',
      );
      expect(vm.adornos.length, 10);
      vm.dispose();
    });

    test('al quitar uno se libera su slot', () async {
      final repo = FakeArbolRepository(
        inicial: [for (var s = 0; s < 10; s++) _esfera('u1', s)],
      );
      final vm = _vm(repo);
      await _pausa();
      expect(await vm.eliminar('u1_4'), isTrue);
      await _pausa();
      expect(vm.slotsLibres, 1);
      await vm.crearEsfera(color: '#D62839', patron: PatronEsfera.liso);
      await _pausa();
      expect(vm.adornos.where((a) => a.id == 'u1_4').length, 1);
      vm.dispose();
    });

    test('quien no es participante no cuelga nada', () async {
      final repo = FakeArbolRepository();
      final vm = _vm(repo, participante: false);
      await _pausa();
      expect(vm.slotsLibres, 0);
      final ok = await vm.crearRegalo(color: '#FFC857', colorMono: '#D62839');
      expect(ok, isFalse);
      expect(
        vm.error,
        'Solo quienes están en la lista de la posada pueden colgar adornos.',
      );
      await _pausa();
      expect(vm.adornos, isEmpty);
      vm.dispose();
    });

    test('valida color de la paleta y mensaje de 60', () async {
      final repo = FakeArbolRepository();
      final vm = _vm(repo);
      await _pausa();
      expect(
        await vm.crearEsfera(color: '#123456', patron: PatronEsfera.liso),
        isFalse,
      );
      expect(vm.error, 'Elige un color de la paleta.');
      expect(
        await vm.crearRegalo(color: '#FFC857', colorMono: '#000000'),
        isFalse,
      );
      expect(
        await vm.crearEsfera(
          color: '#D62839',
          patron: PatronEsfera.liso,
          mensaje: 'a' * 61,
        ),
        isFalse,
      );
      expect(vm.error, 'El mensaje no puede pasar de 60 caracteres.');
      expect(
        await vm.crearEsfera(
          color: '#D62839',
          patron: PatronEsfera.liso,
          mensaje: 'a' * 60,
        ),
        isTrue,
      );
      await _pausa();
      expect(vm.adornos.length, 1);
      vm.dispose();
    });

    test('si el repositorio falla, deja un error y no cuelga nada', () async {
      final repo = FakeArbolRepository();
      final vm = _vm(repo);
      await _pausa();
      repo.fallarEscritura = Exception('sin red');
      final ok = await vm.crearEsfera(
        color: '#D62839',
        patron: PatronEsfera.liso,
      );
      expect(ok, isFalse);
      expect(vm.error, 'No pudimos colgar el adorno. Intenta de nuevo.');
      expect(vm.adornos, isEmpty);
      vm.limpiarError();
      expect(vm.error, isNull);
      vm.dispose();
    });
  });

  group('editar y eliminar', () {
    test('editar cambia color, patrón y mensaje del propio', () async {
      final repo = FakeArbolRepository(inicial: [_esfera('u1', 0)]);
      final vm = _vm(repo);
      await _pausa();
      final ok = await vm.editar(
        'u1_0',
        color: '#FF4FD8',
        patron: PatronEsfera.rayas,
        mensaje: ' Nuevo ',
      );
      await _pausa();
      expect(ok, isTrue);
      final a = vm.adornos.single;
      expect(a.color, '#FF4FD8');
      expect(a.patron, PatronEsfera.rayas);
      expect(a.mensaje, 'Nuevo');
      expect((a.x, a.y), (0.5, 0.5));
      vm.dispose();
    });

    test('editar un adorno ajeno se rechaza (también el admin)', () async {
      final repo = FakeArbolRepository(inicial: [_esfera('u2', 0)]);
      final vm = _vm(repo, admin: true);
      await _pausa();
      expect(await vm.editar('u2_0', color: '#FF4FD8'), isFalse);
      expect(vm.error, 'Solo puedes editar tus propios adornos.');
      expect(vm.adornos.single.color, '#D62839');
      vm.dispose();
    });

    test('editar valida el mensaje y el color', () async {
      final repo = FakeArbolRepository(inicial: [_esfera('u1', 0)]);
      final vm = _vm(repo);
      await _pausa();
      expect(await vm.editar('u1_0', mensaje: 'a' * 61), isFalse);
      expect(await vm.editar('u1_0', color: '#000000'), isFalse);
      expect(vm.error, 'Elige un color de la paleta.');
      expect(await vm.editar('nada_0', mensaje: 'x'), isFalse);
      expect(vm.error, 'Ese adorno ya no está en el árbol.');
      vm.dispose();
    });

    test('eliminar: el autor el suyo, el admin cualquiera, otros no', () async {
      final repo = FakeArbolRepository(
        inicial: [_esfera('u1', 0), _esfera('u2', 0), _esfera('u3', 0)],
      );
      final vm = _vm(repo);
      await _pausa();
      expect(await vm.eliminar('u2_0'), isFalse);
      expect(vm.error, 'Solo puedes quitar tus propios adornos.');
      expect(vm.adornos.length, 3);
      expect(await vm.eliminar('u1_0'), isTrue);
      await _pausa();
      expect(vm.adornos.map((a) => a.id), ['u2_0', 'u3_0']);
      vm.dispose();

      final admin = _vm(repo, uid: 'admin', admin: true);
      await _pausa();
      expect(await admin.eliminar('u2_0'), isTrue);
      expect(await admin.eliminar('u3_0'), isTrue);
      await _pausa();
      expect(admin.adornos, isEmpty);
      admin.dispose();
    });

    test('permisos expuestos', () async {
      final repo = FakeArbolRepository(
        inicial: [_esfera('u1', 0), _esfera('u2', 0)],
      );
      final vm = _vm(repo);
      await _pausa();
      final propio = vm.adornos[0], ajeno = vm.adornos[1];
      expect(vm.puedeMover(propio), isTrue);
      expect(vm.puedeMover(ajeno), isFalse);
      expect(vm.puedeEliminar(ajeno), isFalse);
      vm.dispose();
    });
  });

  group('mover (limitado a una escritura por intervalo)', () {
    testWidgets('actualiza lo local al instante y escribe con límite', (
      tester,
    ) async {
      final repo = FakeArbolRepository(inicial: [_esfera('u1', 0)]);
      final vm = _vm(repo);
      await tester.pump();

      vm.mover('u1_0', 0.50, 0.50); // abre la ventana y escribe
      expect(vm.adornos.single.y, 0.50);
      expect(repo.movimientos.length, 1);

      for (var i = 1; i <= 5; i++) {
        vm.mover('u1_0', 0.5, 0.5 + i * 0.02);
        await tester.pump(const Duration(milliseconds: 20));
      }
      // Lo local sigue el dedo; la nube aún no recibió más escrituras.
      expect(vm.adornos.single.y, closeTo(0.60, 1e-9));
      expect(repo.movimientos.length, 1);

      await tester.pump(const Duration(milliseconds: 200)); // cierra ventana
      expect(repo.movimientos.length, 2);
      expect(repo.movimientos.last.$3, closeTo(0.60, 1e-9));

      // Sin más movimiento no hay más escrituras.
      await tester.pump(const Duration(milliseconds: 600));
      expect(repo.movimientos.length, 2);
      vm.dispose();
    });

    testWidgets('al terminar escribe la posición final y suelta lo local', (
      tester,
    ) async {
      final repo = FakeArbolRepository(inicial: [_esfera('u1', 0)]);
      final vm = _vm(repo);
      await tester.pump();
      vm.mover('u1_0', 0.5, 0.5);
      vm.mover('u1_0', 0.5, 0.62);
      await vm.terminarMovimiento('u1_0');
      expect(repo.movimientos.length, 2);
      expect(repo.movimientos.last.$3, closeTo(0.62, 1e-9));
      await tester.pump();
      expect(vm.adornos.single.y, closeTo(0.62, 1e-9));
      // La escritura pendiente no se repite pasado el intervalo.
      await tester.pump(const Duration(seconds: 1));
      expect(repo.movimientos.length, 2);
      vm.dispose();
    });

    testWidgets('ajusta a la silueta y no mueve adornos ajenos', (
      tester,
    ) async {
      final repo = FakeArbolRepository(
        inicial: [_esfera('u1', 0), _esfera('u2', 0, x: 0.45, y: 0.45)],
      );
      final vm = _vm(repo);
      await tester.pump();
      vm.mover('u1_0', 5, 5);
      final a = vm.adornos.firstWhere((a) => a.id == 'u1_0');
      expect(dentroDelArbol(a.x, a.y), isTrue);
      expect(repo.movimientos.single.$2, a.x);

      vm.mover('u2_0', 0.1, 0.9);
      final b = vm.adornos.firstWhere((a) => a.id == 'u2_0');
      expect((b.x, b.y), (0.45, 0.45));
      expect(repo.movimientos.length, 1);
      await vm.terminarMovimiento('u2_0'); // sin movimiento local: no escribe
      expect(repo.movimientos.length, 1);
      vm.dispose();
    });

    testWidgets('un fallo al escribir revierte lo local y avisa', (
      tester,
    ) async {
      final repo = FakeArbolRepository(inicial: [_esfera('u1', 0)]);
      final vm = _vm(repo);
      await tester.pump();
      repo.fallarEscritura = Exception('sin red');
      vm.mover('u1_0', 0.5, 0.7);
      await tester.pump();
      expect(vm.error, 'No pudimos mover el adorno. Intenta de nuevo.');
      expect(vm.adornos.single.y, 0.5);
      vm.dispose();
    });

    testWidgets('dispose cancela las escrituras pendientes', (tester) async {
      final repo = FakeArbolRepository(inicial: [_esfera('u1', 0)]);
      final vm = _vm(repo);
      await tester.pump();
      vm.mover('u1_0', 0.5, 0.5);
      vm.mover('u1_0', 0.5, 0.6);
      vm.dispose();
      await tester.pump(const Duration(seconds: 1));
      expect(repo.movimientos.length, 1);
    });
  });
}
