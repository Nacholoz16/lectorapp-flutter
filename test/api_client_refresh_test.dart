import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_lectorapp/services/api_client.dart';

/// JWT falso (firma irrelevante: la app solo lee `exp`).
String jwt({required Duration expiresIn}) {
  String b64(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(json.encode(m))).replaceAll('=', '');
  final exp = DateTime.now().add(expiresIn).millisecondsSinceEpoch ~/ 1000;
  return '${b64({'alg': 'HS256'})}.${b64({'id': 1, 'exp': exp})}.firma';
}

/// Se crea dentro de la zona de cada test (el singleton abre un HttpClient al construirse).
ApiClient get api => ApiClient();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> calls;
  late int refreshCalls;

  /// Simula la API: /auth/refresh rota tokens; el resto responde 401 si el acceso no es
  /// el "fresco" emitido por el refresh, 200 si lo es.
  Future<void> setUp0({
    required String access,
    String? refresh = 'refresh-1',
    int refreshStatus = 200,
  }) async {
    calls = [];
    refreshCalls = 0;
    final freshAccess = jwt(expiresIn: const Duration(minutes: 30));
    FlutterSecureStorage.setMockInitialValues({
      'auth-token': access,
      if (refresh != null) 'refresh-token': refresh,
    });
    SharedPreferences.setMockInitialValues({});
    await api.loadToken();
    api.httpClientForTesting = MockClient((req) async {
      calls.add('${req.method} ${req.url.path}');
      if (req.url.path.endsWith('/auth/refresh')) {
        refreshCalls++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        if (refreshStatus != 200) {
          return http.Response(json.encode({'error': 'Tu sesión expiró'}), refreshStatus);
        }
        return http.Response(
            json.encode({'token': freshAccess, 'refresh_token': 'refresh-2'}), 200);
      }
      final ok = req.headers['Authorization'] == 'Bearer $freshAccess';
      return ok
          ? http.Response(json.encode({'ok': true}), 200)
          : http.Response(json.encode({'error': 'Token no autorizado o expirado'}), 401);
    });
  }

  test('acceso vencido + refresh: renueva ANTES de pedir (sin 401 de por medio)', () async {
    await setUp0(access: jwt(expiresIn: const Duration(minutes: -5)));
    final res = await api.get('/readings/feed');
    expect(res, {'ok': true});
    expect(calls.first, endsWith('/auth/refresh'));
    expect(calls.where((c) => c.endsWith('/readings/feed')), hasLength(1));
    expect(await api.getRefreshToken(), 'refresh-2'); // rotado y guardado
  });

  test('401 con acceso "vigente" (p. ej. revocado): renueva y reintenta una vez', () async {
    await setUp0(access: jwt(expiresIn: const Duration(minutes: 20)));
    final res = await api.get('/readings/feed');
    expect(res, {'ok': true});
    expect(calls, hasLength(3)); // feed(401) → refresh → feed(200)
  });

  test('varias peticiones a la vez comparten UNA sola renovación', () async {
    await setUp0(access: jwt(expiresIn: const Duration(minutes: -1)));
    final results = await Future.wait([
      api.get('/readings/feed'),
      api.get('/users/x'),
      api.get('/readings/my-library'),
    ]);
    expect(results, everyElement({'ok': true}));
    expect(refreshCalls, 1);
  });

  test('refresh rechazado (401): cierra la sesión local y lanza 401', () async {
    await setUp0(access: jwt(expiresIn: const Duration(minutes: -1)), refreshStatus: 401);
    await expectLater(
      api.get('/readings/feed'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
    );
    expect(await api.getToken(), isNull);
    expect(await api.getRefreshToken(), isNull);
  });

  test('servidor caído al renovar (503): NO cierra la sesión', () async {
    await setUp0(access: jwt(expiresIn: const Duration(minutes: 20)), refreshStatus: 503);
    await expectLater(api.get('/readings/feed'), throwsA(isA<ApiException>()));
    expect(await api.getRefreshToken(), 'refresh-1');
  });

  test('isAccessTokenExpired: margen de 30 s y tokens inválidos', () {
    expect(ApiClient.isAccessTokenExpired(jwt(expiresIn: const Duration(minutes: 5))), isFalse);
    expect(ApiClient.isAccessTokenExpired(jwt(expiresIn: const Duration(seconds: 10))), isTrue);
    expect(ApiClient.isAccessTokenExpired('basura'), isTrue);
    expect(ApiClient.isAccessTokenExpired(null), isTrue);
  });
}
