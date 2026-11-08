library;

import 'package:flutter/material.dart';

/// Configuración centralizada de la aplicación.
/// Único lugar donde vive la URL base y la clave de navegación global.
class Config {
  Config._(); // No instanciable

  /// URL base de la API. Por defecto, PRODUCCIÓN.
  ///
  /// Para desarrollo local con el emulador Android, NO edites este archivo:
  /// pásala al compilar, así nunca se publica por error una app apuntando a localhost.
  ///
  ///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
  ///
  /// (En VS Code / Android Studio se puede guardar en la configuración de ejecución.)
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.nacholoz3d.cl/api',
  );

  /// Clave global del Navigator para poder navegar desde servicios (ej: redirect a Login al recibir 401)
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
}
