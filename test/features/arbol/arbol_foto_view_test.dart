import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:planificacion_posada/core/theme/app_theme.dart';
import 'package:planificacion_posada/features/arbol/models/adorno.dart';
import 'package:planificacion_posada/features/arbol/repositories/fake_arbol_repository.dart';
import 'package:planificacion_posada/features/arbol/services/captura_foto.dart';
import 'package:planificacion_posada/features/arbol/viewmodels/arbol_view_model.dart';
import 'package:planificacion_posada/features/arbol/views/arbol_view.dart';
import 'package:planificacion_posada/features/arbol/views/dibujos_adorno.dart';
import 'package:planificacion_posada/features/arbol/views/fotos_esfera.dart';

/// Foto de 200x100 de un solo color.
Uint8List _bytes(int r, int g, int b) {
  final im = img.Image(width: 200, height: 100);
  for (final p in im) {
    p.setRgb(r, g, b);
  }
  return img.encodePng(im);
}

class _CapturaFalsa implements CapturaFoto {
  _CapturaFalsa({this.errorAlIniciar, Uint8List? bytes})
    : bytes = bytes ?? _bytes(0, 255, 0);

  final CapturaFotoException? errorAlIniciar;
  final Uint8List bytes;
  int tomadas = 0;
  bool liberada = false;

  @override
  Future<void> iniciar() async {
    if (errorAlIniciar != null) throw errorAlIniciar!;
  }

  @override
  Widget vista(BuildContext context) =>
      const ColoredBox(key: Key('camara-viva'), color: Colors.black);

  @override
  Future<Uint8List> tomar() async {
    tomadas++;
    return bytes;
  }

  @override
  Future<void> liberar() async => liberada = true;
}

Adorno _esfera(String uid, int slot, {String color = '#D62839'}) => Adorno(
  id: Adorno.idDe(uid, slot),
  tipo: TipoAdorno.esfera,
  autorId: uid,
  color: color,
  patron: PatronEsfera.rayas,
  x: 0.5,
  y: 0.55,
);

Adorno _conFoto(String uid, int slot, String foto) => Adorno(
  id: Adorno.idDe(uid, slot),
  tipo: TipoAdorno.esfera,
  autorId: uid,
  color: '#D62839',
  patron: PatronEsfera.foto,
  foto: foto,
  x: 0.5,
  y: 0.55,
);

Future<ArbolViewModel> _montar(
  WidgetTester tester,
  FakeArbolRepository repo,
  CapturaFoto Function() crearCaptura,
) async {
  tester.view.physicalSize = const Size(500, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  final vm = ArbolViewModel(
    repo,
    uid: 'u1',
    esAdmin: false,
    esParticipante: true,
    nombres: const {'u1': 'Ana'},
  );
  addTearDown(vm.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.noche,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: ArbolView(viewModel: vm, crearCaptura: crearCaptura),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return vm;
}

/// Canal 0..1 a 0..255.
double _v(double canal) => canal * 255;

bool _elegido(WidgetTester tester, String patron) =>
    tester.widget<ChoiceChip>(find.byKey(Key('patron-$patron'))).selected;

DibujoEsfera _vistaPrevia(WidgetTester tester) => tester.widget<DibujoEsfera>(
  find.descendant(
    of: find.byKey(const Key('vista-previa')),
    matching: find.byType(DibujoEsfera),
  ),
);

Future<void> _abrirTaller(WidgetTester tester) async {
  await tester.tap(find.text('Crear adorno'));
  await tester.pumpAndSettle();
}

/// Renderiza [hijo] (200x200) y devuelve el color del píxel en ([x], [y]).
Future<Color> _pixel(
  WidgetTester tester,
  Widget hijo,
  int x,
  int y, {
  bool esperarFoto = true,
}) async {
  final llave = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: llave,
          child: SizedBox(width: 200, height: 200, child: hijo),
        ),
      ),
    ),
  );
  if (esperarFoto) {
    // La decodificación de la foto es asíncrona real.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
  }
  final color = await tester.runAsync(() async {
    final limite =
        llave.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final imagen = await limite.toImage();
    final datos = (await imagen.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!;
    final i = (y * imagen.width + x) * 4;
    return Color.fromARGB(
      datos.getUint8(i + 3),
      datos.getUint8(i),
      datos.getUint8(i + 1),
      datos.getUint8(i + 2),
    );
  });
  return color!;
}

