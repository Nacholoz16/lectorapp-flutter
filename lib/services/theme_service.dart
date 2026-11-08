import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/lector_colors.dart';

/// Temas de LectorApp. Cada tema se construye a partir de una paleta de tokens
/// ([LectorColors]); ver la skill `lectorapp-design-system` para los contrastes medidos.
///
/// - `primaryColor` y `colorScheme.primary` = **ink** (tono legible), no el pastel: así todo
///   el código que pinta texto o íconos con `primaryColor` cumple contraste AA.
/// - El pastel queda disponible como `context.lector.accent` / `colorScheme.secondary`.
class ThemeService {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  final ValueNotifier<ThemeData> currentTheme =
      ValueNotifier<ThemeData>(_salviaTheme);

  // --- TOKENS COMPARTIDOS ---

  /// Radio de tarjetas, hojas y diálogos.
  static const double radiusCard = 20;

  /// Radio de elementos pequeños (chips, portadas, inputs compactos, snackbars).
  static const double radiusSmall = 12;

  /// Estilo elegante para títulos (Lora).
  static TextStyle get titleStyle =>
      GoogleFonts.lora(fontWeight: FontWeight.bold);

  // --- LAS 4 PALETAS ---
  //
  // Expuestas en [palettes] para poder verificar contrastes en tests sin construir ThemeData
  // (que carga fuentes de Google Fonts).

  // Los neutros claros comparten valores entre Salvia, Rosa y Brisa.
  static const _lightText = Color(0xFF3D4042); // 10.1:1 sobre crema
  static const _lightTextSecondary = Color(0xFF6B6F72); // ≥ 4.8:1 sobre los 3 fondos claros
  static const _lightIconInactive = Color(0xFF8F9497); // 3.1:1 (íconos/controles)
  static const _lightOutline = Color(0xFFE3E1DC);
  static const _lightSuccess = Color(0xFF2F7D3F); // 4.9:1
  static const _lightDanger = Color(0xFFB33B4E); // 5.6:1
  static const _lightStar = Color(0xFFBF8A00); // 3.1:1 sobre tarjeta blanca

  // 1. "Crema & Salvia" (por defecto)
  static const ThemePalette _lightPalette = ThemePalette(
    brightness: Brightness.light,
    background: Color(0xFFFDFBF7),
    card: Colors.white,
    colors: LectorColors(
      accent: Color(0xFF8BA89F),
      ink: Color(0xFF4F7A70), // blanco encima 4.8:1
      onInk: Colors.white,
      textPrimary: _lightText,
      textSecondary: _lightTextSecondary,
      iconInactive: _lightIconInactive,
      outline: _lightOutline,
      success: _lightSuccess,
      danger: _lightDanger,
      reading: Color(0xFF4F7A70),
      star: _lightStar,
    ),
  );
  static final ThemeData _salviaTheme = _buildTheme(_lightPalette);

  // 2. "Rosa Peonía"
  static const ThemePalette _pinkPalette = ThemePalette(
    brightness: Brightness.light,
    background: Color(0xFFFEF9FA),
    card: Colors.white,
    colors: LectorColors(
      accent: Color(0xFFD8A7B1),
      ink: Color(0xFFB5536A), // blanco encima 4.8:1
      onInk: Colors.white,
      textPrimary: _lightText,
      textSecondary: _lightTextSecondary,
      iconInactive: _lightIconInactive,
      outline: Color(0xFFEDE1E3),
      success: _lightSuccess,
      danger: _lightDanger,
      reading: Color(0xFFB5536A),
      star: _lightStar,
    ),
  );
  static final ThemeData _pinkTheme = _buildTheme(_pinkPalette);

  // 3. "Brisa de Mar"
  static const ThemePalette _bluePalette = ThemePalette(
    brightness: Brightness.light,
    background: Color(0xFFF7FBFD),
    card: Colors.white,
    colors: LectorColors(
      accent: Color(0xFFA1C4D0),
      ink: Color(0xFF3F7186), // blanco encima 5.4:1
      onInk: Colors.white,
      textPrimary: _lightText,
      textSecondary: _lightTextSecondary,
      iconInactive: _lightIconInactive,
      outline: Color(0xFFDCE7EB),
      success: _lightSuccess,
      danger: _lightDanger,
      reading: Color(0xFF3F7186),
      star: _lightStar,
    ),
  );
  static final ThemeData _blueTheme = _buildTheme(_bluePalette);

  // 4. "Café de Medianoche" (oscuro)
  static const ThemePalette _darkPalette = ThemePalette(
    brightness: Brightness.dark,
    background: Color(0xFF1C1917),
    card: Color(0xFF292524),
    colors: LectorColors(
      accent: Color(0xFFB59E86),
      ink: Color(0xFFB59E86), // 5.9:1 sobre tarjeta; texto oscuro encima 6.8:1
      onInk: Color(0xFF1C1917),
      textPrimary: Color(0xFFE7E5E4),
      textSecondary: Color(0xFFA8A29E), // 6.0:1 sobre tarjeta
      iconInactive: Color(0xFF9A9590),
      outline: Color(0xFF44403C),
      success: Color(0xFF81C784), // 7.5:1
      danger: Color(0xFFEF9A9A), // 7.0:1
      reading: Color(0xFFB59E86),
      star: Color(0xFFFFD54F),
    ),
  );
  static final ThemeData _darkTheme = _buildTheme(_darkPalette);

