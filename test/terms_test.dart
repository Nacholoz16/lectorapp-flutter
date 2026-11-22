import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_lectorapp/services/api_client.dart';
import 'package:test_lectorapp/services/auth_service.dart';
import 'package:test_lectorapp/services/terms_service.dart';
import 'package:test_lectorapp/services/theme_service.dart';
import 'package:test_lectorapp/widgets/terms_acceptance.dart';

/// Tarea 1.3: aceptación de Términos y Política de privacidad.

ThemeData _testTheme() =>
    ThemeData(extensions: [ThemeService.palettes['light']!.colors]);

Future<Map<String, dynamic>?> _userData() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(ApiClient.userDataKey);
  return raw == null ? null : json.decode(raw) as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TermsService.needsTermsFrom', () {
    test('usa needs_terms si viene (tolerante a 1/0 y strings)', () {
      expect(TermsService.needsTermsFrom({'needs_terms': true}), isTrue);
      expect(TermsService.needsTermsFrom({'needs_terms': false}), isFalse);
      expect(TermsService.needsTermsFrom({'needs_terms': 1}), isTrue);
      expect(TermsService.needsTermsFrom({'needs_terms': '0'}), isFalse);
    });

    test('sin needs_terms compara la versión aceptada con la vigente', () {
      expect(
          TermsService.needsTermsFrom(
              {'terms_version': '2026-11', 'current_terms_version': '2026-11'}),
          isFalse);
      expect(
          TermsService.needsTermsFrom(
              {'terms_version': null, 'current_terms_version': '2026-11'}),
          isTrue);
      expect(
          TermsService.needsTermsFrom(
              {'terms_version': '2025-01', 'current_terms_version': '2026-11'}),
          isTrue);
    });

    test('sin información (sesión 1.0.0, perfil ajeno) → null: decide la API',
        () {
      expect(TermsService.needsTermsFrom(null), isNull);
      expect(TermsService.needsTermsFrom({'id': 1, 'username': 'ana'}), isNull);
      expect(TermsService.needsTermsFrom({'needs_terms': null}), isNull);
      expect(
          TermsService.needsTermsFrom({'current_terms_version': ''}), isNull);
    });

    test('pickFields solo copia los campos de términos presentes', () {
      expect(
        TermsService.pickFields({
          'id': 1,
          'email': 'ana@x.com',
          'terms_version': null,
          'needs_terms': true,
        }),
        {'terms_version': null, 'needs_terms': true},
      );
    });
  });

  group('ApiException con código', () {
    test('extractErrorCode lee `code` y tolera cuerpos no JSON', () {
      expect(
          ApiClient.extractErrorCode(
              '{"error":"Para publicar","code":"TERMS_REQUIRED"}'),
          'TERMS_REQUIRED');
      expect(ApiClient.extractErrorCode('<html>502</html>'), isNull);
      expect(ApiClient.extractErrorCode('{"error":"x"}'), isNull);
    });

    test('isTermsRequired solo con 403 + TERMS_REQUIRED', () {
      expect(
          ApiException('x', statusCode: 403, code: 'TERMS_REQUIRED')
              .isTermsRequired,
          isTrue);
      expect(
          ApiException('x', statusCode: 403, code: 'FORBIDDEN').isTermsRequired,
          isFalse);
      expect(
          ApiException('x', statusCode: 400, code: 'TERMS_REQUIRED')
              .isTermsRequired,
          isFalse);
    });

    test('un 403 TERMS_REQUIRED de la API llega con su código', () async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      await ApiClient().loadToken();
      ApiClient().httpClientForTesting = MockClient((_) async => http.Response(
          json.encode({'error': 'Para publicar', 'code': 'TERMS_REQUIRED'}),
          403));
      await expectLater(
        ApiClient().post('/readings', body: {}),
        throwsA(isA<ApiException>()
            .having((e) => e.isTermsRequired, 'isTermsRequired', isTrue)),
      );
    });
  });

  group('Estado local de los términos (user-data)', () {
    late List<http.Request> requests;

    setUp(() async {
      requests = [];
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({
        ApiClient.userDataKey:
            json.encode({'id': 7, 'username': 'ana', 'avatar': null}),
      });
      await ApiClient().loadToken();
    });

    test('sesión de la 1.0.0 (sin campos) → needsAcceptance null', () async {
      expect(await TermsService().needsAcceptance(), isNull);
    });

    test(
        'saveStatusFrom guarda lo que trae el perfil propio y conserva el usuario',
        () async {
      await TermsService().saveStatusFrom({
        'username': 'ana',
        'library': <dynamic>[],
        'terms_version': null,
        'current_terms_version': '2026-11',
        'needs_terms': true,
      });
      expect(await TermsService().needsAcceptance(), isTrue);
      final data = await _userData();
      expect(data!['username'], 'ana');
      expect(data.containsKey('library'), isFalse);
    });

    test('saveStatusFrom ignora respuestas sin información de términos',
        () async {
      await TermsService().saveStatusFrom({'username': 'ana'});
      expect((await _userData())!.keys,
          unorderedEquals(['id', 'username', 'avatar']));
    });

    test('markAcceptanceNeeded (tras un 403) marca que falta aceptar',
        () async {
      await TermsService().saveStatusFrom({'needs_terms': false});
      await TermsService().markAcceptanceNeeded();
      expect(await TermsService().needsAcceptance(), isTrue);
    });

    test('accept() llama a POST /account/terms y guarda needs_terms: false',
        () async {
      await TermsService().markAcceptanceNeeded();
      ApiClient().httpClientForTesting = MockClient((req) async {
        requests.add(req);
        return http.Response(
            json.encode({
              'terms_version': '2026-11',
              'current_terms_version': '2026-11',
              'needs_terms': false,
              'terms_accepted_at': '2026-11-22T10:00:00.000Z',
            }),
            200);
      });
      await TermsService().accept();
      expect(requests.single.method, 'POST');
      expect(requests.single.url.path, endsWith('/account/terms'));
      expect(await TermsService().needsAcceptance(), isFalse);
      expect((await _userData())!['terms_version'], '2026-11');
    });

    test('accept() con error de la API no cambia el estado local', () async {
      await TermsService().markAcceptanceNeeded();
      ApiClient().httpClientForTesting = MockClient((_) async =>
          http.Response(json.encode({'error': 'Algo salió mal'}), 500));
      await expectLater(TermsService().accept(), throwsA(isA<ApiException>()));
      expect(await TermsService().needsAcceptance(), isTrue);
    });

    test('sin sesión guardada no se crea user-data', () async {
      SharedPreferences.setMockInitialValues({});
      await TermsService().markAcceptanceNeeded();
      expect(await _userData(), isNull);
    });

    test('registro envía accept_terms y guarda el estado de los términos',
        () async {
      SharedPreferences.setMockInitialValues({});
      ApiClient().httpClientForTesting = MockClient((req) async {
        requests.add(req);
        return http.Response(
            json.encode({
              'token': 'a.b.c',
              'refresh_token': 'refresh-token-de-prueba',
              'user': {
                'id': 9,
                'username': 'ana',
                'email': 'ana@x.com',
                'terms_version': '2026-11',
                'current_terms_version': '2026-11',
                'needs_terms': false,
              },
            }),
            201);
      });
      await AuthService()
          .register('ana', 'ana@x.com', 'password123', acceptedTerms: true);
      final body = json.decode(requests.single.body) as Map<String, dynamic>;
      expect(body['accept_terms'], isTrue);
      final data = await _userData();
      expect(data!['needs_terms'], isFalse);
      expect(
          data.containsKey('email'), isFalse); // el email sigue sin guardarse
    });
  });

  group('TermsCheckbox', () {
    testWidgets('empieza sin marcar; tocar el texto la marca; muestra el error',
        (tester) async {
      final handle = tester.ensureSemantics();
      var value = false;
      await tester.pumpWidget(MaterialApp(
        theme: _testTheme(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => TermsCheckbox(
              value: value,
              errorText: value ? null : 'Acepta para continuar',
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      ));

      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
      expect(find.text('Acepta para continuar'), findsOneWidget);
      expect(find.text('Términos y condiciones'), findsOneWidget);
      expect(find.text('Política de privacidad'), findsOneWidget);

      await tester
          .tap(find.text('Acepto los Términos y la Política de privacidad'));
      await tester.pump();
      expect(value, isTrue);
      expect(find.text('Acepta para continuar'), findsNothing);

      // Los enlaces se anuncian como enlaces y todo cumple 48 dp con etiqueta.
      expect(
        tester.getSemantics(find.text('Términos y condiciones')),
        matchesSemantics(
          isLink: true,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
          label: 'Términos y condiciones',
          hint: 'Se abre en el navegador',
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });

  group('Hoja "Antes de compartir…"', () {
    Future<TermsSheetResult?> openSheetAndTap(
        WidgetTester tester, String button) async {
      TermsSheetResult? result;
      await tester.pumpWidget(MaterialApp(
        theme: _testTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showTermsSheet(context),
              child: const Text('abrir'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(find.text('Antes de compartir…'), findsOneWidget);
      await tester.tap(find.text(button));
      await tester.pumpAndSettle();
      return result;
    }

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({
        ApiClient.userDataKey:
            json.encode({'id': 7, 'username': 'ana', 'needs_terms': true}),
      });
      await ApiClient().loadToken();
    });

    testWidgets('"Ahora no" no acepta nada', (tester) async {
      ApiClient().httpClientForTesting =
          MockClient((_) async => fail('no debe llamar a la API'));
      expect(await openSheetAndTap(tester, 'Ahora no'),
          TermsSheetResult.dismissed);
    });

    testWidgets('"Guardar solo para mí" no acepta y pide guardar en privado',
        (tester) async {
      ApiClient().httpClientForTesting =
          MockClient((_) async => fail('no debe llamar a la API'));
      expect(await openSheetAndTap(tester, 'Guardar solo para mí'),
          TermsSheetResult.savePrivately);
    });

    testWidgets('"Aceptar y publicar" registra la aceptación en la API',
        (tester) async {
      var calls = 0;
      ApiClient().httpClientForTesting = MockClient((req) async {
        calls++;
        return http.Response(
            json.encode({'terms_version': '2026-11', 'needs_terms': false}),
            200);
      });
      TermsSheetResult? sheetResult;
      await tester.pumpWidget(MaterialApp(
        theme: _testTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  sheetResult = await showTermsSheet(context),
              child: const Text('abrir'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aceptar y publicar'));
      // La petición y SharedPreferences son asíncronas reales: dejar que terminen.
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(sheetResult, TermsSheetResult.accepted);
    });

    testWidgets('si la API falla, la hoja sigue abierta con un mensaje',
        (tester) async {
      ApiClient().httpClientForTesting = MockClient((_) async => http.Response(
          json.encode({'error': 'Algo salió mal en el servidor'}), 500));
      await tester.pumpWidget(MaterialApp(
        theme: _testTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showTermsSheet(context),
              child: const Text('abrir'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aceptar y publicar'));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
      expect(find.text('Antes de compartir…'), findsOneWidget);
      expect(find.text('Algo salió mal en el servidor'), findsOneWidget);
    });
    testWidgets('mientras se acepta no se puede cerrar (atrás ni tocar fuera)',
        (tester) async {
      final response = Completer<http.Response>();
      ApiClient().httpClientForTesting = MockClient((_) => response.future);
      TermsSheetResult? sheetResult;
      await tester.pumpWidget(MaterialApp(
        theme: _testTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  sheetResult = await showTermsSheet(context),
              child: const Text('abrir'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(find.textContaining('aceptas los Términos y condiciones'),
          findsOneWidget);

      await tester.tap(find.text('Aceptar y publicar'));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();

      // Atrás del sistema y toque fuera de la hoja: sigue abierta.
      await tester.binding.handlePopRoute();
      await tester.tapAt(const Offset(10, 10));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Antes de compartir…'), findsOneWidget);
      expect(sheetResult, isNull);

      response
          .complete(http.Response(json.encode({'needs_terms': false}), 200));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
      expect(sheetResult, TermsSheetResult.accepted);
    });
  });
}
