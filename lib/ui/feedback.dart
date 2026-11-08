import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_client.dart';

/// Mensajes al usuario con un estilo y una voz comunes (ver skill `lectorapp-ux-patterns`).
///
/// El aspecto (flotante, colores) viene de `snackBarTheme` en `ThemeService`.

/// Convierte cualquier error en un texto humano. Nunca muestra `toString()` de excepciones
/// internas: solo los mensajes de [ApiException], que ya están redactados para el usuario.
String friendlyError(Object error, {String? fallback}) {
  if (error is ApiException) {
    switch (error.statusCode) {
      case 409:
        return 'Ya tienes este libro en tu biblioteca.';
      case 429:
        return 'Vas muy rápido. Espera un momento e inténtalo de nuevo.';
      case 403:
        return 'No tienes permiso para hacer esto.';
      case 404:
        return 'No encontramos lo que buscabas. Puede que ya no exista.';
    }
    if (error.message.isNotEmpty) return error.message;
  }
  return fallback ?? 'Algo salió mal. Inténtalo de nuevo.';
}

void showSuccess(BuildContext context, String message) {
  unawaitedHaptic(HapticFeedback.lightImpact());
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Muestra un error humano. Si se pasa [onRetry], añade la acción "Reintentar" y deja el
/// mensaje visible más tiempo para que dé tiempo a leerlo y pulsarlo.
void showError(
  BuildContext context,
  Object error, {
  String? fallback,
  VoidCallback? onRetry,
}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(
        friendlyError(error, fallback: fallback),
        style: TextStyle(color: scheme.onError),
      ),
      backgroundColor: scheme.error,
      duration: Duration(seconds: onRetry != null ? 8 : 5),
      action: onRetry == null
          ? null
          : SnackBarAction(
              label: 'Reintentar',
              textColor: scheme.onError,
              onPressed: onRetry,
            ),
    ));
}

/// La háptica es un detalle: si la plataforma no la soporta, se ignora sin romper nada.
void unawaitedHaptic(Future<void> f) {
  f.catchError((_) {});
}
