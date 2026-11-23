import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planificacion_posada/core/theme/app_theme.dart';

double _contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final claro = la > lb ? la : lb;
  final oscuro = la > lb ? lb : la;
  return (claro + 0.05) / (oscuro + 0.05);
}

void main() {
  final tema = AppTheme.noche;

  test('es un tema oscuro Material 3 con fondo transparente para el cielo', () {
    expect(tema.brightness, Brightness.dark);
    expect(tema.useMaterial3, isTrue);
    expect(tema.scaffoldBackgroundColor, Colors.transparent);
    expect(tema.appBarTheme.backgroundColor, Colors.transparent);
  });

  test('los alias antiguos devuelven el mismo tema', () {
    expect(identical(AppTheme.claro, AppTheme.noche), isTrue);
    // ignore: deprecated_member_use_from_same_package
    expect(identical(AppTheme.light, AppTheme.noche), isTrue);
  });

  test('texto sobre cristal cumple contraste AA (>= 4.5)', () {
    final e = tema.colorScheme;
    expect(
      _contraste(e.onSurface, AppTheme.cristalBase),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contraste(e.onSurfaceVariant, AppTheme.cristalBase),
      greaterThanOrEqualTo(4.5),
    );
    // Peor caso: cristal sobre una aurora clara (se mezcla 28 % de blanco).
    final claro = Color.alphaBlend(
      Colors.white.withValues(alpha: 0.28),
      AppTheme.cristalBase,
    );
    expect(_contraste(e.onSurface, claro), greaterThanOrEqualTo(4.5));
    expect(_contraste(e.onPrimary, e.primary), greaterThanOrEqualTo(4.5));
    expect(_contraste(e.onSurface, e.surface), greaterThanOrEqualTo(4.5));
  });

  test('conserva acentos: primario rojo festivo, oro y turquesa', () {
    final e = tema.colorScheme;
    expect(e.primary, AppTheme.rojoFestivo);
    expect(e.tertiary, AppTheme.oro);
    expect(e.secondary, AppTheme.auroraTurquesa);
  });

  test('navegación translúcida con indicador dorado', () {
    expect(tema.navigationRailTheme.backgroundColor, Colors.transparent);
    expect(tema.navigationBarTheme.backgroundColor, Colors.transparent);
    expect(tema.navigationBarTheme.indicatorColor!.a, lessThan(0.5));
    expect(tema.cardTheme.color!.a, lessThan(1));
  });

  test('define transiciones de página propias', () {
    expect(
      tema.pageTransitionsTheme.builders.values.every(
        (b) => b.runtimeType.toString().contains('TransicionNoche'),
      ),
      isTrue,
    );
  });

  testWidgets('MaterialApp aplica el tema y los botones usan el rojo', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.noche,
        home: Scaffold(
          body: Center(
            child: FilledButton(onPressed: () {}, child: const Text('Ir')),
          ),
        ),
      ),
    );
    final ctx = t.element(find.byType(FilledButton));
    expect(Theme.of(ctx).colorScheme.brightness, Brightness.dark);
    final m = t.widget<Material>(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.byType(Material),
      ),
    );
    expect(m.color, AppTheme.rojoFestivo);
  });
}
