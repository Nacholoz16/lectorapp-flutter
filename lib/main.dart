import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'screens/login_screen.dart';
import 'screens/tabs_screen.dart';
import 'services/auth_service.dart';
import 'services/api_client.dart';
import 'services/theme_service.dart';
import 'config.dart';

void main() async {
  // 1. Aseguramos que Flutter esté listo
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Cargamos el formato de fechas en español
  await initializeDateFormatting('es', null);
  await ThemeService().loadTheme();

  // 3. Intentar refresh rate alto (solo Android, falla silenciosamente en otros)
  try {
    await FlutterDisplayMode.setHighRefreshRate();
  } catch (_) {}

  // 4. AUTO-LOGIN: Cargamos el token en caché y verificamos su validez
  await ApiClient().loadToken();
  final token = await ApiClient().getToken();
  final bool hasValidToken = AuthService.isJwtValid(token);

  // Si el token expiró, limpiamos los datos guardados
  if (token != null && !hasValidToken) {
    await AuthService().logout();
  }

  final Widget initialScreen =
      hasValidToken ? const TabsScreen() : const LoginScreen();

  // 5. Arrancamos la app
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
          navigatorKey: Config.navigatorKey, // Clave global para redirect desde ApiClient
          debugShowCheckedModeBanner: false,
          title: 'LectorApp',
          theme: theme,
          home: initialScreen,
        );
      },
    );
  }
}
