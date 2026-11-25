import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:planificacion_posada/core/theme/app_theme.dart';
import 'package:planificacion_posada/features/arbol/services/captura_foto.dart';
import 'package:planificacion_posada/features/cohetazo/juego/mapa_arena.dart';
import 'package:planificacion_posada/features/cohetazo/models/direccion.dart';
import 'package:planificacion_posada/features/cohetazo/models/jugador.dart';
import 'package:planificacion_posada/features/cohetazo/repositories/fake_cohetazo_repository.dart';
import 'package:planificacion_posada/features/cohetazo/viewmodels/cohetazo_view_model.dart';
import 'package:planificacion_posada/features/cohetazo/views/cohetazo_view.dart';
import 'package:planificacion_posada/features/cohetazo/views/pintor_arena.dart';

const _uid = 'u1';

class _CapturaFalsa implements CapturaFoto {
  _CapturaFalsa({this.errorAlIniciar});

  final CapturaFotoException? errorAlIniciar;

  @override
  Future<void> iniciar() async {
    if (errorAlIniciar != null) throw errorAlIniciar!;
  }

  @override
  Widget vista(BuildContext context) =>
      const ColoredBox(key: Key('camara-viva'), color: Colors.black);

  @override
  Future<Uint8List> tomar() async {
    final im = img.Image(width: 120, height: 120);
    for (final p in im) {
      p.setRgb(0, 200, 0);
    }
    return img.encodePng(im);
  }

  @override
  Future<void> liberar() async {}
}

class _Banco {
  int t = 2000000;
  late final FakeCohetazoRepository repo = FakeCohetazoRepository(
    reloj: () => t,
  );
  int creados = 0;
  CapturaFoto Function() captura = _CapturaFalsa.new;
}

Future<_Banco> _montar(
  WidgetTester tester, {
  Size tamano = const Size(400, 800),
  _Banco? banco,
}) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  final b = banco ?? _Banco();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.noche,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: CohetazoView(
          uid: _uid,
          nombre: 'Ana',
          crearRepositorio: () {
            b.creados++;
            return b.repo;
          },
          crearCaptura: b.captura,
          reloj: () => b.t,
        ),
      ),
    ),
  );
  await tester.pump();
  return b;
}

Future<void> _tomarFotoYEntrar(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('tomar-avatar')));
  await tester.tap(find.byKey(const Key('tomar-avatar')));
  await tester.pump();
  await tester.pump();
  await tester.tap(find.byKey(const Key('tomar-foto')));
  await tester.pump();
  await tester.pump();
  await tester.tap(find.byKey(const Key('aceptar-foto')));
  await tester.pump();
  await tester.ensureVisible(find.byKey(const Key('entrar-arena')));
  await tester.tap(find.byKey(const Key('entrar-arena')));
  await tester.pump();
  await tester.pump();
}

Future<void> _avanzar(WidgetTester tester, _Banco b, int ms) async {
  var resto = ms;
  while (resto > 0) {
    final paso = resto < 16 ? resto : 16;
    b.t += paso;
    await tester.pump(Duration(milliseconds: paso));
    resto -= paso;
  }
}

