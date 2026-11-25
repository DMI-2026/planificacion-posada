import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planificacion_posada/features/arbol/repositories/fake_arbol_repository.dart';
import 'package:planificacion_posada/features/arbol/services/musica_arbol.dart';
import 'package:planificacion_posada/features/arbol/viewmodels/arbol_view_model.dart';
import 'package:planificacion_posada/features/arbol/views/arbol_view.dart';

class MusicaFalsa implements MusicaArbol {
  MusicaFalsa({this.resultados = const []});

  /// Resultado de cada llamada a iniciar (la última se repite; vacío = true).
  final List<bool> resultados;
  int iniciar_ = 0;
  int pausas = 0;
  int liberaciones = 0;

  @override
  Future<bool> iniciar() async {
    final i = iniciar_++;
    if (resultados.isEmpty) return true;
    return resultados[i < resultados.length ? i : resultados.length - 1];
  }

  @override
  Future<void> pausar() async => pausas++;

  @override
  Future<void> liberar() async => liberaciones++;
}

Future<void> _montar(WidgetTester tester, MusicaFalsa musica) async {
  tester.view.physicalSize = const Size(500, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final vm = ArbolViewModel(
    FakeArbolRepository(),
    uid: 'u1',
    esAdmin: false,
    esParticipante: true,
    nombres: const {'u1': 'Ana'},
  );
  addTearDown(vm.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ArbolView(viewModel: vm, crearMusica: () => musica),
      ),
    ),
  );
  await tester.pump();
}

Finder get _icono => find.descendant(
  of: find.byKey(const Key('musica-toggle')),
  matching: find.byType(Icon),
);

IconData _actual(WidgetTester tester) => tester.widget<Icon>(_icono).icon!;

void main() {
  testWidgets('arranca al abrir y muestra el icono de música', (tester) async {
    final m = MusicaFalsa();
    await _montar(tester, m);
    expect(m.iniciar_, 1);
    expect(_actual(tester), Icons.music_note);
    expect(find.byTooltip('Silenciar música'), findsOneWidget);
  });

  testWidgets('el botón pausa y reanuda', (tester) async {
    final m = MusicaFalsa();
    await _montar(tester, m);
    await tester.tap(find.byKey(const Key('musica-toggle')));
    await tester.pump();
    expect(m.pausas, 1);
    expect(_actual(tester), Icons.music_off);
    expect(find.byTooltip('Activar música'), findsOneWidget);
    await tester.tap(find.byKey(const Key('musica-toggle')));
    await tester.pump();
    expect(m.iniciar_, 2);
    expect(_actual(tester), Icons.music_note);
  });

  testWidgets('se libera al salir de la vista', (tester) async {
    final m = MusicaFalsa();
    await _montar(tester, m);
    await tester.pumpWidget(const SizedBox());
    expect(m.liberaciones, 1);
  });

  testWidgets('si falla al abrir muestra silencio sin romper', (tester) async {
    final m = MusicaFalsa(resultados: [false, false]);
    await _montar(tester, m);
    expect(tester.takeException(), isNull);
    expect(_actual(tester), Icons.music_off);
    expect(find.byTooltip('Activar música'), findsOneWidget);
    // Un fallo repetido no muestra avisos.
    await tester.tap(find.byKey(const Key('fondo-arbol')));
    await tester.pump();
    expect(find.byKey(const Key('aviso-arbol')), findsNothing);
    expect(_actual(tester), Icons.music_off);
  });

  testWidgets('si el autoplay se bloquea, el primer toque arranca', (
    tester,
  ) async {
    final m = MusicaFalsa(resultados: [false, true]);
    await _montar(tester, m);
    expect(_actual(tester), Icons.music_off);
    await tester.tap(find.byKey(const Key('fondo-arbol')));
    await tester.pump();
    expect(m.iniciar_, 2);
    expect(_actual(tester), Icons.music_note);
    // Toques posteriores no reinician.
    await tester.tap(find.byKey(const Key('fondo-arbol')));
    await tester.pump();
    expect(m.iniciar_, 2);
  });

  testWidgets('tocar el botón tras un bloqueo cuenta una sola vez', (
    tester,
  ) async {
    final m = MusicaFalsa(resultados: [false, true]);
    await _montar(tester, m);
    await tester.tap(find.byKey(const Key('musica-toggle')));
    await tester.pump();
    expect(m.iniciar_, 2);
    expect(m.pausas, 0);
    expect(_actual(tester), Icons.music_note);
  });

  testWidgets('una excepción al iniciar no rompe la vista', (tester) async {
    await _montar(tester, _Explota());
    expect(tester.takeException(), isNull);
    expect(_actual(tester), Icons.music_off);
  });
}

class _Explota extends MusicaFalsa {
  @override
  Future<bool> iniciar() async => throw StateError('sin audio');
}
