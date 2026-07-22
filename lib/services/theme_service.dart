import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  final ValueNotifier<ThemeData> currentTheme =
      ValueNotifier<ThemeData>(_salviaTheme);

  // --- CONFIGURACIÓN GLOBAL COMPARTIDA ---

  // Tipografía base (Nunito para lectura suave)
  static TextTheme _buildTextTheme(Color textColor) {
    return GoogleFonts.nunitoTextTheme().apply(
      bodyColor: textColor,
      displayColor: textColor,
    );
  }

  // Estilo elegante para Títulos (Lora)
  static TextStyle get titleStyle =>
      GoogleFonts.lora(fontWeight: FontWeight.bold);

  // Bordes redondeados globales (Efecto Burbuja)
  static final RoundedRectangleBorder _bubbleShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(24.0),
  );

  // Inputs suaves sin bordes
  static InputDecorationTheme _buildInputDecoration(Color fillColor) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fillColor,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24.0),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24.0),
          borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24.0),
          borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }

  // --- NUEVO: Color del cursor y selección de texto ---
  static TextSelectionThemeData _buildTextSelection(Color color) {
    return TextSelectionThemeData(
      cursorColor: color,
      selectionColor: color.withOpacity(0.3),
      selectionHandleColor: color,
    );
  }

  // --- LAS 4 PALETAS PASTEL ---

  // 1. Tema Claro: "Crema & Salvia"
  static final ThemeData _salviaTheme = ThemeData(
    brightness: Brightness.light,
    textSelectionTheme: _buildTextSelection(const Color(0xFF8BA89F)),
    primaryColor: const Color(0xFF8BA89F), // Salvia suave
    scaffoldBackgroundColor: const Color(0xFFFDFBF7), // Crema
    cardColor: Colors.white,
    textTheme: _buildTextTheme(const Color(0xFF3D4042)), // Gris carbón
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFFFDFBF7),
      foregroundColor: const Color(0xFF3D4042),
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.lora(
          color: const Color(0xFF3D4042),
          fontSize: 20,
          fontWeight: FontWeight.bold),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF8BA89F),
      foregroundColor: Colors.white,
      elevation: 4,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: Color(0xFF8BA89F),
      unselectedItemColor: Color(0xFFBDBDBD),
      elevation: 0,
    ),
    cardTheme:
        CardThemeData(shape: _bubbleShape, elevation: 0, color: Colors.white),
    inputDecorationTheme: _buildInputDecoration(Colors.black.withOpacity(0.03)),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF8BA89F),
        foregroundColor: Colors.white,
        shape: _bubbleShape,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    ),
  );

  // 2. Tema Pink: "Rosa Peonía"
  static final ThemeData _pinkTheme = _salviaTheme.copyWith(
    primaryColor: const Color(0xffff6b8a), // Rosa palo
    textSelectionTheme: _buildTextSelection(const Color(0xFFD8A7B1)),
    scaffoldBackgroundColor:
        const Color(0xFFFEF9FA), // <-- NUEVO: Crema rosado muy sutil
    appBarTheme: _salviaTheme.appBarTheme
        .copyWith(backgroundColor: const Color(0xFFFEF9FA)), // <-- NUEVO
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFFD8A7B1),
      foregroundColor: Colors.white,
      elevation: 4,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: Color(0xFFD8A7B1),
      unselectedItemColor: Color(0xFFBDBDBD),
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFD8A7B1),
        foregroundColor: Colors.white,
        shape: _bubbleShape,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    ),
  );

  // 3. Tema Blue: "Brisa de Mar"
  static final ThemeData _blueTheme = _salviaTheme.copyWith(
    primaryColor: const Color(0xFFA1C4D0), // Celeste agrisado
    textSelectionTheme: _buildTextSelection(const Color(0xFFA1C4D0)),
    scaffoldBackgroundColor:
        const Color(0xFFF7FBFD), // <-- NUEVO: Crema azulado muy sutil
    appBarTheme: _salviaTheme.appBarTheme
        .copyWith(backgroundColor: const Color(0xFFF7FBFD)), // <-- NUEVO
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFFA1C4D0),
      foregroundColor: Colors.white,
      elevation: 4,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: Color(0xFFA1C4D0),
      unselectedItemColor: Color(0xFFBDBDBD),
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFA1C4D0),
        foregroundColor: Colors.white,
        shape: _bubbleShape,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    ),
  );

  // 4. Tema Oscuro: "Café de Medianoche"
  static final ThemeData _darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: const Color(0xFFB59E86), // Arena oscuro
    scaffoldBackgroundColor: const Color(0xFF1C1917), // Marrón oscuro
    cardColor: const Color(0xFF292524),
    textTheme: _buildTextTheme(const Color(0xFFE7E5E4)), // Gris piedra
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF1C1917),
      foregroundColor: const Color(0xFFE7E5E4),
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.lora(
          color: const Color(0xFFE7E5E4),
          fontSize: 20,
          fontWeight: FontWeight.bold),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFFB59E86),
      foregroundColor: Color(0xFF1C1917),
      elevation: 4,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF1C1917),
      selectedItemColor: Color(0xFFB59E86),
      unselectedItemColor: Color(0xFF78716C),
      elevation: 0,
    ),
    cardTheme: CardThemeData(
        shape: _bubbleShape, elevation: 0, color: const Color(0xFF292524)),
    inputDecorationTheme: _buildInputDecoration(Colors.white.withOpacity(0.05)),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFB59E86),
        foregroundColor: const Color(0xFF1C1917),
        shape: _bubbleShape,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    ),
  );

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

    // ¡La conexión que faltaba! Guardamos en la memoria del teléfono
    if (save) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_theme', themeName);
    }
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('app_theme') ?? 'light';
    setTheme(savedTheme, save: false);
  }
}
