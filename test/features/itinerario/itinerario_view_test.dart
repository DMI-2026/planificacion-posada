import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planificacion_posada/core/theme/app_theme.dart';
import 'package:planificacion_posada/features/itinerario/models/actividad.dart';
import 'package:planificacion_posada/features/itinerario/repositories/fake_itinerario_repository.dart';
import 'package:planificacion_posada/features/itinerario/viewmodels/itinerario_view_model.dart';
import 'package:planificacion_posada/features/itinerario/views/itinerario_view.dart';

DateTime h(int hora, [int min = 0]) => DateTime(2026, 12, 24, hora, min);

Future<ItinerarioViewModel> montar(
  WidgetTester tester, {
  required bool admin,
  List<Actividad> inicial = const [],
}) async {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = FakeItinerarioRepository(inicial: inicial);
  final vm = ItinerarioViewModel(
    repo,
    esAdmin: admin,
    ahora: () => h(19, 30),
    nombresIniciales: const {'u1': 'Ana'},
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.noche,
      home: ItinerarioView(viewModel: vm),
    ),
  );
  await tester.pumpAndSettle();
  return vm;
}

/// Desmonta la vista y libera el viewmodel (su temporizador debe cancelarse
/// antes de que termine la prueba).
Future<void> cerrar(WidgetTester tester, ItinerarioViewModel vm) async {
  await tester.pumpWidget(const SizedBox());
  vm.dispose();
}

void main() {
  final lista = [
    Actividad(
      id: '1',
      titulo: 'Rosca',
      inicio: h(19),
      duracionMin: 60,
      responsableId: 'u1',
    ),
    Actividad(id: '2', titulo: 'Piñata', inicio: h(20, 30), duracionMin: 30),
  ];

  testWidgets('vacío: mensaje festivo y sin FAB para no admin', (tester) async {
    final vm = await montar(tester, admin: false);
    expect(
      find.text('Aún no hay actividades. ¡La noche promete magia!'),
      findsOneWidget,
    );
    expect(find.text('Agregar actividad'), findsNothing);
    await cerrar(tester, vm);
  });

  testWidgets('muestra horas, estados y responsable', (tester) async {
    final vm = await montar(tester, admin: false, inicial: lista);
    expect(find.text('Rosca'), findsOneWidget);
    expect(find.text('19:00'), findsOneWidget);
    expect(find.text('En curso'), findsOneWidget);
    expect(find.text('Siguiente'), findsOneWidget);
    expect(find.text('Responsable: Ana'), findsOneWidget);
    expect(find.text('Sin responsable'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    await cerrar(tester, vm);
  });

  testWidgets('admin: agrega una actividad desde el formulario', (
    tester,
  ) async {
    final vm = await montar(tester, admin: true);
    await tester.tap(find.text('Agregar actividad'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Título'), 'Cena');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Cena'), findsWidgets);
    expect(vm.actividades.single.titulo, 'Cena');
    expect(vm.actividades.single.duracionMin, 30);
    await cerrar(tester, vm);
  });

  testWidgets('admin: error de validación se muestra en el formulario', (
    tester,
  ) async {
    final vm = await montar(tester, admin: true);
    await tester.tap(find.text('Agregar actividad'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('El título no puede estar vacío.'), findsWidgets);
    expect(vm.actividades, isEmpty);
    await cerrar(tester, vm);
  });

  testWidgets('admin: edita y elimina', (tester) async {
    final vm = await montar(tester, admin: true, inicial: lista);
    await tester.tap(find.byTooltip('Editar Piñata'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Título'),
      'Piñata XL',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Piñata XL'), findsOneWidget);

    await tester.tap(find.byTooltip('Eliminar Rosca'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(find.text('Rosca'), findsNothing);
    expect(vm.actividades.length, 1);
    await cerrar(tester, vm);
  });
}