void main() {
  setUp(FotosEsfera.vaciar);

  group('taller: patrón foto', () {
    testWidgets('elegir Foto, tomar y aceptar muestra la foto y se guarda', (
      tester,
    ) async {
      final falsa = _CapturaFalsa();
      final repo = FakeArbolRepository();
      final vm = await _montar(tester, repo, () => falsa);
      await _abrirTaller(tester);
      expect(find.text('Foto'), findsOneWidget);

      await tester.tap(find.byKey(const Key('patron-foto')));
      await tester.pumpAndSettle();
      expect(find.text('Foto para la esfera'), findsOneWidget);
      expect(find.byKey(const Key('camara-viva')), findsOneWidget);
      expect(find.byKey(const Key('tomar-foto')), findsOneWidget);

      await tester.tap(find.byKey(const Key('tomar-foto')));
      await tester.pumpAndSettle();
      expect(falsa.tomadas, 1);
      expect(find.byKey(const Key('foto-capturada')), findsOneWidget);
      expect(find.byKey(const Key('repetir-foto')), findsOneWidget);

      await tester.tap(find.byKey(const Key('aceptar-foto')));
      await tester.pumpAndSettle();
      expect(falsa.liberada, isTrue);
      expect(find.text('Foto para la esfera'), findsNothing);
      expect(_elegido(tester, 'foto'), isTrue);
      final esperada = procesarFoto(falsa.bytes);
      final previa = _vistaPrevia(tester);
      expect(previa.patron, PatronEsfera.foto);
      expect(previa.foto, esperada);

      await tester.tap(find.text('Colgar en el árbol'));
      await tester.pumpAndSettle();
      final a = vm.adornos.single;
      expect(a.patron, PatronEsfera.foto);
      expect(a.foto, esperada);
      expect(a.toMap()['foto'], esperada);
      expect(find.byKey(Key('adorno-${a.id}')), findsOneWidget);
    });

    testWidgets('Repetir vuelve a la cámara y permite otra toma', (
      tester,
    ) async {
      final falsa = _CapturaFalsa();
      await _montar(tester, FakeArbolRepository(), () => falsa);
      await _abrirTaller(tester);
      await tester.tap(find.byKey(const Key('patron-foto')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tomar-foto')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('repetir-foto')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('camara-viva')), findsOneWidget);
      expect(find.byKey(const Key('foto-capturada')), findsNothing);
      await tester.tap(find.byKey(const Key('tomar-foto')));
      await tester.pumpAndSettle();
      expect(falsa.tomadas, 2);
    });

    testWidgets('cancelar la cámara conserva el patrón anterior', (
      tester,
    ) async {
      final falsa = _CapturaFalsa();
      final repo = FakeArbolRepository();
      final vm = await _montar(tester, repo, () => falsa);
      await _abrirTaller(tester);
      await tester.tap(find.byKey(const Key('patron-estrellas')));
      await tester.tap(find.byKey(const Key('patron-foto')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cancelar-foto')));
      await tester.pumpAndSettle();
      expect(_elegido(tester, 'foto'), isFalse);
      expect(_elegido(tester, 'estrellas'), isTrue);
      expect(falsa.liberada, isTrue);
      await tester.tap(find.text('Colgar en el árbol'));
      await tester.pumpAndSettle();
      expect(vm.adornos.single.patron, PatronEsfera.estrellas);
      expect(vm.adornos.single.foto, isNull);
    });

    testWidgets('cámara denegada: mensaje claro y vuelve al patrón anterior', (
      tester,
    ) async {
      final falsa = _CapturaFalsa(
        errorAlIniciar: const CapturaFotoException(
          'No tenemos permiso para usar la cámara. Actívalo en tu '
          'navegador o en los ajustes y vuelve a intentarlo.',
        ),
      );
      final repo = FakeArbolRepository();
      final vm = await _montar(tester, repo, () => falsa);
      await _abrirTaller(tester);
      await tester.tap(find.byKey(const Key('patron-puntos')));
      await tester.tap(find.byKey(const Key('patron-foto')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'No tenemos permiso para usar la cámara. Actívalo en tu '
          'navegador o en los ajustes y vuelve a intentarlo.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('tomar-foto')), findsNothing);
      await tester.tap(find.byKey(const Key('cerrar-camara')));
      await tester.pumpAndSettle();
      expect(_elegido(tester, 'foto'), isFalse);
      expect(_elegido(tester, 'puntos'), isTrue);

      await tester.tap(find.text('Colgar en el árbol'));
      await tester.pumpAndSettle();
      expect(vm.adornos.single.patron, PatronEsfera.puntos);
      expect(vm.adornos.single.foto, isNull);
    });

    testWidgets('sin cámara: mensaje claro', (tester) async {
      final falsa = _CapturaFalsa(
        errorAlIniciar: const CapturaFotoException(
          'No encontramos una cámara en este dispositivo.',
        ),
      );
      await _montar(tester, FakeArbolRepository(), () => falsa);
      await _abrirTaller(tester);
      await tester.tap(find.byKey(const Key('patron-foto')));
      await tester.pumpAndSettle();
      expect(
        find.text('No encontramos una cámara en este dispositivo.'),
        findsOneWidget,
      );
    });

    testWidgets('editar una esfera con foto la conserva sin abrir la cámara', (
      tester,
    ) async {
      final foto = procesarFoto(_bytes(0, 0, 255));
      var camaras = 0;
      final repo = FakeArbolRepository(inicial: [_conFoto('u1', 0, foto)]);
      final vm = await _montar(tester, repo, () {
        camaras++;
        return _CapturaFalsa();
      });
      await tester.tap(find.byKey(const Key('adorno-u1_0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('editar-adorno')));
      await tester.pumpAndSettle();
      expect(_elegido(tester, 'foto'), isTrue);
      expect(_vistaPrevia(tester).foto, foto);
      await tester.tap(find.byKey(const Key('color-#FF4FD8')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(camaras, 0);
      expect(vm.adornos.single.color, '#FF4FD8');
      expect(vm.adornos.single.patron, PatronEsfera.foto);
      expect(vm.adornos.single.foto, foto);
    });

    testWidgets('editar: «Tomar otra foto» reemplaza la foto', (tester) async {
      final vieja = procesarFoto(_bytes(0, 0, 255));
      final falsa = _CapturaFalsa(bytes: _bytes(255, 0, 0));
      final repo = FakeArbolRepository(inicial: [_conFoto('u1', 0, vieja)]);
      final vm = await _montar(tester, repo, () => falsa);
      await tester.tap(find.byKey(const Key('adorno-u1_0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('editar-adorno')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('retomar-foto')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tomar-foto')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('aceptar-foto')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(vm.adornos.single.foto, procesarFoto(falsa.bytes));
      expect(vm.adornos.single.foto, isNot(vieja));
    });

    testWidgets('editar: cambiar a otro patrón quita la foto', (tester) async {
      final foto = procesarFoto(_bytes(0, 0, 255));
      final repo = FakeArbolRepository(inicial: [_conFoto('u1', 0, foto)]);
      final vm = await _montar(tester, repo, () => _CapturaFalsa());
      await tester.tap(find.byKey(const Key('adorno-u1_0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('editar-adorno')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('patron-rayas')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(vm.adornos.single.patron, PatronEsfera.rayas);
      expect(vm.adornos.single.foto, isNull);
    });

    testWidgets('los demás patrones siguen funcionando sin cámara', (
      tester,
    ) async {
      var camaras = 0;
      final vm = await _montar(tester, FakeArbolRepository(), () {
        camaras++;
        return _CapturaFalsa();
      });
      await _abrirTaller(tester);
      await tester.tap(find.byKey(const Key('patron-puntos')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Colgar en el árbol'));
      await tester.pumpAndSettle();
      expect(camaras, 0);
      expect(vm.adornos.single.patron, PatronEsfera.puntos);
    });
  });

  group('dibujo de la esfera con foto', () {
    testWidgets('la foto llena la esfera y el aro lleva el color elegido', (
      tester,
    ) async {
      final foto = procesarFoto(_bytes(0, 255, 0));
      // Centro de la esfera: (100, 116) en 200x200; radio 80.
      final centro = await _pixel(
        tester,
        DibujoEsfera(
          color: '#D62839',
          patron: PatronEsfera.foto,
          foto: foto,
          tamano: 200,
        ),
        100,
        116,
      );
      expect(
        _v(centro.g),
        greaterThan(_v(centro.r) + 60),
        reason: 'verde de la foto',
      );
      // En el aro (radio 0.9 * 80 = 72 por debajo del centro) manda el color.
      FotosEsfera.vaciar();
      final aro = await _pixel(
        tester,
        DibujoEsfera(
          color: '#D62839',
          patron: PatronEsfera.foto,
          foto: foto,
          tamano: 200,
        ),
        100,
        116 + 74,
      );
      expect(_v(aro.r), greaterThan(_v(aro.g) + 40), reason: 'aro rojo');
    });

    testWidgets('base64 inválido no falla y dibuja la esfera lisa', (
      tester,
    ) async {
      final c = await _pixel(
        tester,
        const DibujoEsfera(
          color: '#D62839',
          patron: PatronEsfera.foto,
          foto: 'esto no es base64 ni imagen!!',
          tamano: 200,
        ),
        100,
        125,
      );
      expect(tester.takeException(), isNull);
      expect(_v(c.r), greaterThan(_v(c.g) + 40));
      expect(_v(c.r), greaterThan(_v(c.b) + 40));
    });

    testWidgets('base64 válido pero que no es imagen tampoco falla', (
      tester,
    ) async {
      final c = await _pixel(
        tester,
        const DibujoEsfera(
          color: '#D62839',
          patron: PatronEsfera.foto,
          foto: 'AAECAwQF',
          tamano: 200,
        ),
        100,
        125,
      );
      expect(tester.takeException(), isNull);
      expect(_v(c.r), greaterThan(_v(c.g) + 40));
    });

    testWidgets('la foto se decodifica una sola vez y se comparte', (
      tester,
    ) async {
      final foto = procesarFoto(_bytes(0, 255, 0));
      await _pixel(
        tester,
        DibujoEsfera(color: '#D62839', patron: PatronEsfera.foto, foto: foto),
        10,
        10,
      );
      expect(FotosEsfera.intentada(foto), isTrue);
      final primera = FotosEsfera.lista(foto);
      expect(primera, isNotNull);
      expect(await FotosEsfera.cargar(foto), same(primera));
    });

    testWidgets('el árbol dibuja una esfera con foto como cualquier adorno', (
      tester,
    ) async {
      final foto = procesarFoto(_bytes(0, 255, 0));
      await _montar(
        tester,
        FakeArbolRepository(
          inicial: [_conFoto('u2', 0, foto), _esfera('u1', 0)],
        ),
        () => _CapturaFalsa(),
      );
      expect(find.byKey(const Key('adorno-u2_0')), findsOneWidget);
      final dibujo = tester.widget<DibujoEsfera>(
        find.descendant(
          of: find.byKey(const Key('adorno-u2_0')),
          matching: find.byType(DibujoEsfera),
        ),
      );
      expect(dibujo.foto, foto);
      expect(find.text('Mis adornos 1/10'), findsOneWidget);
    });
  });
}
