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
import 'package:planificacion_posada/features/arbol/repositories/fake_arbol_repository.dart';
import 'package:planificacion_posada/features/intercambio/repositories/fake_intercambio_repository.dart';
import 'package:planificacion_posada/features/itinerario/repositories/fake_itinerario_repository.dart';
import 'package:planificacion_posada/features/votacion/repositories/fake_votacion_repository.dart';
import 'package:planificacion_posada/main.dart';

/// Ir a «Aportaciones», que en pantalla angosta vive bajo «Más».
Future<void> irAAportaciones(WidgetTester tester) async {
  if (find.byType(NavigationBar).evaluate().isNotEmpty) {
    await tester.tap(find.text('Más'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mas-Aportaciones')));
  } else {
    await tester.tap(find.text('Aportaciones'));
  }
  await tester.pumpAndSettle();
}

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
      votacionRepository: FakeVotacionRepository(),
      itinerarioRepository: FakeItinerarioRepository(),
      arbolRepository: FakeArbolRepository(),
      intercambioRepository: FakeIntercambioRepository(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('el shell muestra 4 destinos y «Más», e Inicio vacío', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await abrir(tester);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Participantes'), findsOneWidget);
    expect(find.text('Comida'), findsOneWidget);
    expect(find.text('Itinerario'), findsOneWidget);
    expect(find.text('Más'), findsOneWidget);
    expect(find.text('Aportaciones'), findsNothing);
    expect(
      find.text('El organizador aún no ha definido el evento'),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('estadistica-confirmados')),
        matching: find.text('0'),
      ),
      findsOneWidget,
    );
    expect(find.text('Asistentes confirmados'), findsOneWidget);
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
    await irAAportaciones(tester);
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
    await irAAportaciones(tester);
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

  const etiquetas = [
    'Inicio',
    'Participantes',
    'Comida',
    'Itinerario',
    'Aportaciones',
    'Árbol',
    'Intercambio',
  ];

  testWidgets('angosto: los 7 destinos se alcanzan (los 3 últimos con «Más»)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await abrir(tester);
    for (final e in etiquetas) {
      if (etiquetas.indexOf(e) < 4) {
        await tester.tap(find.text(e));
      } else {
        await tester.tap(find.text('Más'));
        await tester.pumpAndSettle();
        // La hoja lista exactamente los destinos que no caben en la barra.
        expect(find.byKey(const ValueKey('mas-Aportaciones')), findsOneWidget);
        expect(find.byKey(const ValueKey('mas-Inicio')), findsNothing);
        await tester.tap(find.byKey(ValueKey('mas-$e')));
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: e);
      final barra = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(
        barra.selectedIndex,
        etiquetas.indexOf(e) < 4 ? etiquetas.indexOf(e) : 4,
        reason: 'selección de $e',
      );
    }
    // Tras elegir un destino de «Más» la hoja se cierra y se ve su pantalla.
    expect(find.byKey(const ValueKey('mas-Árbol')), findsNothing);
  });

  testWidgets('ancho: el NavigationRail muestra los 7 destinos', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await abrir(tester);
    for (final e in etiquetas) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.text(e),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: e);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.selectedIndex, etiquetas.indexOf(e));
    }
  });

  testWidgets('el rol se resuelve después: Itinerario muestra lo del admin', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await abrir(tester, admin: true);
    await tester.tap(find.text('Itinerario'));
    await tester.pumpAndSettle();
    expect(find.text('Agregar actividad'), findsOneWidget);
  });

  testWidgets('no admin: Itinerario sin acciones de admin', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await abrir(tester);
    await tester.tap(find.text('Itinerario'));
    await tester.pumpAndSettle();
    expect(find.text('Agregar actividad'), findsNothing);
  });
}