void main() {
  group('pantalla de entrada', () {
    testWidgets('muestra título, reglas y exige la foto para entrar', (
      tester,
    ) async {
      final b = await _montar(tester);
      expect(find.text('Cohetazo navideño'), findsOneWidget);
      expect(find.text('Reglas'), findsOneWidget);
      expect(find.byKey(const Key('nombre-jugador')), findsOneWidget);
      expect(find.text('Jugarás como Ana'), findsOneWidget);
      expect(find.text('Tomar foto de avatar'), findsOneWidget);
      expect(find.byKey(const Key('avatar-vacio')), findsOneWidget);
      expect(find.byKey(const Key('aviso-foto-obligatoria')), findsOneWidget);
      // Sin foto el botón de entrar está deshabilitado: no pasa nada.
      await tester.ensureVisible(find.byKey(const Key('entrar-arena')));
      await tester.tap(find.byKey(const Key('entrar-arena')));
      await tester.pump();
      expect(find.byKey(const Key('vista-arena')), findsNothing);
      expect(b.creados, 0);
      expect(b.repo.entradas, 0);
    });

    testWidgets('foto con la cámara de prueba y entrar a la arena', (
      tester,
    ) async {
      final b = await _montar(tester);
      await _tomarFotoYEntrar(tester);
      expect(find.byKey(const Key('vista-arena')), findsOneWidget);
      expect(b.creados, 1);
      expect(b.repo.entradas, 1);
      // El avatar guardado es la miniatura de 96 px de la foto.
      final avatar = b.repo.avataresActuales[_uid]!;
      expect(avatar.length, lessThanOrEqualTo(20000));
      final im = img.decodeJpg(Uint8List.fromList(_base64(avatar)))!;
      expect((im.width, im.height), (96, 96));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'sin cámara: error en español, reintento y avatar de iniciales',
      (tester) async {
        final b = _Banco()
          ..captura = () => _CapturaFalsa(
            errorAlIniciar: const CapturaFotoException(
              'No encontramos una cámara en este dispositivo.',
            ),
          );
        await _montar(tester, banco: b);
        await tester.ensureVisible(find.byKey(const Key('tomar-avatar')));
        await tester.tap(find.byKey(const Key('tomar-avatar')));
        await tester.pump();
        await tester.pump();
        expect(find.byKey(const Key('error-camara')), findsOneWidget);
        await tester.tap(find.byKey(const Key('cerrar-camara')));
        await tester.pump();
        await tester.pump();
        expect(
          tester.widget<Text>(find.byKey(const Key('error-avatar'))).data,
          'No encontramos una cámara en este dispositivo.',
        );
        expect(find.textContaining('https'), findsWidgets);
        expect(find.byKey(const Key('reintentar-avatar')), findsOneWidget);

        // Reintentar vuelve a abrir el diálogo de la cámara.
        await tester.ensureVisible(find.byKey(const Key('reintentar-avatar')));
        await tester.tap(find.byKey(const Key('reintentar-avatar')));
        await tester.pump();
        await tester.pump();
        expect(find.byKey(const Key('error-camara')), findsOneWidget);
        await tester.tap(find.byKey(const Key('cerrar-camara')));
        await tester.pump();
        await tester.pump();

        // Alternativa claramente señalada: iniciales sobre un círculo de color.
        await tester.ensureVisible(find.byKey(const Key('usar-iniciales')));
        await tester.tap(find.byKey(const Key('usar-iniciales')));
        await tester.pump();
        expect(find.byKey(const Key('etiqueta-iniciales')), findsOneWidget);
        expect(find.text('Avatar de iniciales (sin foto)'), findsOneWidget);
        await tester.ensureVisible(find.byKey(const Key('entrar-arena')));
        await tester.tap(find.byKey(const Key('entrar-arena')));
        await tester.pump();
        await tester.pump();
        expect(b.repo.entradas, 1);
        expect(b.repo.avataresActuales[_uid], isNotEmpty);
      },
    );
  });

  group('arena', () {
    testWidgets('muestra jugadores, marcador y estadísticas propias', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final b = _Banco();
      b.repo.simularJugador(
        const Jugador(uid: 'b', nombre: 'Beto', x: 5, y: 1),
        avatar: 'AV',
      );
      await _montar(tester, tamano: const Size(1000, 800), banco: b);
      await _tomarFotoYEntrar(tester);
      await _avanzar(tester, b, 100);
      expect(find.byKey(const Key('lienzo-arena')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('en-linea')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('fila-marcador-b')), findsOneWidget);
      expect(find.byKey(const Key('fila-marcador-$_uid')), findsOneWidget);
      expect(find.text('Beto'), findsOneWidget);
      expect(find.text('Ana'), findsOneWidget);
      for (final k in ['stat-alcance', 'stat-cohetes', 'stat-velocidad']) {
        expect(find.byKey(Key(k)), findsOneWidget, reason: k);
      }
      expect(
        find.descendant(
          of: find.byKey(const Key('stat-alcance')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('el pintor dibuja a cada jugador (pide su avatar)', (
      tester,
    ) async {
      final repo = FakeCohetazoRepository(reloj: () => 5000000);
      repo.simularJugador(const Jugador(uid: 'b', nombre: 'Beto', x: 5, y: 1));
      final vm = CohetazoViewModel(
        repo,
        uid: _uid,
        nombre: 'Ana',
        avatar: 'AV',
        reloj: () => 5000000,
      );
      addTearDown(vm.dispose);
      await tester.runAsync(() async {
        await vm.iniciar();
        await Future<void>.delayed(Duration.zero);
      });
      final pedidos = <String>{};
      final pintor = PintorArena(
        vm: vm,
        imagen: (uid) {
          pedidos.add(uid);
          return null;
        },
      );
      final grabadora = ui.PictureRecorder();
      pintor.paint(Canvas(grabadora), const Size(420, 340));
      grabadora.endRecording().dispose();
      expect(pedidos, {_uid, 'b'});
    });

    testWidgets(
      'el teclado mueve (flechas y WASD) y la barra espaciadora pone cohetes',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final b = _Banco();
        await _montar(tester, tamano: const Size(1000, 800), banco: b);
        await _tomarFotoYEntrar(tester);
        await _avanzar(tester, b, 50);

        final inicio = b.repo.jugadoresActuales[_uid]!;
        final libre = Direccion.values.firstWhere(
          (d) => !MapaArena.esMuro(inicio.x + d.dx, inicio.y + d.dy),
        );
        final flecha = {
          Direccion.arriba: LogicalKeyboardKey.arrowUp,
          Direccion.abajo: LogicalKeyboardKey.arrowDown,
          Direccion.izquierda: LogicalKeyboardKey.arrowLeft,
          Direccion.derecha: LogicalKeyboardKey.arrowRight,
        }[libre]!;
        await tester.sendKeyDownEvent(flecha);
        await _avanzar(tester, b, 200);
        await tester.sendKeyUpEvent(flecha);
        await _avanzar(tester, b, 300);
        final despues = b.repo.jugadoresActuales[_uid]!;
        expect(
          (despues.x, despues.y),
          (inicio.x + libre.dx, inicio.y + libre.dy),
        );

        // WASD: regresar con la tecla opuesta.
        final opuesta = {
          Direccion.arriba: LogicalKeyboardKey.keyS,
          Direccion.abajo: LogicalKeyboardKey.keyW,
          Direccion.izquierda: LogicalKeyboardKey.keyD,
          Direccion.derecha: LogicalKeyboardKey.keyA,
        }[libre]!;
        await tester.sendKeyDownEvent(opuesta);
        await _avanzar(tester, b, 200);
        await tester.sendKeyUpEvent(opuesta);
        await _avanzar(tester, b, 300);
        final regreso = b.repo.jugadoresActuales[_uid]!;
        expect((regreso.x, regreso.y), (inicio.x, inicio.y));

        expect(b.repo.cohetesActuales, isEmpty);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await _avanzar(tester, b, 50);
        final c = b.repo.cohetesActuales.values.single;
        expect((c.x, c.y, c.uid), (inicio.x, inicio.y, _uid));
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets('en pantalla angosta se ven el D-pad y el botón de cohete', (
      tester,
    ) async {
      final b = await _montar(tester);
      await _tomarFotoYEntrar(tester);
      await _avanzar(tester, b, 50);
      expect(find.byKey(const Key('dpad')), findsOneWidget);
      expect(find.byKey(const Key('boton-cohete')), findsOneWidget);
      // El arena sigue cabiendo: sin desbordes.
      expect(tester.takeException(), isNull);

      // El botón de cohete coloca un cohete.
      await tester.tap(find.byKey(const Key('boton-cohete')));
      await _avanzar(tester, b, 50);
      expect(b.repo.cohetesActuales, hasLength(1));

      // Mantener una dirección del D-pad mueve al jugador.
      final inicio = b.repo.jugadoresActuales[_uid]!;
      final libre = Direccion.values.firstWhere(
        (d) =>
            !MapaArena.esMuro(inicio.x + d.dx, inicio.y + d.dy) &&
            !MapaArena.hayCajaInicial(inicio.x + d.dx, inicio.y + d.dy),
      );
      final gesto = await tester.startGesture(
        tester.getCenter(find.byKey(Key('dpad-${libre.name}'))),
      );
      await _avanzar(tester, b, 200);
      await gesto.up();
      await _avanzar(tester, b, 300);
      final despues = b.repo.jugadoresActuales[_uid]!;
      expect(
        (despues.x, despues.y),
        (inicio.x + libre.dx, inicio.y + libre.dy),
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets(
      'en pantalla ancha el D-pad se oculta y se alterna con el botón',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final b = await _montar(tester, tamano: const Size(1000, 800));
        await _tomarFotoYEntrar(tester);
        await _avanzar(tester, b, 50);
        expect(find.byKey(const Key('dpad')), findsNothing);
        await tester.tap(find.byKey(const Key('alternar-controles')));
        await tester.pump();
        expect(find.byKey(const Key('dpad')), findsOneWidget);
        await tester.tap(find.byKey(const Key('alternar-controles')));
        await tester.pump();
        expect(find.byKey(const Key('dpad')), findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets('salir de la pantalla borra al jugador de la arena', (
      tester,
    ) async {
      final b = await _montar(tester);
      await _tomarFotoYEntrar(tester);
      await _avanzar(tester, b, 50);
      expect(b.repo.jugadoresActuales, contains(_uid));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(b.repo.salidas, [_uid]);
      expect(b.repo.jugadoresActuales, isEmpty);
    });

    testWidgets('el botón «Salir» vuelve a la entrada y borra al jugador', (
      tester,
    ) async {
      final b = await _montar(tester);
      await _tomarFotoYEntrar(tester);
      await _avanzar(tester, b, 50);
      await tester.tap(find.byKey(const Key('salir-arena')));
      await tester.pump();
      await tester.pump();
      expect(b.repo.salidas, [_uid]);
      expect(find.text('Entrar a la arena'), findsOneWidget);
      expect(find.byKey(const Key('vista-arena')), findsNothing);
    });

    testWidgets('si no puede entrar muestra el error y permite reintentar', (
      tester,
    ) async {
      final b = _Banco();
      b.repo.fallarEscritura = StateError('sin base de datos');
      await _montar(tester, banco: b);
      await _tomarFotoYEntrar(tester);
      await tester.pump();
      expect(find.byKey(const Key('error-arena')), findsOneWidget);
      await tester.tap(find.byKey(const Key('reintentar-arena')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('error-arena')), findsNothing);
      expect(b.repo.entradas, 1);
      expect(find.byKey(const Key('lienzo-arena')), findsOneWidget);
    });
  });
}

List<int> _base64(String s) => base64Decode(s);
