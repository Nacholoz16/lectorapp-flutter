import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'screens/login_screen.dart';
import 'screens/tabs_screen.dart';
import 'services/theme_service.dart'; // Lo crearemos en el siguiente paso

void main() async {
  // 1. Aseguramos que Flutter esté listo
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Cargamos el formato de fechas en español
  await initializeDateFormatting('es', null);
  await ThemeService().loadTheme();
  // 3. AUTO-LOGIN: Revisamos si hay un token guardado
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth-token');
  try {
    await FlutterDisplayMode.setHighRefreshRate();
  } catch (e) {}
  // Si hay token, vamos al Home (Tabs). Si no, al Login.
  final Widget initialScreen = (token != null && token.isNotEmpty)
      ? const TabsScreen()
      : const LoginScreen();

  // 4. Arrancamos la app
  runApp(LectorApp(initialScreen: initialScreen));
}

class LectorApp extends StatelessWidget {
  final Widget initialScreen;

  const LectorApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    // ValueListenableBuilder escucha los cambios de tema en tiempo real
    return ValueListenableBuilder<ThemeData>(
      valueListenable: ThemeService().currentTheme,
      builder: (context, theme, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'LectorApp',
          theme: theme, // ¡Tema dinámico!
          home: initialScreen, // ¡Pantalla inicial dinámica (Auto-Login)!
        );
      },
    );
  }
}
