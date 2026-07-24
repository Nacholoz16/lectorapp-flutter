library;

import 'package:flutter/material.dart';

/// Configuración centralizada de la aplicación.
/// Único lugar donde vive la URL base y la clave de navegación global.
class Config {
  Config._(); // No instanciable
  
  /// URL base de la API (único lugar donde se define)
  // static const String baseUrl = 'https://api.nacholoz3d.cl/api';
  static const String baseUrl = 'http://10.0.2.2:3000/api';


  /// Clave global del Navigator para poder navegar desde servicios (ej: redirect a Login al recibir 401)
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
}
