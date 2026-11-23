import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planificacion_posada/core/theme/app_theme.dart';
import 'package:planificacion_posada/features/votacion/models/comida_opcion.dart';
import 'package:planificacion_posada/features/votacion/models/limites_votacion.dart';
import 'package:planificacion_posada/features/votacion/models/voto.dart';
import 'package:planificacion_posada/features/votacion/repositories/fake_votacion_repository.dart';
import 'package:planificacion_posada/features/votacion/viewmodels/votacion_view_model.dart';
import 'package:planificacion_posada/features/votacion/views/votacion_view.dart';

Future<void> _pausa() => Future<void>.delayed(Duration.zero);

ComidaOpcion _o(String id, String nombre, {String por = 'u1'}) =>
    ComidaOpcion(id: id, nombre: nombre, propuestaPor: por);

Future<VotacionViewModel> _vm(
  FakeVotacionRepository repo, {
  String uid = 'u1',
  bool admin = false,
  bool participante = true,
}) async {
  final vm = VotacionViewModel(
    repo,
    uid: uid,
    esAdmin: admin,
    esParticipante: participante,
  );
  await _pausa();
  return vm;
}

void main() {
  group('modelos', () {
    test('ComidaOpcion toMap/fromMap', () {
      final f = DateTime.utc(2026, 12, 1);
      final o = ComidaOpcion(
        id: 'o1',
        nombre: 'Pozole',
        descripcion: 'Rojo',
        propuestaPor: 'u1',
        creada: f,
      );
      expect(o.toMap(), {
        'nombre': 'Pozole',
        'descripcion': 'Rojo',
        'propuesta_por': 'u1',
        'creada': f,
      });
      final c = ComidaOpcion.fromMap('o1', o.toMap());
      expect(
        [c.id, c.nombre, c.descripcion, c.propuestaPor, c.creada],
        ['o1', 'Pozole', 'Rojo', 'u1', f],
      );
    });

    test('ComidaOpcion.fromMap tolera campos ausentes', () {
      final c = ComidaOpcion.fromMap('x', {'nombre': 'A'});
      expect(c.descripcion, '');
      expect(c.propuestaPor, '');
      expect(c.creada, isNull);
    });

    test('Voto toMap/fromMap', () {
      const v = Voto(uid: 'u1', opcionId: 'o1');
      expect(v.toMap(), {'opcion_id': 'o1'});
      final c = Voto.fromMap('u1', v.toMap());
      expect([c.uid, c.opcionId], ['u1', 'o1']);
    });
  });

  group('VotacionViewModel', () {
    test(
      'carga opciones y votos, ordena por votos y calcula porcentajes',
      () async {
        final repo = FakeVotacionRepository(
          opciones: [_o('a', 'Pozole'), _o('b', 'Tamales'), _o('c', 'Pavo')],
          votos: const [
            Voto(uid: 'x', opcionId: 'b'),
            Voto(uid: 'y', opcionId: 'b'),
            Voto(uid: 'z', opcionId: 'a'),
            Voto(uid: 'w', opcionId: 'b'),
          ],
        );
        final vm = await _vm(repo);
        expect(vm.cargando, isFalse);
        final r = vm.resultados;
        expect(r.map((e) => e.opcion.id), ['b', 'a', 'c']);
        expect(r.map((e) => e.votos), [3, 1, 0]);
        expect(r.map((e) => e.porcentaje), [0.75, 0.25, 0.0]);
        expect(vm.totalVotos, 4);
        vm.dispose();
      },
    );

    test('un voto por persona: votar de nuevo cambia el voto', () async {
      final repo = FakeVotacionRepository(
        opciones: [_o('a', 'Pozole'), _o('b', 'Tamales')],
      );
      final vm = await _vm(repo);
      expect(await vm.votar('a'), isTrue);
      await _pausa();
      expect(vm.miVoto, 'a');
      expect(await vm.votar('b'), isTrue);
      await _pausa();
      expect(vm.miVoto, 'b');
      expect(vm.totalVotos, 1);
      expect(vm.resultados.first.opcion.id, 'b');
      vm.dispose();
    });

    test('quitarVoto lo retira mientras está abierta', () async {
      final repo = FakeVotacionRepository(
        opciones: [_o('a', 'Pozole')],
        votos: const [Voto(uid: 'u1', opcionId: 'a')],
      );
      final vm = await _vm(repo);
      expect(vm.miVoto, 'a');
      expect(await vm.quitarVoto(), isTrue);
      await _pausa();
      expect(vm.miVoto, isNull);
      expect(vm.totalVotos, 0);
      vm.dispose();
    });

    test('cerrada bloquea votar y quitar voto sin cambiar nada', () async {
      final repo = FakeVotacionRepository(
        opciones: [_o('a', 'Pozole'), _o('b', 'Tamales')],
        votos: const [Voto(uid: 'u1', opcionId: 'a')],
        cerrada: true,
      );
      final vm = await _vm(repo);
      expect(vm.cerrada, isTrue);
      expect(await vm.votar('b'), isFalse);
      expect(vm.error, 'La votación está cerrada.');
      expect(await vm.quitarVoto(), isFalse);
      await _pausa();
      expect(vm.miVoto, 'a');
      expect(vm.totalVotos, 1);
      vm.dispose();
    });

    test('no participante no puede votar ni proponer', () async {
      final repo = FakeVotacionRepository(opciones: [_o('a', 'Pozole')]);
      final vm = await _vm(repo, participante: false);
      expect(await vm.votar('a'), isFalse);
      expect(vm.error, 'Solo los participantes pueden votar.');
      expect(await vm.proponer('Flan', ''), isFalse);
      expect(vm.error, 'Solo los participantes pueden proponer platillos.');
      await _pausa();
      expect(vm.totalVotos, 0);
      expect(vm.resultados.length, 1);
      vm.dispose();
    });

    test('votar por una opción inexistente falla', () async {
      final vm = await _vm(FakeVotacionRepository());
      expect(await vm.votar('nada'), isFalse);
      expect(vm.error, 'Ese platillo ya no existe.');
      vm.dispose();
    });

    test(
      'ganadores: vacío abierta, uno cerrada, todos los empatados',
      () async {
        final repo = FakeVotacionRepository(
          opciones: [_o('a', 'Pozole'), _o('b', 'Tamales'), _o('c', 'Pavo')],
          votos: const [
            Voto(uid: 'x', opcionId: 'a'),
            Voto(uid: 'y', opcionId: 'b'),
            Voto(uid: 'z', opcionId: 'b'),
          ],
        );
        final vm = await _vm(repo, admin: true);
        expect(vm.ganadores, isEmpty);
        expect(await vm.cerrar(), isTrue);
        await _pausa();
        expect(vm.cerrada, isTrue);
        expect(vm.ganadores.map((o) => o.id), ['b']);
        await vm.reabrir();
        await _pausa();
        expect(vm.cerrada, isFalse);
        await repo.votar('w', 'a');
        await _pausa();
        await vm.cerrar();
        await _pausa();
        expect(vm.ganadores.map((o) => o.id), ['a', 'b']);
        vm.dispose();
      },
    );

    test('cerrada sin votos no tiene ganadores', () async {
      final vm = await _vm(
        FakeVotacionRepository(opciones: [_o('a', 'Pozole')], cerrada: true),
      );
      expect(vm.ganadores, isEmpty);
      vm.dispose();
    });

    test('cerrar y reabrir solo el admin', () async {
      final repo = FakeVotacionRepository();
      final vm = await _vm(repo);
      expect(await vm.cerrar(), isFalse);
      expect(vm.error, 'Solo el admin puede cerrar o reabrir la votación.');
      await _pausa();
      expect(vm.cerrada, isFalse);
      vm.dispose();
    });

    test('cerrada: no se propone ni borra (salvo admin que modera)', () async {
      final repo = FakeVotacionRepository(
        opciones: [_o('a', 'Pozole'), _o('b', 'Tamales', por: 'u2')],
        cerrada: true,
      );
      final vm = await _vm(repo);
      expect(vm.puedeEliminar(vm.resultados.first.opcion), isFalse);
      expect(await vm.proponer('Flan', ''), isFalse);
      expect(vm.error, 'La votación está cerrada.');
      expect(await vm.eliminarOpcion('a'), isFalse);
      expect(vm.error, 'La votación está cerrada.');
      await _pausa();
      expect(vm.resultados.length, 2);
      vm.dispose();

      final admin = await _vm(repo, uid: 'adm', admin: true);
      expect(admin.puedeEliminar(admin.resultados.first.opcion), isTrue);
      expect(await admin.proponer('Flan', ''), isFalse);
      expect(admin.error, 'La votación está cerrada.');
      expect(await admin.eliminarOpcion('b'), isTrue);
      await _pausa();
      expect(admin.resultados.map((r) => r.opcion.id), ['a']);
      admin.dispose();
    });

    test('eliminar: quien propuso o el admin; otros no', () async {
      final repo = FakeVotacionRepository(
        opciones: [
          _o('a', 'Pozole'),
          _o('b', 'Tamales', por: 'u2'),
        ],
      );
      final vm = await _vm(repo);
      expect(await vm.eliminarOpcion('b'), isFalse);
      expect(vm.error, 'Solo quien lo propuso o el admin puede eliminarlo.');
      expect(await vm.eliminarOpcion('a'), isTrue);
      await _pausa();
      expect(vm.resultados.map((r) => r.opcion.id), ['b']);
      vm.dispose();

      final admin = await _vm(repo, uid: 'adm', admin: true);
      expect(await admin.eliminarOpcion('b'), isTrue);
      await _pausa();
      expect(admin.vacio, isTrue);
      admin.dispose();
    });

    test(
      'votos de una opción eliminada se ignoran y se puede votar otra vez',
      () async {
        final repo = FakeVotacionRepository(
          opciones: [_o('a', 'Pozole'), _o('b', 'Tamales')],
          votos: const [Voto(uid: 'u1', opcionId: 'a')],
        );
        final vm = await _vm(repo, admin: true);
        await vm.eliminarOpcion('a');
        await _pausa();
        expect(vm.miVoto, isNull);
        expect(vm.totalVotos, 0);
        expect(await vm.votar('b'), isTrue);
        await _pausa();
        expect(vm.miVoto, 'b');
        vm.dispose();
      },
    );

    test('proponer valida y guarda recortado', () async {
      final repo = FakeVotacionRepository();
      final vm = await _vm(repo);
      expect(await vm.proponer('   ', ''), isFalse);
      expect(vm.error, 'El nombre del platillo no puede estar vacío.');
      expect(
        await vm.proponer('a' * (LimitesVotacion.nombreMax + 1), ''),
        isFalse,
      );
      expect(vm.error, 'El nombre no puede pasar de 80 caracteres.');
      expect(
        await vm.proponer('Flan', 'a' * (LimitesVotacion.descripcionMax + 1)),
        isFalse,
      );
      expect(vm.error, 'La descripción no puede pasar de 300 caracteres.');
      await _pausa();
      expect(vm.vacio, isTrue);
      expect(await vm.proponer('  Flan  ', ' rico '), isTrue);
      expect(vm.error, isNull);
      await _pausa();
      final o = vm.resultados.single.opcion;
      expect([o.nombre, o.descripcion, o.propuestaPor], ['Flan', 'rico', 'u1']);
      expect(await vm.proponer('a' * 80, 'b' * 300), isTrue);
      vm.dispose();
    });

    test(
      'error de stream se muestra y dispose cancela suscripciones',
      () async {
        final repo = FakeVotacionRepository();
        final vm = await _vm(repo);
        expect(repo.escuchas, 3);
        repo.emitirError('boom');
        await _pausa();
        expect(vm.error, 'No pudimos cargar la votación. Intenta de nuevo.');
        vm.dispose();
        expect(repo.escuchas, 0);
      },
    );
  });

  group('VotacionView', () {
    Future<void> montar(WidgetTester tester, VotacionViewModel vm) async {
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.noche,
          home: VotacionView(viewModel: vm),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('votar, cambiar, cerrar y mostrar ganador', (tester) async {
      final repo = FakeVotacionRepository(
        opciones: [
          _o('a', 'Pozole'),
          _o('b', 'Tamales', por: 'u2'),
        ],
      );
      final vm = VotacionViewModel(
        repo,
        uid: 'u1',
        esAdmin: true,
        esParticipante: true,
      );
      addTearDown(vm.dispose);
      await montar(tester, vm);

      expect(find.text('Votación abierta'), findsOneWidget);
      expect(find.text('Proponer platillo'), findsOneWidget);
      expect(find.text('Votar'), findsNWidgets(2));

      await tester.tap(find.text('Votar').first);
      await tester.pumpAndSettle();
      expect(find.text('Quitar voto'), findsOneWidget);
      expect(vm.miVoto, 'a');

      await tester.tap(find.text('Cerrar votación'));
      await tester.pumpAndSettle();
      expect(find.text('Votación cerrada'), findsOneWidget);
      expect(find.text('Ganador: Pozole'), findsOneWidget);
      expect(find.text('Proponer platillo'), findsNothing);
      expect(find.text('Votar'), findsNothing);
      expect(find.text('Tu voto'), findsOneWidget);

      await tester.tap(find.text('Reabrir votación'));
      await tester.pumpAndSettle();
      expect(find.text('Votación abierta'), findsOneWidget);
    });

    testWidgets('proponer desde el diálogo y validar', (tester) async {
      final repo = FakeVotacionRepository();
      final vm = VotacionViewModel(
        repo,
        uid: 'u1',
        esAdmin: false,
        esParticipante: true,
      );
      addTearDown(vm.dispose);
      await montar(tester, vm);

      expect(
        find.text('Aún no hay platillos. ¡Propón el primero!'),
        findsOneWidget,
      );
      await tester.tap(find.text('Proponer platillo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Proponer'));
      await tester.pumpAndSettle();
      expect(
        find.text('El nombre del platillo no puede estar vacío.'),
        findsWidgets,
      );
      await tester.enterText(find.byType(TextField).first, 'Buñuelos');
      await tester.tap(find.text('Proponer'));
      await tester.pumpAndSettle();
      expect(find.text('Buñuelos'), findsOneWidget);
      expect(find.text('Cerrar votación'), findsNothing);
      expect(find.byTooltip('Eliminar platillo'), findsOneWidget);
    });

    testWidgets('no participante solo ve resultados', (tester) async {
      final repo = FakeVotacionRepository(opciones: [_o('a', 'Pozole')]);
      final vm = VotacionViewModel(
        repo,
        uid: 'u9',
        esAdmin: false,
        esParticipante: false,
      );
      addTearDown(vm.dispose);
      await montar(tester, vm);
      expect(find.text('Pozole'), findsOneWidget);
      expect(find.text('Votar'), findsNothing);
      expect(find.text('Proponer platillo'), findsNothing);
      expect(find.byTooltip('Eliminar platillo'), findsNothing);
    });
  });
}
