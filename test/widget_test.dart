import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planificacion_posada/features/aportaciones/models/aportacion.dart';
import 'package:planificacion_posada/features/aportaciones/repositories/fake_aportacion_repository.dart';
import 'package:planificacion_posada/features/auth/models/usuario.dart';
import 'package:planificacion_posada/features/auth/repositories/fake_admin_repository.dart';
import 'package:planificacion_posada/features/auth/repositories/fake_auth_repository.dart';
import 'package:planificacion_posada/features/evento/repositories/fake_evento_repository.dart';
import 'package:planificacion_posada/features/participantes/models/participante.dart';
import 'package:planificacion_posada/features/participantes/repositories/fake_participante_repository.dart';
import 'package:planificacion_posada/main.dart';

Future<void> abrir(
  WidgetTester tester, {
  FakeAportacionRepository? aportaciones,
  FakeAuthRepository? auth,
  FakeParticipanteRepository? participantes,
  bool admin = false,
}) async {
  if (tester.view.physicalSize.width == 800) {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  // El fondo animado es continuo: se pide movimiento reducido para que
  // pumpAndSettle termine.
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
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
      adminRepository: FakeAdminRepository(admins: admin ? {'u-1'} : {}),
      eventoRepository: FakeEventoRepository(),
      participanteRepository: participantes ?? FakeParticipanteRepository(),
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
    expect(
      find.text('El organizador aún no ha definido el evento'),
      findsOneWidget,
    );
    expect(find.text('Asistentes confirmados: 0'), findsOneWidget);
  });

  testWidgets(
    'participantes: aparece quien inició sesión, sin botón de agregar',
    (tester) async {
      await abrir(tester);
      await tester.tap(find.text('Participantes'));
      await tester.pumpAndSettle();

      expect(find.text('Agregar participante'), findsNothing);
      expect(find.text('Ana (Tú)'), findsOneWidget);
      expect(find.text('Tal vez: 1'), findsOneWidget);
      expect(find.text('Eres admin'), findsNothing);

      await tester.tap(find.text('Sí'));
      await tester.pumpAndSettle();
      expect(find.text('Sí: 1'), findsOneWidget);
      expect(find.text('Tal vez: 0'), findsOneWidget);
    },
  );

  testWidgets('no admin: solo puede cambiar su propia asistencia y no quita', (
    tester,
  ) async {
    await abrir(
      tester,
      participantes: FakeParticipanteRepository(
        inicial: const [Participante(id: 'u-2', nombre: 'Beto')],
      ),
    );
    await tester.tap(find.text('Participantes'));
    await tester.pumpAndSettle();

    SegmentedButton<Asistencia> selector(String id) => tester.widget(
      find.descendant(
        of: find.byKey(ValueKey('participante-$id')),
        matching: find.byType(SegmentedButton<Asistencia>),
      ),
    );
    expect(selector('u-1').onSelectionChanged, isNotNull);
    expect(selector('u-2').onSelectionChanged, isNull);
    expect(find.byIcon(Icons.person_remove_outlined), findsNothing);
  });

  testWidgets('admin: edita a todos, quita participantes y ve "Eres admin"', (
    tester,
  ) async {
    await abrir(
      tester,
      admin: true,
      participantes: FakeParticipanteRepository(
        inicial: const [Participante(id: 'u-2', nombre: 'Beto')],
      ),
    );
    await tester.tap(find.text('Participantes'));
    await tester.pumpAndSettle();

    expect(find.text('Eres admin'), findsOneWidget);
    SegmentedButton<Asistencia> selector(String id) => tester.widget(
      find.descendant(
        of: find.byKey(ValueKey('participante-$id')),
        matching: find.byType(SegmentedButton<Asistencia>),
      ),
    );
    expect(selector('u-2').onSelectionChanged, isNotNull);
    expect(find.byIcon(Icons.person_remove_outlined), findsNWidgets(2));
  });

  testWidgets('no admin: Inicio es de solo lectura', (tester) async {
    await abrir(tester);
    expect(find.text('Crear evento'), findsNothing);
    expect(find.text('Editar evento'), findsNothing);
    expect(
      find.text('El organizador aún no ha definido el evento'),
      findsOneWidget,
    );
  });

  testWidgets('admin: puede crear el evento desde Inicio', (tester) async {
    await abrir(tester, admin: true);
    expect(find.text('Crear evento'), findsOneWidget);
    expect(find.textContaining('Todavía no hay evento'), findsOneWidget);
  });

  testWidgets('no admin: aportaciones sin eliminar y lista solo en las suyas', (
    tester,
  ) async {
    await abrir(
      tester,
      aportaciones: FakeAportacionRepository(
        inicial: const [
          Aportacion(id: 'a-1', articulo: 'Ponche', cantidad: 2),
          Aportacion(
            id: 'a-2',
            articulo: 'Piñata',
            cantidad: 1,
            responsableId: 'u-1',
          ),
        ],
      ),
    );
    await tester.tap(find.text('Aportaciones'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    Checkbox casilla(String id) => tester.widget(
      find.descendant(
        of: find.byKey(ValueKey('aportacion-$id')),
        matching: find.byType(Checkbox),
      ),
    );
    expect(casilla('a-1').onChanged, isNull);
    expect(casilla('a-2').onChanged, isNotNull);
  });

  testWidgets('marcar una aportación como lista actualiza contadores', (
    tester,
  ) async {
    await abrir(
      tester,
      aportaciones: FakeAportacionRepository(
        inicial: const [
          Aportacion(
            id: 'a-1',
            articulo: 'Ponche',
            cantidad: 2,
            responsableId: 'u-1',
          ),
        ],
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
