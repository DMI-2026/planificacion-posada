import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planificacion_posada/core/theme/app_theme.dart';
import 'package:planificacion_posada/features/arbol/models/adorno.dart';
import 'package:planificacion_posada/features/arbol/repositories/fake_arbol_repository.dart';
import 'package:planificacion_posada/features/arbol/viewmodels/arbol_view_model.dart';
import 'package:planificacion_posada/features/arbol/views/arbol_view.dart';

Adorno _esfera(
  String uid,
  int slot, {
  double x = 0.5,
  double y = 0.55,
  String m = '',
}) => Adorno(
  id: Adorno.idDe(uid, slot),
  tipo: TipoAdorno.esfera,
  autorId: uid,
  color: '#D62839',
  patron: PatronEsfera.rayas,
  mensaje: m,
  x: x,
  y: y,
);

Adorno _regalo(String uid, int slot, {double x = 0.4, double y = 0.7}) =>
    Adorno(
      id: Adorno.idDe(uid, slot),
      tipo: TipoAdorno.regalo,
      autorId: uid,
      color: '#FFC857',
      colorMono: '#2FBF71',
      mensaje: 'Para ti',
      x: x,
      y: y,
    );

Future<ArbolViewModel> _montar(
  WidgetTester tester,
  FakeArbolRepository repo, {
  bool admin = false,
  bool participante = true,
}) async {
  tester.view.physicalSize = const Size(500, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // Los efectos son continuos: movimiento reducido para que pumpAndSettle termine.
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  final vm = ArbolViewModel(
    repo,
    uid: 'u1',
    esAdmin: admin,
    esParticipante: participante,
    nombres: const {'u1': 'Ana', 'u2': 'Beto'},
  );
  addTearDown(vm.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.noche,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: ArbolView(viewModel: vm),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return vm;
}

void main() {
  testWidgets('muestra el contador y el árbol vacío con una invitación', (
    tester,
  ) async {
    await _montar(tester, FakeArbolRepository());
    expect(find.text('Mis adornos 0/10'), findsOneWidget);
    expect(find.text('Crear adorno'), findsOneWidget);
    expect(
      find.textContaining('El árbol espera su primer adorno'),
      findsOneWidget,
    );
  });

  testWidgets('dibuja los adornos del repositorio y cuenta solo los míos', (
    tester,
  ) async {
    await _montar(
      tester,
      FakeArbolRepository(
        inicial: [
          _esfera('u1', 0),
          _regalo('u1', 1),
          _esfera('u2', 0, x: 0.45),
        ],
      ),
    );
    expect(find.byKey(const Key('adorno-u1_0')), findsOneWidget);
    expect(find.byKey(const Key('adorno-u1_1')), findsOneWidget);
    expect(find.byKey(const Key('adorno-u2_0')), findsOneWidget);
    expect(find.text('Mis adornos 2/10'), findsOneWidget);
    expect(find.textContaining('El árbol espera'), findsNothing);
  });

  testWidgets('un adorno que llega en tiempo real aparece sin recargar', (
    tester,
  ) async {
    final repo = FakeArbolRepository();
    await _montar(tester, repo);
    repo.simularRemoto(_regalo('u2', 3));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('adorno-u2_3')), findsOneWidget);
    // Se mueve: el adorno ajeno se anima a su nueva posición.
    final antes = tester.getCenter(find.byKey(const Key('adorno-u2_3')));
    repo.simularRemoto(_regalo('u2', 3, x: 0.6, y: 0.8));
    await tester.pumpAndSettle();
    final despues = tester.getCenter(find.byKey(const Key('adorno-u2_3')));
    expect(despues.dx, greaterThan(antes.dx));
    expect(despues.dy, greaterThan(antes.dy));
  });

  testWidgets(
    'tocar un adorno muestra autor y mensaje; tocar el fondo lo cierra',
    (tester) async {
      await _montar(
        tester,
        FakeArbolRepository(inicial: [_esfera('u2', 0, m: 'Feliz Navidad')]),
      );
      await tester.tap(find.byKey(const Key('adorno-u2_0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tarjeta-adorno')), findsOneWidget);
      expect(find.text('Beto'), findsOneWidget);
      expect(find.text('Feliz Navidad'), findsOneWidget);
      // Ajeno: sin acciones.
      expect(find.byKey(const Key('quitar-adorno')), findsNothing);
      expect(find.byKey(const Key('editar-adorno')), findsNothing);

      await tester.tapAt(
        tester.getTopLeft(find.byKey(const Key('fondo-arbol'))) +
            const Offset(5, 5),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tarjeta-adorno')), findsNothing);
    },
  );

  testWidgets('un adorno sin mensaje dice «Sin mensaje»', (tester) async {
    await _montar(tester, FakeArbolRepository(inicial: [_esfera('u2', 0)]));
    await tester.tap(find.byKey(const Key('adorno-u2_0')));
    await tester.pumpAndSettle();
    expect(find.text('Sin mensaje'), findsOneWidget);
  });

  testWidgets('arrastrar un adorno propio cambia su posición y la guarda', (
    tester,
  ) async {
    final repo = FakeArbolRepository(inicial: [_esfera('u1', 0)]);
    final vm = await _montar(tester, repo);
    final f = find.byKey(const Key('adorno-u1_0'));
    final antes = tester.getCenter(f);
    await tester.drag(f, const Offset(30, 60));
    await tester.pumpAndSettle();
    final despues = tester.getCenter(f);
    expect(despues.dx, greaterThan(antes.dx + 5));
    expect(despues.dy, greaterThan(antes.dy + 20));
    final a = vm.adornos.single;
    expect(a.x, greaterThan(0.5));
    expect(a.y, greaterThan(0.55));
    expect(repo.movimientos, isNotEmpty);
    expect(repo.movimientos.last.$1, 'u1_0');
    expect(repo.movimientos.last.$2, closeTo(a.x, 1e-9));
    expect(repo.movimientos.last.$3, closeTo(a.y, 1e-9));
  });

  testWidgets('arrastrar fuera del árbol deja el adorno dentro de la silueta', (
    tester,
  ) async {
    final repo = FakeArbolRepository(
      inicial: [_esfera('u1', 0, x: 0.5, y: 0.3)],
    );
    final vm = await _montar(tester, repo);
    await tester.drag(
      find.byKey(const Key('adorno-u1_0')),
      const Offset(400, -300),
    );
    await tester.pumpAndSettle();
    final a = vm.adornos.single;
    expect(a.x, lessThanOrEqualTo(0.5 + 0.2));
    expect(a.y, greaterThan(0.05));
  });

  testWidgets('un adorno ajeno no se arrastra', (tester) async {
    final repo = FakeArbolRepository(inicial: [_esfera('u2', 0)]);
    final vm = await _montar(tester, repo);
    await tester.drag(
      find.byKey(const Key('adorno-u2_0')),
      const Offset(30, 60),
    );
    await tester.pumpAndSettle();
    expect((vm.adornos.single.x, vm.adornos.single.y), (0.5, 0.55));
    expect(repo.movimientos, isEmpty);
  });

  testWidgets('el autor quita el suyo desde la tarjeta', (tester) async {
    final repo = FakeArbolRepository(inicial: [_esfera('u1', 0, m: 'Mío')]);
    await _montar(tester, repo);
    await tester.tap(find.byKey(const Key('adorno-u1_0')));
    await tester.pumpAndSettle();
    expect(find.text('Ana'), findsOneWidget);
    await tester.tap(find.byKey(const Key('quitar-adorno')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('adorno-u1_0')), findsNothing);
    expect(find.text('Mis adornos 0/10'), findsOneWidget);
  });

  testWidgets('el admin puede quitar adornos ajenos pero no editarlos', (
    tester,
  ) async {
    final repo = FakeArbolRepository(inicial: [_esfera('u2', 0)]);
    await _montar(tester, repo, admin: true);
    await tester.tap(find.byKey(const Key('adorno-u2_0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('editar-adorno')), findsNothing);
    await tester.tap(find.byKey(const Key('quitar-adorno')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('adorno-u2_0')), findsNothing);
  });

  group('taller', () {
    testWidgets('colgar una esfera: vista previa, colores y mensaje', (
      tester,
    ) async {
      final repo = FakeArbolRepository();
      final vm = await _montar(tester, repo);
      await tester.tap(find.text('Crear adorno'));
      await tester.pumpAndSettle();
      expect(find.text('Taller de adornos'), findsOneWidget);
      expect(find.byKey(const Key('vista-previa')), findsOneWidget);
      expect(find.text('Te quedan 10 lugares en el árbol.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('color-#2EE6C8')));
      await tester.tap(find.byKey(const Key('patron-estrellas')));
      await tester.enterText(
        find.byKey(const Key('mensaje-adorno')),
        'Hola clase',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Colgar en el árbol'));
      await tester.pumpAndSettle();

      expect(find.text('Taller de adornos'), findsNothing);
      final a = vm.adornos.single;
      expect(a.tipo, TipoAdorno.esfera);
      expect(a.color, '#2EE6C8');
      expect(a.patron, PatronEsfera.estrellas);
      expect(a.mensaje, 'Hola clase');
      expect(find.byKey(Key('adorno-${a.id}')), findsOneWidget);
      expect(find.text('Mis adornos 1/10'), findsOneWidget);
    });

    testWidgets('colgar un regalo con listón', (tester) async {
      final repo = FakeArbolRepository();
      final vm = await _montar(tester, repo);
      await tester.tap(find.text('Crear adorno'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Regalo'));
      await tester.pumpAndSettle();
      expect(find.text('Color del listón'), findsOneWidget);
      await tester.tap(find.byKey(const Key('cinta-#FF4FD8')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Colgar en el árbol'));
      await tester.pumpAndSettle();
      final a = vm.adornos.single;
      expect(a.tipo, TipoAdorno.regalo);
      expect(a.colorMono, '#FF4FD8');
    });

    testWidgets('con 10 adornos el taller avisa y no deja colgar', (
      tester,
    ) async {
      final repo = FakeArbolRepository(
        inicial: [
          for (var s = 0; s < 10; s++) _esfera('u1', s, x: 0.3 + s * 0.04),
        ],
      );
      final vm = await _montar(tester, repo);
      expect(find.text('Mis adornos 10/10'), findsOneWidget);
      await tester.tap(find.text('Crear adorno'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Ya colgaste tus 10 adornos'), findsOneWidget);
      await tester.tap(find.text('Colgar en el árbol'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(vm.adornos.length, 10);
    });

    testWidgets('quien no es participante ve el aviso y no cuelga', (
      tester,
    ) async {
      final repo = FakeArbolRepository();
      final vm = await _montar(tester, repo, participante: false);
      await tester.tap(find.text('Crear adorno'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Para colgar adornos necesitas estar en la lista de la posada.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Colgar en el árbol'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(vm.adornos, isEmpty);
    });

    testWidgets('editar un adorno propio guarda los cambios', (tester) async {
      final repo = FakeArbolRepository(inicial: [_esfera('u1', 0, m: 'Viejo')]);
      final vm = await _montar(tester, repo);
      await tester.tap(find.byKey(const Key('adorno-u1_0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('editar-adorno')));
      await tester.pumpAndSettle();
      expect(find.text('Editar adorno'), findsOneWidget);
      expect(find.text('Viejo'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('mensaje-adorno')), 'Nuevo');
      await tester.tap(find.byKey(const Key('color-#FF4FD8')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(vm.adornos.single.mensaje, 'Nuevo');
      expect(vm.adornos.single.color, '#FF4FD8');
      expect(vm.adornos.single.x, 0.5);
      expect(vm.cantidadMios, 1);
    });

    testWidgets('el campo de mensaje limita a 60 caracteres', (tester) async {
      await _montar(tester, FakeArbolRepository());
      await tester.tap(find.text('Crear adorno'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('mensaje-adorno')), 'a' * 80);
      await tester.pump();
      final campo = tester.widget<TextField>(
        find.byKey(const Key('mensaje-adorno')),
      );
      expect(campo.controller!.text.length, 60);
    });
  });

  testWidgets('con animaciones: cuelga con confeti y caída sin errores', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeArbolRepository(inicial: [_esfera('u2', 0)]);
    final vm = ArbolViewModel(
      repo,
      uid: 'u1',
      esAdmin: false,
      esParticipante: true,
    );
    addTearDown(vm.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.noche,
        home: Scaffold(
          backgroundColor: Colors.transparent,
          body: ArbolView(viewModel: vm),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Crear adorno'));
    await tester.pump(); // empieza la animación de la hoja
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.tap(find.text('Colgar en el árbol'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(find.byKey(const Key('adorno-u1_0')), findsOneWidget);
    // Cierra: desmonta la vista y deja correr el confeti restante.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 4));
  });
}
