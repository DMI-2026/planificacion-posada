import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planificacion_posada/core/efectos/efectos.dart';
import 'package:planificacion_posada/core/theme/app_theme.dart';

Widget _app(Widget hijo, {bool reducido = false}) => MaterialApp(
  theme: AppTheme.noche,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reducido),
    child: child!,
  ),
  home: Scaffold(body: hijo),
);

void main() {
  for (final reducido in [false, true]) {
    final modo = reducido ? 'movimiento reducido' : 'con animación';

    testWidgets('FondoNocheMagica pinta su hijo ($modo)', (t) async {
      await t.pumpWidget(
        _app(
          const FondoNocheMagica(child: Center(child: Text('hola'))),
          reducido: reducido,
        ),
      );
      await t.pump(const Duration(seconds: 2));
      expect(find.text('hola'), findsOneWidget);
      if (reducido) {
        // Sin animaciones continuas: pumpAndSettle termina.
        await t.pumpAndSettle();
        expect(t.hasRunningAnimations, isFalse);
      } else {
        expect(t.hasRunningAnimations, isTrue);
      }
    });

    testWidgets('LucesNavidenas se monta ($modo)', (t) async {
      await t.pumpWidget(_app(const LucesNavidenas(), reducido: reducido));
      await t.pump(const Duration(seconds: 1));
      expect(find.byType(LucesNavidenas), findsOneWidget);
      expect(t.hasRunningAnimations, !reducido);
    });

    testWidgets(
      'TarjetaCristal muestra contenido y responde al toque ($modo)',
      (t) async {
        var toques = 0;
        await t.pumpWidget(
          _app(
            Center(
              child: TarjetaCristal(
                onTap: () => toques++,
                child: const Text('cristal'),
              ),
            ),
            reducido: reducido,
          ),
        );
        expect(find.text('cristal'), findsOneWidget);
        final gesto = await t.createGesture(kind: PointerDeviceKind.mouse);
        await gesto.addPointer(location: Offset.zero);
        await gesto.moveTo(t.getCenter(find.text('cristal')));
        await t.pump(const Duration(milliseconds: 300));
        await t.tap(find.text('cristal'));
        await t.pump(const Duration(milliseconds: 300));
        expect(toques, 1);
        await gesto.removePointer();
      },
    );

    testWidgets('EntradaEscalonada termina visible ($modo)', (t) async {
      await t.pumpWidget(
        _app(
          Column(
            children: EntradaEscalonada.lista([
              for (var i = 0; i < 4; i++) Text('fila $i'),
            ]),
          ),
          reducido: reducido,
        ),
      );
      if (reducido) {
        expect(
          t
              .widget<Opacity>(
                find.ancestor(
                  of: find.text('fila 3'),
                  matching: find.byType(Opacity),
                ),
              )
              .opacity,
          1,
        );
      }
      await t.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        final o = t.widget<Opacity>(
          find
              .ancestor(
                of: find.text('fila $i'),
                matching: find.byType(Opacity),
              )
              .first,
        );
        expect(o.opacity, 1);
      }
    });

    testWidgets('ContadorAnimado llega a su valor final ($modo)', (t) async {
      await t.pumpWidget(_app(ContadorAnimado(valor: 42), reducido: reducido));
      if (reducido) expect(find.text('42'), findsOneWidget);
      await t.pumpAndSettle();
      expect(find.text('42'), findsOneWidget);
      await t.pumpWidget(_app(ContadorAnimado(valor: 57), reducido: reducido));
      await t.pumpAndSettle();
      expect(find.text('57'), findsOneWidget);
    });

    testWidgets('Confeti aparece y desaparece ($modo)', (t) async {
      late BuildContext ctx;
      await t.pumpWidget(
        _app(
          Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
          reducido: reducido,
        ),
      );
      lanzarConfeti(ctx, duracion: const Duration(milliseconds: 800));
      await t.pump();
      await t.pump(const Duration(milliseconds: 200));
      expect(find.byType(Confeti), reducido ? findsNothing : findsOneWidget);
      await t.pump(const Duration(seconds: 1));
      await t.pump();
      expect(find.byType(Confeti), findsNothing);
    });

    testWidgets('BotonBrillante dispara onPressed ($modo)', (t) async {
      var n = 0;
      await t.pumpWidget(
        _app(
          Center(
            child: BotonBrillante(
              onPressed: () => n++,
              etiqueta: 'Confirmar',
              icono: Icons.check,
            ),
          ),
          reducido: reducido,
        ),
      );
      await t.tap(find.text('Confirmar'));
      await t.pump(const Duration(milliseconds: 300));
      expect(n, 1);
    });

    testWidgets('TituloMagico muestra el texto ($modo)', (t) async {
      await t.pumpWidget(
        _app(const TituloMagico('Posada'), reducido: reducido),
      );
      await t.pump(const Duration(seconds: 1));
      expect(find.text('Posada'), findsOneWidget);
    });
  }

  testWidgets('BotonBrillante deshabilitado no responde', (t) async {
    await t.pumpWidget(
      _app(
        const Center(child: BotonBrillante(onPressed: null, etiqueta: 'No')),
      ),
    );
    await t.pump(const Duration(seconds: 1));
    expect(find.text('No'), findsOneWidget);
    expect(t.hasRunningAnimations, isFalse);
  });
}
