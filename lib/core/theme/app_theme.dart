import 'package:flutter/material.dart';

import 'transicion_noche.dart';

/// Tema «noche mágica navideña» (Material 3, oscuro).
///
/// Paleta: azules medianoche e índigo de base, auroras magenta y turquesa,
/// dorado cálido para luces y estrellas, y rojo festivo para acciones
/// principales. Sin dependencias de fuentes: los títulos usan una familia con
/// serifa (Georgia/Palatino/Cambria según plataforma) y el cuerpo la fuente
/// sans del sistema.
class AppTheme {
  AppTheme._();

  // Paleta base.
  static const Color medianoche = Color(0xFF070B1F);
  static const Color indigo = Color(0xFF141C4A);
  static const Color indigoClaro = Color(0xFF232C6B);
  static const Color auroraMagenta = Color(0xFFFF4FD8);
  static const Color auroraTurquesa = Color(0xFF2EE6C8);
  static const Color oro = Color(0xFFFFC857);
  static const Color rojoFestivo = Color(0xFFD62839);
  static const Color texto = Color(0xFFF4F0FF);
  static const Color textoSuave = Color(0xFFBDBEE6);

  /// Base opaca del cristal (tarjetas, barras): contraste AA con [texto].
  static const Color cristalBase = Color(0xFF141C4A);

  /// Cristal translúcido para superficies (Card, diálogos, barras).
  static Color get cristal => cristalBase.withValues(alpha: 0.72);

  static const String fuenteTitulos = 'Georgia';
  static const List<String> fuenteTitulosAlternas = [
    'Palatino',
    'Palatino Linotype',
    'Cambria',
    'Times New Roman',
    'serif',
  ];

  /// Tema oscuro principal.
  static ThemeData get noche => _noche;

  /// Alias de compatibilidad con el nombre anterior del tema.
  static ThemeData get claro => _noche;

  /// Alias de compatibilidad: el tema ya no es claro.
  @Deprecated('Usa AppTheme.noche')
  static ThemeData get light => _noche;

  static final ThemeData _noche = _construir();

  static ThemeData _construir() {
    const esquema = ColorScheme(
      brightness: Brightness.dark,
      primary: rojoFestivo,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF5B1230),
      onPrimaryContainer: Color(0xFFFFD9DD),
      secondary: auroraTurquesa,
      onSecondary: Color(0xFF03141A),
      secondaryContainer: Color(0xFF0E4A55),
      onSecondaryContainer: Color(0xFFB8FFF1),
      tertiary: oro,
      onTertiary: Color(0xFF241800),
      tertiaryContainer: Color(0xFF5A4100),
      onTertiaryContainer: Color(0xFFFFE9B8),
      error: Color(0xFFFF8A94),
      onError: Color(0xFF3A0008),
      surface: Color(0xFF0B1030),
      onSurface: texto,
      onSurfaceVariant: textoSuave,
      surfaceTint: Colors.transparent,
      surfaceContainerLowest: medianoche,
      surfaceContainerLow: Color(0xFF0F1540),
      surfaceContainer: indigo,
      surfaceContainerHigh: Color(0xFF1B2459),
      surfaceContainerHighest: indigoClaro,
      outline: Color(0xFF6F76B8),
      outlineVariant: Color(0xFF2C3570),
      inverseSurface: texto,
      onInverseSurface: Color(0xFF0B1030),
      inversePrimary: Color(0xFF9B1220),
      shadow: Colors.black,
      scrim: Colors.black,
    );

    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    TextStyle titulo(TextStyle? s, FontWeight peso) =>
        (s ?? const TextStyle()).copyWith(
          fontFamily: fuenteTitulos,
          fontFamilyFallback: fuenteTitulosAlternas,
          fontWeight: peso,
          letterSpacing: 0.2,
        );
    final t = base.textTheme.apply(bodyColor: texto, displayColor: texto);
    final textos = t.copyWith(
      displayLarge: titulo(t.displayLarge, FontWeight.w700),
      displayMedium: titulo(t.displayMedium, FontWeight.w700),
      displaySmall: titulo(t.displaySmall, FontWeight.w700),
      headlineLarge: titulo(t.headlineLarge, FontWeight.w700),
      headlineMedium: titulo(t.headlineMedium, FontWeight.w700),
      headlineSmall: titulo(t.headlineSmall, FontWeight.w700),
      titleLarge: titulo(t.titleLarge, FontWeight.w700),
      titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyMedium: t.bodyMedium?.copyWith(height: 1.4),
      bodyLarge: t.bodyLarge?.copyWith(height: 1.45),
    );

