import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planificacion_posada/core/theme/app_theme.dart';

bool _esGris(Color? c) {
  if (c == null) return false;
  return c.r == c.g && c.g == c.b;
}

void main() {
  final tema = AppTheme.claro;

  test('el fondo de la app es blanco puro', () {
    expect(tema.scaffoldBackgroundColor, Colors.white);
    expect(tema.colorScheme.surface, Colors.white);
    expect(tema.appBarTheme.backgroundColor, Colors.white);
    expect(tema.appBarTheme.surfaceTintColor, Colors.transparent);
    expect(tema.appBarTheme.scrolledUnderElevation, 0);
  });

  test('el NavigationRail usa escala de grises', () {
    final rail = tema.navigationRailTheme;
    expect(_esGris(rail.backgroundColor), isTrue);
    expect(rail.backgroundColor, isNot(Colors.white));
    expect(_esGris(rail.indicatorColor), isTrue);
  });

  test('el NavigationBar usa escala de grises', () {
    final barra = tema.navigationBarTheme;
    expect(_esGris(barra.backgroundColor), isTrue);
    expect(barra.backgroundColor, isNot(Colors.white));
    expect(_esGris(barra.indicatorColor), isTrue);
  });

  test('el color primario conserva el acento festivo', () {
    final p = tema.colorScheme.primary;
    expect(_esGris(p), isFalse);
  });

  testWidgets('un NavigationRail muestra el fondo gris', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.claro,
        home: Scaffold(
          body: NavigationRail(
            selectedIndex: 0,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.home),
                label: Text('A'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.info),
                label: Text('B'),
              ),
            ],
          ),
        ),
      ),
    );
    final rail = t.widget<NavigationRail>(find.byType(NavigationRail));
    final ctx = t.element(find.byType(NavigationRail));
    final fondo =
        rail.backgroundColor ??
        Theme.of(ctx).navigationRailTheme.backgroundColor;
    expect(fondo, AppTheme.grisSidebar);
    final cajas = t.widgetList<Material>(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.byType(Material),
      ),
    );
    expect(cajas.any((m) => m.color == AppTheme.grisSidebar), isTrue);
  });
}
