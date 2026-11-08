import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/login_screen.dart';
import 'screens/tabs_screen.dart';
import 'services/auth_service.dart';
import 'services/api_client.dart';
import 'services/display_mode_service.dart';
import 'services/theme_service.dart';
import 'services/timer_background_service.dart';
import 'config.dart';

void main() async {
  // 1. Aseguramos que Flutter esté listo
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Inicializaciones independientes EN PARALELO (antes eran secuenciales y el
  //    tiempo de arranque era la suma de todas):
  //    - servicio del cronómetro en segundo plano
  //    - formato de fechas en español
  //    - tema guardado
  //    - token desde el almacenamiento cifrado
  await Future.wait([
    TimerBackgroundService.initializeService(),
    initializeDateFormatting('es', null),
    ThemeService().loadTheme(),
    ApiClient().loadToken(),
  ]);

  // 3. AUTO-LOGIN: verificamos localmente que el token no haya expirado
  final token = await ApiClient().getToken();
  final bool hasValidToken = AuthService.isJwtValid(token);

  // Token expirado: limpiar solo lo local. No se llama a /auth/logout porque un token
  // expirado ya no sirve, y esperar a la red aquí retrasaría el arranque (o lo colgaría sin red).
  if (token != null && !hasValidToken) {
    await ApiClient().clearSession();
  }

  final Widget initialScreen =
      hasValidToken ? const TabsScreen() : const LoginScreen();

  // 4. Arrancamos la app
  runApp(LectorApp(initialScreen: initialScreen));

  // 5. Alta tasa de refresco (90/120 Hz): tras el primer frame y al volver a la app
  //    (ver DisplayModeService para el porqué).
  DisplayModeService.init();
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
