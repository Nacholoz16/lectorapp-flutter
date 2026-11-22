import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_lectorapp/config.dart';
import 'package:test_lectorapp/models/reading_log_draft.dart';
import 'package:test_lectorapp/screens/deactivate_account_screen.dart';
import 'package:test_lectorapp/screens/deactivated_screen.dart';
import 'package:test_lectorapp/screens/delete_account_screen.dart';
import 'package:test_lectorapp/screens/login_screen.dart';
import 'package:test_lectorapp/services/account_service.dart';
import 'package:test_lectorapp/services/api_client.dart';
import 'package:test_lectorapp/services/theme_service.dart';
import 'package:test_lectorapp/ui/account_copy.dart';

/// Tarea 2.2: eliminar la cuenta desde la app.

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

http.Response _json(Object body, int status) =>
    http.Response(json.encode(body), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

/// Lo que hay en el teléfono de alguien con sesión: tokens, usuario, caché del feed, dos
/// borradores y sus preferencias de tema y vista.
const _deviceData = <String, Object>{
  'cached_global_feed': '[{"id":1}]',
  'reading_draft_log_12': '{"status":"leyendo","review":"Mi nota privada"}',
  'reading_draft_book_/works/OL1W': '{"status":"terminado"}',
  'app_theme': 'pink',
  'feed_layout': 'compact',
};

Future<void> _signedIn({String status = 'active'}) async {
  FlutterSecureStorage.setMockInitialValues({
    'auth-token': _jwt(),
    'refresh-token': 'refresh-1',
  });
  SharedPreferences.setMockInitialValues({
    ApiClient.userDataKey:
        json.encode({'id': 7, 'username': 'ana', 'status': status}),
    ..._deviceData,
  });
  await ApiClient().loadToken();
  await AccountService().load();
}

Future<Set<String>> _prefsKeys() async =>
    (await SharedPreferences.getInstance()).getKeys();

/// Ver `account_deactivation_test.dart`: deja avanzar las respuestas simuladas sin red real.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  await tester.pumpAndSettle();
}