    const formaCristal = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(24)),
      side: BorderSide(color: Color(0x33FFFFFF)),
    );
    const brilloOro = [Shadow(color: oro, blurRadius: 14)];
    final contorno = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0x40FFFFFF)),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: esquema,
      textTheme: textos,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: const Color(0xFF0B1030),
      splashFactory: InkSparkle.splashFactory,
      dividerTheme: const DividerThemeData(
        color: Color(0x26FFFFFF),
        thickness: 1,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: TransicionNochePageTransitionsBuilder(),
          TargetPlatform.iOS: TransicionNochePageTransitionsBuilder(),
          TargetPlatform.macOS: TransicionNochePageTransitionsBuilder(),
          TargetPlatform.windows: TransicionNochePageTransitionsBuilder(),
          TargetPlatform.linux: TransicionNochePageTransitionsBuilder(),
          TargetPlatform.fuchsia: TransicionNochePageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: texto,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textos.titleLarge?.copyWith(color: oro),
      ),
      cardTheme: CardThemeData(
        margin: const EdgeInsets.symmetric(vertical: 6),
        color: cristal,
        surfaceTintColor: Colors.transparent,
        shadowColor: auroraMagenta,
        elevation: 0,
        shape: formaCristal,
      ),
      filledButtonTheme: FilledButtonThemeData(style: _botonBrillo()),
      elevatedButtonTheme: ElevatedButtonThemeData(style: _botonBrillo()),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: oro,
          minimumSize: const Size(64, 48),
          shape: const StadiumBorder(),
          side: BorderSide(color: oro.withValues(alpha: 0.6)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: auroraTurquesa,
          minimumSize: const Size(48, 44),
          shape: const StadiumBorder(),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: texto),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: const Color(0x1AFFFFFF),
        labelStyle: const TextStyle(color: textoSuave),
        hintStyle: const TextStyle(color: Color(0xFF9EA1D0)),
        border: contorno,
        enabledBorder: contorno,
        focusedBorder: contorno.copyWith(
          borderSide: const BorderSide(color: oro, width: 2),
        ),
        errorBorder: contorno.copyWith(
          borderSide: const BorderSide(color: Color(0xFFFF8A94)),
        ),
        focusedErrorBorder: contorno.copyWith(
          borderSide: const BorderSide(color: Color(0xFFFF8A94), width: 2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xF2141C4A),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: formaCristal,
        titleTextStyle: textos.headlineSmall?.copyWith(color: oro),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xF2141C4A),
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: Color(0xF2141C4A),
        showDragHandle: true,
        dragHandleColor: Color(0x80FFFFFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          side: BorderSide(color: Color(0x33FFFFFF)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0x1FFFFFFF),
        selectedColor: oro.withValues(alpha: 0.28),
        side: const BorderSide(color: Color(0x40FFFFFF)),
        shape: const StadiumBorder(),
        labelStyle: const TextStyle(color: texto),
        checkmarkColor: oro,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (e) => e.contains(WidgetState.selected)
                ? oro.withValues(alpha: 0.28)
                : const Color(0x14FFFFFF),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (e) => e.contains(WidgetState.selected) ? oro : texto,
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: Color(0x40FFFFFF)),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: rojoFestivo,
        foregroundColor: Colors.white,
        elevation: 10,
        highlightElevation: 14,
        shape: const StadiumBorder(side: BorderSide(color: Color(0x66FFC857))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xF21B2459),
        contentTextStyle: const TextStyle(color: texto, fontSize: 14),
        actionTextColor: oro,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0x33FFFFFF)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: oro,
        linearTrackColor: Color(0x33FFFFFF),
        circularTrackColor: Color(0x1FFFFFFF),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: textoSuave,
        textColor: texto,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (e) => e.contains(WidgetState.selected) ? oro : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(Color(0xFF241800)),
        side: const BorderSide(color: textoSuave, width: 1.6),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (e) => e.contains(WidgetState.selected) ? oro : textoSuave,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (e) => e.contains(WidgetState.selected)
              ? oro.withValues(alpha: 0.35)
              : const Color(0x33FFFFFF),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: oro.withValues(alpha: 0.22),
        indicatorShape: const StadiumBorder(),
        selectedIconTheme: const IconThemeData(color: oro, shadows: brilloOro),
        unselectedIconTheme: const IconThemeData(color: textoSuave),
        selectedLabelTextStyle: const TextStyle(
          color: oro,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: const TextStyle(color: textoSuave),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: oro.withValues(alpha: 0.22),
        indicatorShape: const StadiumBorder(),
        iconTheme: WidgetStateProperty.resolveWith(
          (e) => e.contains(WidgetState.selected)
              ? const IconThemeData(color: oro, shadows: brilloOro)
              : const IconThemeData(color: textoSuave),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (e) => e.contains(WidgetState.selected)
              ? const TextStyle(
                  color: oro,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                )
              : const TextStyle(color: textoSuave, fontSize: 12),
        ),
      ),
    );
  }

  static ButtonStyle _botonBrillo() => ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
    shape: const WidgetStatePropertyAll(StadiumBorder()),
    backgroundColor: WidgetStateProperty.resolveWith(
      (e) => e.contains(WidgetState.disabled)
          ? const Color(0xFF3A3F66)
          : rojoFestivo,
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (e) => e.contains(WidgetState.disabled)
          ? const Color(0xFFC9CBE8)
          : Colors.white,
    ),
    shadowColor: const WidgetStatePropertyAll(Color(0xFFFF4D5E)),
    elevation: WidgetStateProperty.resolveWith(
      (e) => e.contains(WidgetState.disabled)
          ? 0
          : e.contains(WidgetState.pressed)
          ? 2
          : e.contains(WidgetState.hovered)
          ? 12
          : 6,
    ),
  );
}
