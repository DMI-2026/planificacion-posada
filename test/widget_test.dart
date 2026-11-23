import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planificacion_posada/features/aportaciones/models/aportacion.dart';
import 'package:planificacion_posada/features/aportaciones/repositories/fake_aportacion_repository.dart';
import 'package:planificacion_posada/features/auth/models/usuario.dart';
import 'package:planificacion_posada/features/auth/repositories/fake_auth_repository.dart';
import 'package:planificacion_posada/features/evento/repositories/fake_evento_repository.dart';
import 'package:planificacion_posada/features/participantes/repositories/fake_participante_repository.dart';
import 'package:planificacion_posada/main.dart';

Future<void> abrir(
  WidgetTester tester, {
  FakeAportacionRepository? aportaciones,
  FakeAuthRepository? auth,
}) async {
  if (tester.view.physicalSize.width == 800) {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(
    PosadaApp(
      authRepository:
          auth ??
          FakeAuthRepository(
            sesionInicial: const Usuario(
              id: 'u-1',
              correo: 'ana@posada.mx',
              nombre: 'Ana',
            ),
          ),
      eventoRepository: FakeEventoRepository(),
      participanteRepository: FakeParticipanteRepository(),
      aportacionRepository: aportaciones ?? FakeAportacionRepository(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('el shell muestra los 3 destinos y Inicio vacío', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await abrir(tester);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Participantes'), findsOneWidget);
    expect(find.text('Aportaciones'), findsOneWidget);
    expect(find.textContaining('Todavía no hay evento'), findsOneWidget);
    expect(find.text('Asistentes confirmados: 0'), findsOneWidget);
  });

  testWidgets('agregar participante lo lista y actualiza contadores', (
    tester,
  ) async {
    await abrir(tester);
    await tester.tap(find.text('Participantes'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Aún no hay participantes'), findsOneWidget);

    await tester.tap(find.text('Agregar participante'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ana');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Tal vez: 1'), findsOneWidget);
    expect(find.text('Sí: 0'), findsOneWidget);

    await tester.tap(find.text('Sí'));
    await tester.pumpAndSettle();
    expect(find.text('Sí: 1'), findsOneWidget);
    expect(find.text('Tal vez: 0'), findsOneWidget);
  });

  testWidgets('nombre vacío muestra el mensaje del viewmodel', (tester) async {
    await abrir(tester);
    await tester.tap(find.text('Participantes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar participante'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(
      find.text('El nombre del participante no puede estar vacío.'),
      findsWidgets,
    );
    expect(find.text('Nuevo participante'), findsOneWidget);
  });

  testWidgets('marcar una aportación como lista actualiza contadores', (
    tester,
  ) async {
    await abrir(
      tester,
      aportaciones: FakeAportacionRepository(
        inicial: const [Aportacion(id: 'a-1', articulo: 'Ponche', cantidad: 2)],
      ),
    );
    await tester.tap(find.text('Aportaciones'));
    await tester.pumpAndSettle();
    expect(find.text('Pendientes: 1'), findsOneWidget);
    expect(find.text('Listas: 0'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(find.text('Pendientes: 0'), findsOneWidget);
    expect(find.text('Listas: 1'), findsOneWidget);
  });

  testWidgets('en ancho se usa NavigationRail', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await abrir(tester);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('sin sesión se muestra el login y con credenciales entra', (
    tester,
  ) async {
    await abrir(tester, auth: FakeAuthRepository());
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Participantes'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextField, 'Correo'),
      FakeAuthRepository.correoDemo,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Contraseña'),
      FakeAuthRepository.contrasenaDemo,
    );
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Participantes'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsNothing);
  });

  testWidgets('cerrar sesión vuelve al login', (tester) async {
    await abrir(tester);
    await tester.tap(find.byTooltip('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Participantes'), findsNothing);
  });
}
