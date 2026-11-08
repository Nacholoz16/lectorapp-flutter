import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class AuthService {
  // Singleton
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _api = ApiClient();

  /// Inicia sesión con email (si contiene '@') o username.
  /// Lanza [ApiException] con el mensaje del backend (ej. "Credenciales inválidas").
  Future<void> login(String identifier, String password) async {
    final payload = identifier.contains('@')
        ? {'email': identifier, 'password': password}
        : {'username': identifier, 'password': password};

    final data =
        await _api.post('/auth/login', body: payload, redirectOn401: false);
    await _saveSession(data);
  }

  /// Recuperación, paso 1: pide que se envíe un código de 6 dígitos al email.
  /// La API responde lo mismo exista o no la cuenta; devuelve ese mensaje.
  Future<String> requestPasswordReset(String email) async {
    final data = await _api.post(
      '/auth/forgot-password',
      body: {'email': email},
      redirectOn401: false,
    );
    return (data is Map ? data['message'] : null)?.toString() ??
        'Si el email está registrado, te enviamos un código.';
  }

  /// Recuperación, paso 2: código + contraseña nueva. Si es correcto deja la sesión iniciada
  /// (la API cierra todas las sesiones anteriores de esa cuenta).
  Future<void> resetPassword({
    required String email,
    required String code,
    required String password,
  }) async {
    final data = await _api.post(
      '/auth/reset-password',
      body: {'email': email, 'code': code, 'password': password},
      redirectOn401: false,
    );
    await _saveSession(data);
  }

  /// Registra un nuevo usuario y deja la sesión iniciada.
  Future<void> register(String username, String email, String password) async {
    final data = await _api.post(
      '/auth/register',
      body: {'username': username, 'email': email, 'password': password},
      redirectOn401: false,
    );
    await _saveSession(data);
  }

  Future<void> _saveSession(dynamic data) async {
    if (data is! Map || data['token'] is! String) {
      throw ApiException('Respuesta inválida del servidor');
    }
    await _api.setSession(
      token: data['token'] as String,
      refreshToken: data['refresh_token'] as String?,
    );

    // Solo lo necesario para la UI: no persistimos el email en almacenamiento sin cifrar.
    final user = data['user'] as Map? ?? {};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      ApiClient.userDataKey,
      json.encode({
        'id': user['id'],
        'username': user['username'],
        'avatar': user['avatar'],
      }),
    );
  }

  /// Obtener el token actual (desde caché en memoria).
  Future<String?> getToken() => _api.getToken();

  /// Obtener los datos del usuario logueado guardados.
  Future<Map<String, dynamic>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(ApiClient.userDataKey);
    if (userStr == null) return null;
    try {
      return json.decode(userStr) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Verifica localmente si un JWT no ha expirado (decodifica el payload, no valida la firma:
  /// la firma la valida siempre el backend).
  static bool isJwtValid(String? token) {
    if (token == null || token.isEmpty) return false;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;

      final payload = base64Url.normalize(parts[1]);
      final decoded = json.decode(utf8.decode(base64Url.decode(payload)));
      final exp = decoded['exp'];
      if (exp is! int) return false;

      return DateTime.now()
          .isBefore(DateTime.fromMillisecondsSinceEpoch(exp * 1000));
    } catch (_) {
      return false;
    }
  }

  /// Verifica si el token guardado existe y NO ha expirado.
  Future<bool> isTokenValid() async => isJwtValid(await getToken());

  /// Cierra sesión: revoca en la API el token de acceso y la sesión larga (refresh token),
  /// y luego borra los datos locales. Si no hay red, igual cierra la sesión local.
  Future<void> logout() async {
    try {
      final refreshToken = await _api.getRefreshToken();
      if (await getToken() != null || refreshToken != null) {
        await _api.post(
          '/auth/logout',
          body: {if (refreshToken != null) 'refresh_token': refreshToken},
          redirectOn401: false,
        );
      }
    } catch (_) {
      // Sin red o token ya inválido: no debe impedir cerrar sesión localmente.
    }
    await _api.clearSession();
  }
}
