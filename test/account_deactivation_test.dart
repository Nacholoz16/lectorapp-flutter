import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_lectorapp/config.dart';
import 'package:test_lectorapp/screens/deactivate_account_screen.dart';
import 'package:test_lectorapp/screens/deactivated_screen.dart';
import 'package:test_lectorapp/screens/login_screen.dart';
import 'package:test_lectorapp/screens/tabs_screen.dart';
import 'package:test_lectorapp/services/account_service.dart';
import 'package:test_lectorapp/services/api_client.dart';
import 'package:test_lectorapp/services/auth_service.dart';
import 'package:test_lectorapp/services/theme_service.dart';
import 'package:test_lectorapp/ui/account_copy.dart';

/// Tarea 2.1: desactivar y reactivar la cuenta (modo solo lectura).

ThemeData _testTheme() =>
    ThemeData(extensions: [ThemeService.palettes['light']!.colors]);

/// JWT falso vigente (la app solo lee `exp`).
String _jwt() {
  String b64(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(json.encode(m))).replaceAll('=', '');
  final exp =
      DateTime.now().add(const Duration(minutes: 20)).millisecondsSinceEpoch ~/
          1000;
  return '${b64({'alg': 'HS256'})}.${b64({'id': 7, 'exp': exp})}.firma';
}

Future<Map<String, dynamic>?> _userData() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(ApiClient.userDataKey);
  return raw == null ? null : json.decode(raw) as Map<String, dynamic>;
}