/// Monta la pantalla como en la app: apilada sobre otra (Perfil → ⚙ → Cuenta).
Future<void> _openScreen(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    navigatorKey: Config.navigatorKey,
    theme: _testTheme(),
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const DeleteAccountScreen())),
          child: const Text('abrir'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

final _deleteButton = find.widgetWithText(FilledButton, 'Eliminar mi cuenta');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Limpieza del teléfono', () {
    test('ReadingLogDraftStore.clearAll borra solo los borradores', () async {
      SharedPreferences.setMockInitialValues(Map.of(_deviceData));
      await ReadingLogDraftStore.clearAll();
      expect(await _prefsKeys(), {'cached_global_feed', 'app_theme', 'feed_layout'});
    });

    test('tras eliminar: sin sesión, usuario, feed ni borradores; tema y vista se quedan',
        () async {
      await _signedIn();
      await AccountService().clearLocalDataAfterDeletion();
      expect(await _prefsKeys(), {'app_theme', 'feed_layout'});
      expect(await ApiClient().getToken(), isNull);
      expect(await ApiClient().getRefreshToken(), isNull);
    });
  });

  group('AccountService.deleteAccount', () {
    test('envía DELETE /account con la contraseña y limpia el teléfono', () async {
      await _signedIn();
      late http.Request sent;
      ApiClient().httpClientForTesting = MockClient((req) async {
        sent = req;
        return _json({'deleted': true}, 200);
      });
      await AccountService().deleteAccount('password123');

      expect(sent.method, 'DELETE');
      expect(sent.url.path, endsWith('/account'));
      expect(sent.headers['Authorization'], startsWith('Bearer '));
      expect(json.decode(sent.body), {'password': 'password123'});
      expect(await _prefsKeys(), {'app_theme', 'feed_layout'});
      expect(await ApiClient().getRefreshToken(), isNull);
    });

    test('contraseña incorrecta: no renueva, no cierra la sesión y no borra nada', () async {
      await _signedIn();
      final paths = <String>[];
      ApiClient().httpClientForTesting = MockClient((req) async {
        paths.add(req.url.path);
        return _json({'error': 'La contraseña no es correcta.', 'code': 'INVALID_PASSWORD'},
            401);
      });
      await expectLater(
        AccountService().deleteAccount('incorrecta'),
        throwsA(isA<ApiException>()
            .having((e) => e.isInvalidPassword, 'isInvalidPassword', isTrue)),
      );
      expect(paths, [endsWith('/account')]); // sin /auth/refresh
      expect(await ApiClient().getRefreshToken(), 'refresh-1');
      expect(await _prefsKeys(), containsAll(<String>[ApiClient.userDataKey, ..._deviceData.keys]));
    });

    test('error del servidor: el teléfono queda intacto (la cuenta sigue existiendo)', () async {
      await _signedIn();
      ApiClient().httpClientForTesting = MockClient(
          (_) async => _json({'error': 'Error interno', 'code': 'INTERNAL_ERROR'}, 500));
      await expectLater(AccountService().deleteAccount('password123'),
          throwsA(isA<ApiException>()));
      expect(await ApiClient().getRefreshToken(), 'refresh-1');
      expect(await _prefsKeys(), containsAll(_deviceData.keys));
    });
  });

  group('Pantalla Eliminar mi cuenta', () {
    testWidgets('explica qué se borra y ofrece desactivar si la cuenta está activa',
        (tester) async {
      await _signedIn();
      await _openScreen(tester);

      expect(find.text('Eliminar tu cuenta para siempre'), findsOneWidget);
      expect(find.textContaining('No se puede deshacer'), findsOneWidget);
      expect(find.textContaining('Tus lecturas, reseñas y notas'), findsOneWidget);
      expect(find.textContaining('Los libros del catálogo no se borran'), findsOneWidget);
      expect(find.text('¿Solo quieres un descanso?'), findsOneWidget);

      // El enlace lleva a desactivar (reemplazando esta pantalla).
      ApiClient().httpClientForTesting = MockClient((_) async =>
          _json({'status': 'active', 'public_readings': 1, 'restorable_readings': 0}, 200));
      await tester.ensureVisible(find.widgetWithText(TextButton, 'Desactivar mi cuenta'));
      await tester.tap(find.widgetWithText(TextButton, 'Desactivar mi cuenta'));
      await _settle(tester);
      expect(find.byType(DeactivateAccountScreen), findsOneWidget);
      expect(find.byType(DeleteAccountScreen), findsNothing);
    });

    testWidgets('con la cuenta desactivada no ofrece desactivar', (tester) async {
      await _signedIn(status: 'deactivated');
      await _openScreen(tester);
      expect(find.text('¿Solo quieres un descanso?'), findsNothing);
      expect(_deleteButton, findsOneWidget);
    });

    testWidgets('el botón destructivo usa el color danger del tema', (tester) async {
      await _signedIn();
      await _openScreen(tester);
      final button = tester.widget<FilledButton>(_deleteButton);
      final c = ThemeService.palettes['light']!.colors;
      expect(button.style!.backgroundColor!.resolve({}), c.danger);
      expect(button.style!.foregroundColor!.resolve({}), c.onInk);
    });

    testWidgets(
        'sin contraseña no llama; incorrecta → error junto al campo y sesión intacta; '
        'cancelar no borra', (tester) async {
      await _signedIn();
      final requests = <String>[];
      ApiClient().httpClientForTesting = MockClient((req) async {
        requests.add('${req.method} ${req.url.path}');
        return _json({'error': 'La contraseña no es correcta.', 'code': 'INVALID_PASSWORD'},
            401);
      });
      await _openScreen(tester);

      await tester.ensureVisible(_deleteButton);
      await tester.tap(_deleteButton);
      await tester.pumpAndSettle();
      expect(find.text('Escribe tu contraseña para confirmar'), findsOneWidget);
      expect(find.text('¿Eliminar tu cuenta para siempre?'), findsNothing);

      // Cancelar la confirmación: no se envía nada.
      await tester.enterText(find.byType(TextField), 'mala1234');
      await tester.ensureVisible(_deleteButton);
      await tester.tap(_deleteButton);
      await tester.pumpAndSettle();
      expect(find.text('¿Eliminar tu cuenta para siempre?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(requests, isEmpty);

      // Confirmar con la contraseña incorrecta.
      await tester.ensureVisible(_deleteButton);
      await tester.tap(_deleteButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar para siempre'));
      await _settle(tester);

      expect(requests, ['DELETE ${_apiPrefix()}/account']);
      expect(find.text('La contraseña no es correcta'), findsOneWidget);
      expect(find.byType(DeleteAccountScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(await ApiClient().getRefreshToken(), 'refresh-1');
      expect(await _prefsKeys(), containsAll(_deviceData.keys));
      // Lo escrito se conserva para corregirlo.
      expect(find.text('mala1234'), findsOneWidget);
    });

    testWidgets('eliminar: limpia el teléfono y vuelve a Login con el aviso', (tester) async {
      await _signedIn();
      ApiClient().httpClientForTesting =
          MockClient((_) async => _json({'deleted': true}, 200));
      await _openScreen(tester);

      await tester.enterText(find.byType(TextField), 'buena123');
      await tester.ensureVisible(_deleteButton);
      await tester.tap(_deleteButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar para siempre'));
      await _settle(tester);

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(DeleteAccountScreen), findsNothing);
      expect(find.text('abrir'), findsNothing); // la pila anterior ya no existe
      expect(find.text(accountDeletedMessage), findsOneWidget);
      expect(await _prefsKeys(), {'app_theme', 'feed_layout'});
      expect(await ApiClient().getToken(), isNull);
    });

    testWidgets('el modo solo lectura (cuenta desactivada) ofrece eliminar la cuenta',
        (tester) async {
      await _signedIn(status: 'deactivated');
      ApiClient().httpClientForTesting = MockClient((req) async =>
          req.url.path.endsWith('/account/status')
              ? _json({'status': 'deactivated', 'public_readings': 0, 'restorable_readings': 0},
                  200)
              : _json(<dynamic>[], 200));
      await tester.pumpWidget(MaterialApp(
        navigatorKey: Config.navigatorKey,
        theme: _testTheme(),
        home: const DeactivatedScreen(),
      ));
      await _settle(tester);

      final entry = find.widgetWithText(TextButton, 'Eliminar mi cuenta');
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await _settle(tester);
      expect(find.byType(DeleteAccountScreen), findsOneWidget);
      expect(find.text('¿Solo quieres un descanso?'), findsNothing);
    });
  });
}

/// Prefijo de ruta de `Config.baseUrl` (p. ej. `/api`), para comparar rutas completas.
String _apiPrefix() => Uri.parse(Config.baseUrl).path;
