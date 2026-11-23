import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planificacion_posada/core/navegacion/posada_scope.dart';
import 'package:planificacion_posada/core/theme/app_theme.dart';
import 'package:planificacion_posada/features/aportaciones/models/aportacion.dart';
import 'package:planificacion_posada/features/aportaciones/repositories/fake_aportacion_repository.dart';
import 'package:planificacion_posada/features/aportaciones/viewmodels/aportaciones_view_model.dart';
import 'package:planificacion_posada/features/aportaciones/views/aportaciones_view.dart';
import 'package:planificacion_posada/features/evento/repositories/fake_evento_repository.dart';
import 'package:planificacion_posada/features/evento/viewmodels/evento_view_model.dart';
import 'package:planificacion_posada/features/participantes/models/participante.dart';
import 'package:planificacion_posada/features/participantes/repositories/fake_participante_repository.dart';
import 'package:planificacion_posada/features/participantes/viewmodels/participantes_view_model.dart';

import '../../helpers/sesion_prueba.dart';

void main() {
  late FakeAportacionRepository repo;

  /// Monta la vista con un PosadaScope. Si el scope cambia de campos (p. ej.
  /// se quita `evento`), solo hay que ajustar este método.
  Future<AportacionesViewModel> montar(
    WidgetTester tester, {
    bool admin = false,
    List<Aportacion> inicial = const [],
    int? meta,
  }) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final sesion = sesionPrueba(admin: admin);
    repo = FakeAportacionRepository(inicial: inicial, metaInicial: meta);
    final vm = AportacionesViewModel(repo, sesion: sesion);
    final evento = EventoViewModel(FakeEventoRepository(), sesion: sesion);
    final participantes = ParticipantesViewModel(
      FakeParticipanteRepository(
        inicial: const [
          Participante(id: 'u-1', nombre: 'Ana'),
          Participante(id: 'u-2', nombre: 'Beto'),
        ],
      ),
      sesion: sesion,
    );
    addTearDown(() {
      vm.dispose();
      evento.dispose();
      participantes.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.noche,
        home: PosadaScope(
          sesion: sesion,
          evento: evento,
          participantes: participantes,
          aportaciones: vm,
          child: const AportacionesView(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return vm;
  }

  const material = Aportacion(
    id: 'm-1',
    articulo: 'Ponche',
    cantidad: 2,
    responsableId: 'u-1',
  );
  const e1 = Aportacion.economica(
    id: 'e-1',
    responsableId: 'u-1',
    montoCentavos: 12345,
  );
  const e2 = Aportacion.economica(
    id: 'e-2',
    responsableId: 'u-2',
    montoCentavos: 5000,
    recibido: true,
  );

  testWidgets('muestra el material por defecto y alterna a económica', (
    tester,
  ) async {
    await montar(tester, inicial: [material, e1]);
    expect(find.text('Ponche (x2)'), findsOneWidget);
    expect(find.text(r'$123.45'), findsNothing);
    await tester.tap(find.text('Económica'));
    await tester.pump();
    expect(find.text('Ponche (x2)'), findsNothing);
    expect(find.text(r'$123.45'), findsOneWidget);
    expect(find.text('Ana · Pendiente'), findsOneWidget);
  });

  testWidgets('encabezado económico: total, meta y progreso', (tester) async {
    await montar(tester, inicial: [e1, e2], meta: 20000);
    await tester.tap(find.text('Económica'));
    await tester.pump();
    expect(find.text(r'$50.00'), findsWidgets); // recibido (e2)
    expect(find.text(r'Meta: $200.00 · 25%'), findsOneWidget);
    expect(find.text(r'Registrado: $173.45'), findsOneWidget);
    expect(find.byKey(const ValueKey('meta-alcanzada')), findsNothing);
    // No admin: sin editor de meta ni interruptor de recibido.
    expect(find.byKey(const ValueKey('editar-meta')), findsNothing);
    expect(find.byKey(const ValueKey('recibido-e-1')), findsNothing);
  });

  testWidgets('meta alcanzada muestra el mensaje', (tester) async {
    await montar(tester, inicial: [e2], meta: 5000);
    await tester.tap(find.text('Económica'));
    await tester.pump();
    expect(find.byKey(const ValueKey('meta-alcanzada')), findsOneWidget);
    expect(find.text(r'Meta: $50.00 · 100%'), findsOneWidget);
  });

  testWidgets('admin marca recibido y edita la meta', (tester) async {
    final vm = await montar(tester, admin: true, inicial: [e1]);
    await tester.tap(find.text('Económica'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('recibido-e-1')));
    await tester.pump();
    await tester.pump();
    expect(vm.economicas.single.recibido, isTrue);

    await tester.tap(find.byKey(const ValueKey('editar-meta')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('campo-monto')), '1000');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(vm.meta, 100000);
  });

  testWidgets('diálogo: registra una aportación económica propia', (
    tester,
  ) async {
    final vm = await montar(tester);
    await tester.tap(find.text('Agregar aportación'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('dialogo-tipo')),
        matching: find.text('Económica'),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('campo-monto')), '75.5');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(vm.economicas.single.montoCentavos, 7550);
    expect(vm.economicas.single.responsableId, 'u-1');
    expect(find.text('Nueva aportación'), findsNothing);
  });

  testWidgets('diálogo: un monto inválido deja el error y no guarda', (
    tester,
  ) async {
    final vm = await montar(tester);
    await tester.tap(find.text('Económica'));
    await tester.pump();
    await tester.tap(find.text('Agregar aportación'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('campo-monto')), 'abc');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(r'El monto debe ser de al menos $0.01.'),
      ),
      findsOneWidget,
    );
    expect(vm.economicas, isEmpty);
    expect(repo.escrituras, 0);
  });

  testWidgets('diálogo: sigue agregando material', (tester) async {
    final vm = await montar(tester);
    await tester.tap(find.text('Agregar aportación'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Tamales');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(vm.materiales.single.articulo, 'Tamales');
  });
}
