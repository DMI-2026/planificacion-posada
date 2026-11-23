import 'package:flutter/material.dart';

/// Tema festivo de la posada: fondo blanco, navegación en escala de grises y
/// acentos rojo profundo / verde (Material 3).
class AppTheme {
  AppTheme._();

  /// Fondo general de la app.
  static const Color fondoBlanco = Colors.white;

  /// Fondo del sidebar (NavigationRail) y de la barra de navegación.
  static const Color grisSidebar = Color(0xFFF5F5F5);

  /// Fondo muy claro para tarjetas y contenedores sobre blanco.
  static const Color grisSuperficie = Color(0xFFF7F7F7);

  /// Divisores y bordes finos.
  static const Color grisBorde = Color(0xFFE0E0E0);

  /// Indicador del destino seleccionado.
  static const Color grisIndicador = Color(0xFFD6D6D6);

  /// Texto e icono seleccionados (contraste alto sobre [grisSidebar]).
  static const Color grisSeleccionado = Color(0xFF212121);

  /// Texto e icono no seleccionados (>= 4.5:1 sobre [grisSidebar]).
  static const Color grisNoSeleccionado = Color(0xFF616161);

  static ThemeData get claro {
    final base = ColorScheme.fromSeed(
      seedColor: const Color(0xFFB71C1C),
      secondary: const Color(0xFF2E7D32),
      brightness: Brightness.light,
    );
    final esquema = base.copyWith(
      surface: fondoBlanco,
      surfaceTint: Colors.transparent,
      surfaceContainerLowest: fondoBlanco,
      surfaceContainerLow: grisSuperficie,
      surfaceContainer: grisSuperficie,
      surfaceContainerHigh: grisSidebar,
      surfaceContainerHighest: grisBorde,
      outlineVariant: grisBorde,
    );
    const estiloSeleccionado =
        TextStyle(color: grisSeleccionado, fontWeight: FontWeight.w600);
    const estiloNoSeleccionado = TextStyle(color: grisNoSeleccionado);
    return ThemeData(
      useMaterial3: true,
      colorScheme: esquema,
      scaffoldBackgroundColor: fondoBlanco,
      canvasColor: fondoBlanco,
      dividerTheme: const DividerThemeData(color: grisBorde, thickness: 1),
      appBarTheme: const AppBarTheme(
        backgroundColor: fondoBlanco,
        foregroundColor: grisSeleccionado,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: grisBorde)),
      ),
      cardTheme: const CardThemeData(
        margin: EdgeInsets.symmetric(vertical: 4),
        color: grisSuperficie,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: grisBorde),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: grisSidebar,
        indicatorColor: grisIndicador,
        selectedIconTheme: IconThemeData(color: grisSeleccionado),
        unselectedIconTheme: IconThemeData(color: grisNoSeleccionado),
        selectedLabelTextStyle: estiloSeleccionado,
        unselectedLabelTextStyle: estiloNoSeleccionado,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: grisSidebar,
        surfaceTintColor: Colors.transparent,
        indicatorColor: grisIndicador,
        iconTheme: WidgetStateProperty.resolveWith((estados) => IconThemeData(
              color: estados.contains(WidgetState.selected)
                  ? grisSeleccionado
                  : grisNoSeleccionado,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((estados) =>
            estados.contains(WidgetState.selected)
                ? estiloSeleccionado
                : estiloNoSeleccionado),
      ),
    );
  }
}