  /// Paletas por nombre de tema ('light', 'pink', 'blue', 'dark').
  static const Map<String, ThemePalette> palettes = {
    'light': _lightPalette,
    'pink': _pinkPalette,
    'blue': _bluePalette,
    'dark': _darkPalette,
  };

  static ThemeData _buildTheme(ThemePalette palette) {
    final brightness = palette.brightness;
    final background = palette.background;
    final card = palette.card;
    final colors = palette.colors;
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: colors.ink,
      brightness: brightness,
    ).copyWith(
      primary: colors.ink,
      onPrimary: colors.onInk,
      primaryContainer: colors.accent.withValues(alpha: 0.25),
      onPrimaryContainer: colors.textPrimary,
      secondary: colors.accent,
      onSecondary: isDark ? colors.onInk : colors.textPrimary,
      error: colors.danger,
      onError: isDark ? const Color(0xFF1C1917) : Colors.white,
      surface: card,
      onSurface: colors.textPrimary,
      onSurfaceVariant: colors.textSecondary,
      // Superficies de diálogos, hojas y menús: el color de tarjeta del tema, sin el tinte
      // automático de Material 3 (que dejaba tonos violáceos o verdosos ajenos a la paleta).
      surfaceContainerLowest: card,
      surfaceContainerLow: card,
      surfaceContainer: card,
      surfaceContainerHigh: card,
      surfaceContainerHighest: isDark ? const Color(0xFF34302C) : background,
      surfaceTint: Colors.transparent,
      outline: colors.iconInactive,
      outlineVariant: colors.outline,
      inverseSurface: colors.textPrimary,
      onInverseSurface: background,
      inversePrimary: colors.accent,
    );

    final textTheme = GoogleFonts.nunitoTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    ).apply(bodyColor: colors.textPrimary, displayColor: colors.textPrimary);

    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusCard),
    );
    OutlineInputBorder inputBorder([BorderSide side = BorderSide.none]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          borderSide: side,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: [colors],
      primaryColor: colors.ink,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      cardColor: card,
      dividerColor: colors.outline,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: colors.textSecondary),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.ink,
        selectionColor: colors.accent.withValues(alpha: 0.4),
        selectionHandleColor: colors.ink,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: colors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.lora(
          color: colors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.ink,
        foregroundColor: colors.onInk,
        elevation: 4,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? background : card,
        selectedItemColor: colors.ink,
        unselectedItemColor: colors.iconInactive,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        shape: rounded,
        elevation: 0,
        color: card,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(color: colors.outline, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        hintStyle: TextStyle(color: colors.textSecondary),
        labelStyle: TextStyle(color: colors.textSecondary),
        floatingLabelStyle: TextStyle(color: colors.ink),
        prefixIconColor: colors.textSecondary,
        suffixIconColor: colors.textSecondary,
        border: inputBorder(),
        enabledBorder: inputBorder(),
        // El foco debe verse (antes no tenía borde y no se sabía qué campo estaba activo).
        focusedBorder: inputBorder(BorderSide(color: colors.ink, width: 2)),
        errorBorder: inputBorder(BorderSide(color: colors.danger, width: 1.5)),
        focusedErrorBorder:
            inputBorder(BorderSide(color: colors.danger, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.ink,
          foregroundColor: colors.onInk,
          shape: rounded,
          elevation: 0,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.ink,
          foregroundColor: colors.onInk,
          shape: rounded,
          minimumSize: const Size(64, 48),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.ink,
          side: BorderSide(color: colors.ink.withValues(alpha: 0.5)),
          shape: rounded,
          minimumSize: const Size(64, 48),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colors.ink),
      ),
      chipTheme: ChipThemeData(
        selectedColor: colors.accent.withValues(alpha: 0.3),
        side: BorderSide(color: colors.outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.ink,
        linearTrackColor: colors.accent.withValues(alpha: 0.25),
        circularTrackColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.textPrimary,
        contentTextStyle: TextStyle(color: background, fontSize: 15),
        actionTextColor: colors.accent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: colors.iconInactive,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusCard)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
      ),
    );
  }

  // Selector de Tema
  Future<void> setTheme(String themeName, {bool save = true}) async {
    switch (themeName) {
      case 'dark':
        currentTheme.value = _darkTheme;
        break;
      case 'pink':
        currentTheme.value = _pinkTheme;
        break;
      case 'blue':
        currentTheme.value = _blueTheme;
        break;
      default:
        currentTheme.value = _salviaTheme;
        break;
    }

    if (save) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_theme', themeName);
    }
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('app_theme') ?? 'light';
    await setTheme(savedTheme, save: false);
  }
}

/// Colores base de un tema: brillo, fondo, tarjeta y tokens [LectorColors].
@immutable
class ThemePalette {
  final Brightness brightness;
  final Color background;
  final Color card;
  final LectorColors colors;

  const ThemePalette({
    required this.brightness,
    required this.background,
    required this.card,
    required this.colors,
  });
}
