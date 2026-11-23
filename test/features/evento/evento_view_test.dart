import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planificacion_posada/core/navegacion/posada_scope.dart';
import 'package:planificacion_posada/core/theme/app_theme.dart';
import 'package:planificacion_posada/features/aportaciones/repositories/fake_aportacion_repository.dart';
import 'package:planificacion_posada/features/aportaciones/viewmodels/aportaciones_view_model.dart';
import 'package:planificacion_posada/features/evento/models/evento.dart';
import 'package:planificacion_posada/features/evento/repositories/fake_evento_repository.dart';
import 'package:planificacion_posada/features/evento/viewmodels/evento_view_model.dart';
import 'package:planificacion_posada/features/evento/views/evento_view.dart';
import 'package:planificacion_posada/features/participantes/repositories/fake_participante_repository.dart';
import 'package:planificacion_posada/features/participantes/viewmodels/participantes_view_model.dart';

import '../../helpers/sesion_prueba.dart';

Future<void> abrir(
  WidgetTester tester,
  Evento? evento,
  DateTime ahora, {
  bool reducido = true,
}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  if (reducido) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  final sesion = sesionPrueba(admin: true);
  final eventoVm = EventoViewModel(
    FakeEventoRepository(inicial: evento),
    sesion: sesion,
  );
  final partVm = ParticipantesViewModel(
    FakeParticipanteRepository(),
    sesion: sesion,
  );
  final aportVm = AportacionesViewModel(
    FakeAportacionRepository(),
    sesion: sesion,
  );
  addTearDown(() {
    eventoVm.dispose();
    partVm.dispose();
    aportVm.dispose();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.noche,
      home: PosadaScope(
        sesion: sesion,
        evento: eventoVm,
        participantes: partVm,
        aportaciones: aportVm,
        child: EventoView(ahora: () => ahora),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  final ahora = DateTime(2026, 12, 1, 10);

  testWidgets('cuenta regresiva: fecha futura muestra días, horas, min y seg', (
    tester,
  ) async {
    final evento = Evento(
      nombre: 'Posada DMI',
      fecha: DateTime(2026, 12, 18, 19, 30, 15),
      lugar: 'Aula 5',
    );
    await abrir(tester, evento, ahora);
    expect(find.text('Posada DMI'), findsOneWidget);
    // 17 días, 9 h, 30 min, 15 s.
    expect(find.text('17'), findsOneWidget);
    expect(find.text('09'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('15'), findsOneWidget);
    for (final e in ['días', 'horas', 'min', 'seg']) {
      expect(find.text(e), findsOneWidget);
    }
    expect(find.text('¡Es hoy!'), findsNothing);
    expect(find.text('18/12/2026 19:30'), findsOneWidget);
    expect(find.text('Aula 5'), findsOneWidget);
    expect(find.text('Asistentes confirmados'), findsOneWidget);
  });

  testWidgets('cuenta regresiva: el día del evento muestra "¡Es hoy!"', (
    tester,
  ) async {
    final evento = Evento(
      nombre: 'Posada DMI',
      fecha: DateTime(2026, 12, 1, 19),
    );
    await abrir(tester, evento, ahora);
    expect(find.text('¡Es hoy!'), findsOneWidget);
    expect(find.text('días'), findsNothing);
  });

  testWidgets('cuenta regresiva: evento pasado avisa que ya pasó', (
    tester,
  ) async {
    final evento = Evento(nombre: 'Posada DMI', fecha: DateTime(2026, 11, 30));
    await abrir(tester, evento, ahora);
    expect(find.text('La posada ya pasó'), findsOneWidget);
  });

  testWidgets('cuenta regresiva avanza cada segundo con animación activa', (
    tester,
  ) async {
    var reloj = ahora;
    final evento = Evento(
      nombre: 'Posada',
      fecha: DateTime(2026, 12, 2, 10, 1),
    );
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sesion = sesionPrueba(admin: true);
    final e = EventoViewModel(
      FakeEventoRepository(inicial: evento),
      sesion: sesion,
    );
    final p = ParticipantesViewModel(
      FakeParticipanteRepository(),
      sesion: sesion,
    );
    final a = AportacionesViewModel(FakeAportacionRepository(), sesion: sesion);
    addTearDown(() {
      e.dispose();
      p.dispose();
      a.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.noche,
        home: PosadaScope(
          sesion: sesion,
          evento: e,
          participantes: p,
          aportaciones: a,
          child: EventoView(ahora: () => reloj),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('01'), findsNWidgets(2)); // 1 día y 1 minuto
    expect(find.text('00'), findsNWidgets(2)); // horas y segundos
    reloj = ahora.add(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('30'), findsOneWidget); // quedan 30 s
    expect(find.text('01'), findsOneWidget); // solo el día
    // Desmonta para cancelar temporizadores y animaciones.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sin evento y admin: invita a crear y muestra el botón', (
    tester,
  ) async {
    await abrir(tester, null, ahora);
    expect(
      find.text('Todavía no hay evento. Crea la posada de la clase.'),
      findsOneWidget,
    );
    expect(find.text('Crear evento'), findsOneWidget);
  });
}
