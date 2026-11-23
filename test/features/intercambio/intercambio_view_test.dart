import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planificacion_posada/core/theme/app_theme.dart';
import 'package:planificacion_posada/features/intercambio/models/asignacion.dart';
import 'package:planificacion_posada/features/intercambio/models/config_intercambio.dart';
import 'package:planificacion_posada/features/intercambio/models/inscrito.dart';
import 'package:planificacion_posada/features/intercambio/repositories/fake_intercambio_repository.dart';
import 'package:planificacion_posada/features/intercambio/viewmodels/intercambio_view_model.dart';
import 'package:planificacion_posada/features/intercambio/views/intercambio_view.dart';

const _nombres = {'u1': 'Ana', 'u2': 'Beto', 'u3': 'Caro', 'admin': 'Admin'};

Future<IntercambioViewModel> _monta(
  WidgetTester tester,
  FakeIntercambioRepository repo, {
  String uid = 'u1',
  bool admin = false,
}) async {
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  final vm = IntercambioViewModel(
    repo,
    uid: uid,
    esAdmin: admin,
    esParticipante: true,
    nombres: _nombres,
    random: Random(1),
  );
  addTearDown(vm.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.noche,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: IntercambioView(viewModel: vm),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return vm;
}

FakeIntercambioRepository _sorteado({bool revelado = false}) =>
    FakeIntercambioRepository(
      config: ConfigIntercambio(
        sorteado: true,
        revelado: revelado,
        presupuestoCentavos: 25000,
      ),
      inscritos: const [
        Inscrito(uid: 'u1'),
        Inscrito(uid: 'u2', deseos: ['Taza de barro', 'Calcetas']),
        Inscrito(uid: 'u3'),
      ],
      asignaciones: const [
        Asignacion(uid: 'u1', destinatarioId: 'u2'),
        Asignacion(uid: 'u2', destinatarioId: 'u3'),
        Asignacion(uid: 'u3', destinatarioId: 'u1'),
      ],
    );

void main() {
  testWidgets('muestra presupuesto y permite inscribirse con deseos', (
    tester,
  ) async {
    final repo = FakeIntercambioRepository(
      config: const ConfigIntercambio(
        inscripcionAbierta: true,
        presupuestoCentavos: 25000,
      ),
    );
    await _monta(tester, repo);
    expect(find.text('\$250.00'), findsOneWidget);
    expect(find.text('Inscribirme'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('campo-deseo')), 'Una bufanda');
    await tester.tap(find.byKey(const Key('agregar-deseo')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InputChip, 'Una bufanda'), findsOneWidget);
    await tester.tap(find.text('Inscribirme'));
    await tester.pumpAndSettle();
    expect(repo.inscritosActuales.single.deseos, ['Una bufanda']);
    expect(find.text('Salir del intercambio'), findsOneWidget);
  });

  testWidgets('con inscripción cerrada no se puede inscribir', (tester) async {
    await _monta(tester, FakeIntercambioRepository());
    expect(find.text('Inscribirme'), findsNothing);
    expect(find.textContaining('cerrada'), findsWidgets);
  });

  testWidgets('tocar el regalo revela al destinatario y sus deseos', (
    tester,
  ) async {
    await _monta(tester, _sorteado());
    expect(find.text('Beto'), findsNothing);
    await tester.tap(find.byKey(const Key('regalo-sorpresa')));
    await tester.pumpAndSettle();
    expect(find.text('Beto'), findsOneWidget);
    expect(find.text('Taza de barro'), findsOneWidget);
    expect(find.text('Calcetas'), findsOneWidget);
  });

  testWidgets('con el sorteo revelado se ven todas las parejas', (
    tester,
  ) async {
    await _monta(tester, _sorteado(revelado: true));
    expect(find.byKey(const Key('pareja-u1')), findsOneWidget);
    expect(find.byKey(const Key('pareja-u2')), findsOneWidget);
    expect(find.byKey(const Key('pareja-u3')), findsOneWidget);
  });

  testWidgets('sin revelar, un participante no ve las parejas', (tester) async {
    await _monta(tester, _sorteado());
    expect(find.byKey(const Key('pareja-u1')), findsNothing);
  });

  testWidgets('el admin sortea y revela desde su panel', (tester) async {
    final repo = FakeIntercambioRepository(
      config: const ConfigIntercambio(inscripcionAbierta: true),
      inscritos: const [
        Inscrito(uid: 'u1'),
        Inscrito(uid: 'u2'),
      ],
    );
    await _monta(tester, repo, uid: 'admin', admin: true);
    expect(find.text('Panel del organizador'), findsOneWidget);
    await tester.tap(find.text('Cerrar inscripción'));
    await tester.pumpAndSettle();
    expect(repo.configActual.inscripcionAbierta, isFalse);
    await tester.tap(find.byKey(const Key('admin-sortear')));
    await tester.pumpAndSettle();
    expect(repo.configActual.sorteado, isTrue);
    expect(repo.asignacionesActuales, hasLength(2));
    await tester.tap(find.byKey(const Key('admin-revelar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revelar'));
    await tester.pumpAndSettle();
    expect(repo.configActual.revelado, isTrue);
  });

  testWidgets('el admin guarda el presupuesto', (tester) async {
    final repo = FakeIntercambioRepository();
    await _monta(tester, repo, uid: 'admin', admin: true);
    await tester.enterText(find.byKey(const Key('campo-presupuesto')), '300');
    await tester.tap(find.byKey(const Key('guardar-presupuesto')));
    await tester.pumpAndSettle();
    expect(repo.configActual.presupuestoCentavos, 30000);
  });

  testWidgets('un participante no ve el panel del organizador', (tester) async {
    await _monta(tester, FakeIntercambioRepository());
    expect(find.text('Panel del organizador'), findsNothing);
  });

  testWidgets('con movimiento normal el regalo se abre animado', (
    tester,
  ) async {
    final repo = _sorteado();
    final vm = IntercambioViewModel(
      repo,
      uid: 'u1',
      esAdmin: false,
      esParticipante: true,
      nombres: _nombres,
    );
    addTearDown(vm.dispose);
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.noche,
        home: Scaffold(body: IntercambioView(viewModel: vm)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.tap(find.byKey(const Key('regalo-sorpresa')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Beto'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Taza de barro'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