http.Response _json(Object body, int status) =>
    http.Response(json.encode(body), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

/// Sesión iniciada (acceso vigente + refresh) y `user-data` de una cuenta activa.
Future<void> _signedIn({String status = 'active'}) async {
  FlutterSecureStorage.setMockInitialValues({
    'auth-token': _jwt(),
    'refresh-token': 'refresh-1',
  });
  SharedPreferences.setMockInitialValues({
    ApiClient.userDataKey:
        json.encode({'id': 7, 'username': 'ana', 'status': status}),
  });
  await ApiClient().loadToken();
  await AccountService().load();
}

/// Deja terminar las respuestas simuladas (MockClient y SharedPreferences de prueba son
/// futuros de Dart puro: avanzan con el reloj falso). No se usa `runAsync` a propósito: así
/// google_fonts nunca llega a pedir Lora a la red real durante el test.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Textos (account_copy)', () {
    test('desactivar: 0, 1 y N lecturas públicas', () {
      expect(deactivateReadingsText(0), contains('No tienes lecturas públicas'));
      expect(deactivateReadingsText(1),
          'Tu lectura pública pasará a privada. Cuando vuelvas, regresarán como estaban.');
      expect(deactivateReadingsText(3),
          'Tus 3 lecturas públicas pasarán a privadas. Cuando vuelvas, regresarán como estaban.');
    });

    test('reactivar: 0, 1 y N lecturas que volverán', () {
      expect(reactivateReadingsText(0), contains('seguirán siendo privadas'));
      expect(reactivateReadingsText(1),
          startsWith('Tu lectura que era pública volverá a ser pública'));
      expect(reactivateReadingsText(4),
          startsWith('Tus 4 lecturas que eran públicas volverán a ser públicas'));
    });

    test('avisos tras reactivar y desactivar', () {
      expect(reactivatedMessage(0), 'Tu cuenta está activa de nuevo.');
      expect(reactivatedMessage(1), endsWith('Volvió a ser pública 1 lectura.'));
      expect(reactivatedMessage(5),
          endsWith('Volvieron a ser públicas 5 lecturas.'));
      expect(deactivatedMessage(0), 'Tu cuenta está desactivada.');
      expect(deactivatedMessage(2), endsWith('Tus 2 lecturas públicas ahora son privadas.'));
    });
  });

  group('Parseo del estado', () {
    test('statusFrom solo acepta un string no vacío', () {
      expect(AccountService.statusFrom({'status': 'deactivated'}), 'deactivated');
      expect(AccountService.statusFrom({'status': ''}), isNull);
      expect(AccountService.statusFrom({'status': 1}), isNull);
      expect(AccountService.statusFrom({'username': 'ana'}), isNull);
      expect(AccountService.statusFrom(null), isNull);
    });

    test('AccountStatusInfo.fromJson es tolerante (números como string, faltantes)', () {
      final info = AccountStatusInfo.fromJson(const {
        'status': 'deactivated',
        'public_readings': '0',
        'restorable_readings': 3,
      });
      expect(info.isDeactivated, isTrue);
      expect(info.publicReadings, 0);
      expect(info.restorableReadings, 3);

      final empty = AccountStatusInfo.fromJson(const {});
      expect(empty.status, 'active');
      expect(empty.isDeactivated, isFalse);
      expect(empty.restorableReadings, 0);
    });

    test('ApiException: isAccountDeactivated / isInvalidPassword', () {
      expect(
          ApiException('x', statusCode: 403, code: 'ACCOUNT_DEACTIVATED')
              .isAccountDeactivated,
          isTrue);
      expect(ApiException('x', statusCode: 403, code: 'FORBIDDEN').isAccountDeactivated,
          isFalse);
      expect(
          ApiException('x', statusCode: 401, code: 'INVALID_PASSWORD').isInvalidPassword,
          isTrue);
      expect(ApiException('x', statusCode: 401, code: 'UNAUTHORIZED').isInvalidPassword,
          isFalse);
    });
  });

  group('Estado local y sesión', () {
    test('load() lee el status de user-data; sin user-data queda activa', () async {
      await _signedIn(status: 'deactivated');
      expect(AccountService().isDeactivated.value, isTrue);

      SharedPreferences.setMockInitialValues({});
      await AccountService().load();
      expect(AccountService().isDeactivated.value, isFalse);
    });

    test('login de una cuenta desactivada guarda el status y activa el modo solo lectura',
        () async {
      await _signedIn();
      SharedPreferences.setMockInitialValues({});
      ApiClient().httpClientForTesting = MockClient((_) async => _json({
            'token': _jwt(),
            'refresh_token': 'refresh-2',
            'user': {'id': 7, 'username': 'ana', 'status': 'deactivated'},
          }, 200));
      await AuthService().login('ana', 'password123');
      expect(AccountService().isDeactivated.value, isTrue);
      expect((await _userData())!['status'], 'deactivated');
    });

    test('login sin campo status (API vieja) → activa', () async {
      await _signedIn(status: 'deactivated');
      ApiClient().httpClientForTesting = MockClient((_) async => _json({
            'token': _jwt(),
            'user': {'id': 7, 'username': 'ana'},
          }, 200));
      await AuthService().login('ana', 'password123');
      expect(AccountService().isDeactivated.value, isFalse);
      expect((await _userData())!['status'], 'active');
    });

    test('cerrar la sesión no cambia el modo (no remonta pestañas); el próximo login lo fija',
        () async {
      await _signedIn(status: 'deactivated');
      await ApiClient().clearSession();
      expect(AccountService().isDeactivated.value, isTrue);

      ApiClient().httpClientForTesting = MockClient((_) async => _json({
            'token': _jwt(),
            'refresh_token': 'refresh-2',
            'user': {'id': 8, 'username': 'beto', 'status': 'active'},
          }, 200));
      await AuthService().login('beto', 'password123');
      expect(AccountService().isDeactivated.value, isFalse);
    });
  });

  group('ApiClient: red de seguridad y contraseña incorrecta', () {
    test('un 403 ACCOUNT_DEACTIVATED pasa a modo solo lectura (una sola vez)', () async {
      await _signedIn();
      var calls = 0;
      ApiClient().httpClientForTesting = MockClient((_) async {
        calls++;
        return _json({'error': 'Tu cuenta está desactivada.', 'code': 'ACCOUNT_DEACTIVATED'},
            403);
      });
      await expectLater(
        ApiClient().get('/readings/feed'),
        throwsA(isA<ApiException>()
            .having((e) => e.isAccountDeactivated, 'isAccountDeactivated', isTrue)),
      );
      expect(AccountService().isDeactivated.value, isTrue);
      // La sesión se conserva (no es un 401) y no hubo reintentos.
      expect(await ApiClient().getRefreshToken(), 'refresh-1');
      expect(calls, 1);
      await Future<void>.delayed(Duration.zero);
      expect((await _userData())!['status'], 'deactivated');

      // Otra petición que falle igual no cambia nada ni hace bucles.
      await expectLater(ApiClient().get('/readings/feed'), throwsA(isA<ApiException>()));
      expect(AccountService().isDeactivated.value, isTrue);
      expect(calls, 2);
    });

    test('un 403 FORBIDDEN normal no toca el estado de la cuenta', () async {
      await _signedIn();
      ApiClient().httpClientForTesting = MockClient(
          (_) async => _json({'error': 'No', 'code': 'FORBIDDEN'}, 403));
      await expectLater(ApiClient().get('/x'), throwsA(isA<ApiException>()));
      expect(AccountService().isDeactivated.value, isFalse);
    });

    test('401 INVALID_PASSWORD no renueva ni cierra la sesión', () async {
      await _signedIn();
      final paths = <String>[];
      ApiClient().httpClientForTesting = MockClient((req) async {
        paths.add(req.url.path);
        return _json({'error': 'La contraseña no es correcta.', 'code': 'INVALID_PASSWORD'},
            401);
      });
      await expectLater(
        AccountService().deactivate('incorrecta'),
        throwsA(isA<ApiException>()
            .having((e) => e.isInvalidPassword, 'isInvalidPassword', isTrue)),
      );
      expect(paths, [endsWith('/account/deactivate')]);
      expect(await ApiClient().getToken(), isNotNull);
      expect(await ApiClient().getRefreshToken(), 'refresh-1');
      expect(AccountService().isDeactivated.value, isFalse);
    });
  });

  group('AccountService: desactivar y reactivar', () {
    test('deactivate envía la contraseña y pasa a desactivada', () async {
      await _signedIn();
      late http.Request sent;
      ApiClient().httpClientForTesting = MockClient((req) async {
        sent = req;
        return _json({'status': 'deactivated', 'hidden_readings': 2}, 200);
      });
      expect(await AccountService().deactivate('password123'), 2);
      expect(sent.method, 'POST');
      expect(json.decode(sent.body), {'password': 'password123'});
      expect(AccountService().isDeactivated.value, isTrue);
      expect((await _userData())!['status'], 'deactivated');
    });

    test('deactivate con 409 (ya desactivada en otro teléfono) sincroniza y no falla',
        () async {
      await _signedIn();
      ApiClient().httpClientForTesting = MockClient((req) async {
        if (req.url.path.endsWith('/account/status')) {
          return _json({'status': 'deactivated', 'public_readings': 0, 'restorable_readings': 2},
              200);
        }
        return _json({'error': 'Tu cuenta ya está desactivada.', 'code': 'CONFLICT'}, 409);
      });
      expect(await AccountService().deactivate('password123'), 0);
      expect(AccountService().isDeactivated.value, isTrue);
    });

    test('reactivate devuelve cuántas volvieron a ser públicas y sale del modo', () async {
      await _signedIn(status: 'deactivated');
      ApiClient().httpClientForTesting =
          MockClient((_) async => _json({'status': 'active', 'restored_readings': 3}, 200));
      expect(await AccountService().reactivate(), 3);
      expect(AccountService().isDeactivated.value, isFalse);
      expect((await _userData())!['status'], 'active');
    });

    test('reactivate con 409 y la cuenta ya activa → 0, sin error', () async {
      await _signedIn(status: 'deactivated');
      ApiClient().httpClientForTesting = MockClient((req) async {
        if (req.url.path.endsWith('/account/status')) {
          return _json({'status': 'active', 'public_readings': 1, 'restorable_readings': 0}, 200);
        }
        return _json({'error': 'Tu cuenta ya está activa.', 'code': 'CONFLICT'}, 409);
      });
      expect(await AccountService().reactivate(), 0);
      expect(AccountService().isDeactivated.value, isFalse);
    });
  });

  group('Pantallas', () {
    testWidgets('TabsScreen con la cuenta desactivada: solo la biblioteca, sin pestañas',
        (tester) async {
      await _signedIn(status: 'deactivated');
      ApiClient().httpClientForTesting = MockClient((req) async =>
          req.url.path.endsWith('/account/status')
              ? _json({'status': 'deactivated', 'public_readings': 0, 'restorable_readings': 0},
                  200)
              : _json(<dynamic>[], 200));
      await tester.pumpWidget(MaterialApp(theme: _testTheme(), home: const TabsScreen()));
      await _settle(tester);
      expect(find.text('Tu cuenta está desactivada'), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsNothing);
    });

    testWidgets(
        'cerrar sesión en modo solo lectura: solo POST /auth/logout, sin remontar las pestañas',
        (tester) async {
      await _signedIn(status: 'deactivated');
      final requests = <String>[];
      ApiClient().httpClientForTesting = MockClient((req) async {
        final auth = req.headers['Authorization'] == null ? 'sin token' : 'con token';
        requests.add('${req.method} ${req.url.path} ($auth)');
        if (req.url.path.endsWith('/account/status')) {
          return _json({'status': 'deactivated', 'public_readings': 0, 'restorable_readings': 0},
              200);
        }
        if (req.url.path.endsWith('/auth/logout')) return _json({'success': true}, 200);
        return _json(<dynamic>[], 200);
      });
      await tester.pumpWidget(MaterialApp(
        navigatorKey: Config.navigatorKey,
        theme: _testTheme(),
        home: const TabsScreen(),
      ));
      await _settle(tester);
      // El indicador fijo de arriba también ofrece reactivar.
      expect(find.text('Cuenta desactivada'), findsOneWidget);
      expect(find.byTooltip('Reactivar mi cuenta'), findsOneWidget);

      requests.clear();
      await tester.ensureVisible(find.text('Cerrar sesión'));
      await tester.tap(find.text('Cerrar sesión'));
      await _settle(tester);

      expect(requests, hasLength(1), reason: '$requests');
      expect(requests.single, startsWith('POST'));
      expect(requests.single, contains('/auth/logout'));
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(await ApiClient().getRefreshToken(), isNull);
    });

    testWidgets('un 403 ACCOUNT_DEACTIVATED cierra las pantallas apiladas', (tester) async {
      await _signedIn();
      ApiClient().httpClientForTesting = MockClient((_) async =>
          _json({'error': 'Tu cuenta está desactivada.', 'code': 'ACCOUNT_DEACTIVATED'}, 403));
      await tester.pumpWidget(MaterialApp(
        navigatorKey: Config.navigatorKey,
        theme: _testTheme(),
        home: const Scaffold(body: Text('raíz')),
      ));
      unawaited(Config.navigatorKey.currentState!.push(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('detalle')))));
      await tester.pumpAndSettle();
      expect(find.text('detalle'), findsOneWidget);

      Object? error;
      unawaited(ApiClient().get('/books/search?q=x').then((_) {}, onError: (Object e) => error = e));
      await _settle(tester);
      expect(error, isA<ApiException>());
      expect(find.text('detalle'), findsNothing);
      expect(find.text('raíz'), findsOneWidget);
      expect(AccountService().isDeactivated.value, isTrue);
    });

    testWidgets('modo solo lectura: aviso, reactivar con confirmación y sin "añadir"',
        (tester) async {
      await _signedIn(status: 'deactivated');
      final requests = <String>[];
      ApiClient().httpClientForTesting = MockClient((req) async {
        requests.add('${req.method} ${req.url.path}');
        if (req.url.path.endsWith('/account/status')) {
          return _json({'status': 'deactivated', 'public_readings': 0, 'restorable_readings': 2},
              200);
        }
        if (req.url.path.endsWith('/account/reactivate')) {
          return _json({'status': 'active', 'restored_readings': 2}, 200);
        }
        return _json(<dynamic>[], 200); // my-library vacía
      });

      await tester.pumpWidget(MaterialApp(
        theme: _testTheme(),
        home: const DeactivatedScreen(),
      ));
      await _settle(tester);
      await tester.pumpAndSettle();

      expect(find.text('Tu cuenta está desactivada'), findsOneWidget);
      expect(find.text('Reactivar mi cuenta'), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsOneWidget);
      expect(find.byTooltip('Añadir un libro'), findsNothing);
      expect(find.text('Buscar libros'), findsNothing);
      // Solo endpoints permitidos con la cuenta desactivada.
      expect(
          requests.every((r) =>
              r.contains('/account/status') || r.contains('/readings/my-library')),
          isTrue,
          reason: '$requests');

      await tester.ensureVisible(find.text('Reactivar mi cuenta'));
      await tester.tap(find.text('Reactivar mi cuenta'));
      await _settle(tester);
      await tester.pumpAndSettle();
      expect(find.text('¿Reactivar tu cuenta?'), findsOneWidget);
      expect(find.textContaining('Tus 2 lecturas que eran públicas volverán a ser públicas'),
          findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Reactivar'));
      await _settle(tester);
      await tester.pumpAndSettle();
      expect(
          requests.any((r) => r.startsWith('POST') && r.endsWith('/account/reactivate')),
          isTrue);
      expect(AccountService().isDeactivated.value, isFalse);
      expect(find.text('Tu cuenta está activa de nuevo. Volvieron a ser públicas 2 lecturas.'),
          findsOneWidget);
    });

    testWidgets('desactivar: explica, contraseña incorrecta junto al campo, y desactiva',
        (tester) async {
      await _signedIn();
      var password = '';
      ApiClient().httpClientForTesting = MockClient((req) async {
        if (req.url.path.endsWith('/account/status')) {
          return _json({'status': 'active', 'public_readings': 3, 'restorable_readings': 0}, 200);
        }
        password = (json.decode(req.body) as Map)['password'] as String;
        return password == 'buena123'
            ? _json({'status': 'deactivated', 'hidden_readings': 3}, 200)
            : _json({'error': 'La contraseña no es correcta.', 'code': 'INVALID_PASSWORD'}, 401);
      });

      // Se abre desde otra pantalla, como en la app (Perfil → ⚙ → Cuenta): al terminar vuelve
      // a la raíz.
      await tester.pumpWidget(MaterialApp(
        theme: _testTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const DeactivateAccountScreen())),
              child: const Text('abrir'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await _settle(tester);
      await tester.pumpAndSettle();

      expect(
          find.text('Tus 3 lecturas públicas pasarán a privadas. '
              'Cuando vuelvas, regresarán como estaban.'),
          findsOneWidget);

      // Sin contraseña: no llama a la API.
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Desactivar mi cuenta'));
      await tester.tap(find.widgetWithText(FilledButton, 'Desactivar mi cuenta'));
      await tester.pumpAndSettle();
      expect(find.text('Escribe tu contraseña para confirmar'), findsOneWidget);

      Future<void> submit(String pw) async {
        await tester.enterText(find.byType(TextField), pw);
        await tester.ensureVisible(find.widgetWithText(FilledButton, 'Desactivar mi cuenta'));
        await tester.tap(find.widgetWithText(FilledButton, 'Desactivar mi cuenta'));
        await tester.pumpAndSettle();
        expect(find.text('¿Desactivar tu cuenta?'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'Desactivar'));
        await _settle(tester);
        await tester.pumpAndSettle();
      }

      await submit('mala1234');
      expect(password, 'mala1234');
      expect(find.text('La contraseña no es correcta'), findsOneWidget);
      expect(AccountService().isDeactivated.value, isFalse);
      expect(await ApiClient().getRefreshToken(), 'refresh-1');

      await submit('buena123');
      expect(AccountService().isDeactivated.value, isTrue);
      expect(find.text('Tómate un descanso'), findsNothing);
      expect(find.text('Tu cuenta está desactivada. Tus 3 lecturas públicas ahora son privadas.'),
          findsOneWidget);
    });
  });
}
