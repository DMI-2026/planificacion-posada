import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planificacion_posada/core/efectos/efectos.dart';
import 'package:planificacion_posada/core/navegacion/posada_scope.dart';
import 'package:planificacion_posada/core/theme/app_theme.dart';
import 'package:planificacion_posada/features/aportaciones/repositories/fake_aportacion_repository.dart';
import 'package:planificacion_posada/features/aportaciones/viewmodels/aportaciones_view_model.dart';
import 'package:planificacion_posada/features/evento/repositories/fake_evento_repository.dart';
import 'package:planificacion_posada/features/evento/viewmodels/evento_view_model.dart';
import 'package:planificacion_posada/features/participantes/models/participante.dart';
import 'package:planificacion_posada/features/participantes/repositories/fake_participante_repository.dart';
import 'package:planificacion_posada/features/participantes/viewmodels/participantes_view_model.dart';
import 'package:planificacion_posada/features/participantes/views/participantes_view.dart';

import '../../helpers/sesion_prueba.dart';

Future<ParticipantesViewModel> abrir(
  WidgetTester tester, {
  required bool reducido,
}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  if (reducido) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  final sesion = sesionPrueba();
  final p = ParticipantesViewModel(
    FakeParticipanteRepository(
      inicial: const [
        Participante(id: 'u-1', nombre: 'Ana María'),
        Participante(id: 'u-2', nombre: 'Beto'),
      ],
    ),
    sesion: sesion,
  );
  final e = EventoViewModel(FakeEventoRepository(), sesion: sesion);
  final a = AportacionesViewModel(FakeAportacionRepository(), sesion: sesion);
  addTearDown(() {
    p.dispose();
    e.dispose();
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
        child: const ParticipantesView(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
  return p;
}

void main() {
  test('iniciales y degradado son estables por nombre', () {
    expect(iniciales('Ana María'), 'AM');
    expect(iniciales('  beto '), 'B');
    expect(iniciales(''), '?');
    expect(degradadoAvatar('Beto'), degradadoAvatar('Beto'));
  });

  testWidgets('confirmar "Sí" con movimiento reducido no lanza errores', (
    tester,
  ) async {
    final vm = await abrir(tester, reducido: true);
    expect(find.text('Ana María (Tú)'), findsOneWidget);
    expect(find.text('AM'), findsOneWidget);
    expect(find.text('Tal vez: 2'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('participante-u-1')),
        matching: find.text('Sí'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
    expect(vm.conteo(Asistencia.si), 1);
    expect(find.text('Sí: 1'), findsOneWidget);
    expect(find.byType(Overlay), findsWidgets);
  });

  testWidgets('confirmar "Sí" con animaciones lanza confeti y termina', (
    tester,
  ) async {
    await abrir(tester, reducido: false);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('participante-u-1')),
        matching: find.text('Sí'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(Confeti), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(Confeti), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('cambiar a otra opción o a otra persona no lanza confeti', (
    tester,
  ) async {
    await abrir(tester, reducido: false);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('participante-u-1')),
        matching: find.text('No'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(Confeti), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
