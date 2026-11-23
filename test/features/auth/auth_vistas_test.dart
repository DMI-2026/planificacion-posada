import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planificacion_posada/core/theme/app_theme.dart';
import 'package:planificacion_posada/features/auth/repositories/fake_auth_repository.dart';
import 'package:planificacion_posada/features/auth/viewmodels/auth_view_model.dart';
import 'package:planificacion_posada/features/auth/views/puerta_sesion_view.dart';

void main() {
  testWidgets('la puerta alterna login y registro con título y campos', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final vm = AuthViewModel(FakeAuthRepository());
    addTearDown(vm.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.noche,
        home: PuertaSesionView(
          viewModel: vm,
          sesionBuilder: (_, _) => const Text('dentro'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Posada de la clase'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Correo'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Contraseña'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Nombre'), findsNothing);
    expect(find.text('Iniciar sesión'), findsOneWidget);

    await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Nombre'), findsOneWidget);
    expect(find.text('Registrarme'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsNothing);

    await tester.tap(find.text('¿Ya tienes cuenta? Inicia sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Registrarme'), findsNothing);
  });

  testWidgets('credenciales incorrectas muestran el error en la tarjeta', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final vm = AuthViewModel(FakeAuthRepository());
    addTearDown(vm.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.noche,
        home: PuertaSesionView(
          viewModel: vm,
          sesionBuilder: (_, _) => const Text('dentro'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(vm.error, isNotEmpty);
    expect(find.text(vm.error), findsOneWidget);
    expect(find.text('dentro'), findsNothing);
  });
}
