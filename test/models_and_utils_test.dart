import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_lectorapp/models/reading_log.dart';
import 'package:test_lectorapp/models/user_profile.dart';
import 'package:test_lectorapp/services/api_client.dart';
import 'package:test_lectorapp/services/auth_service.dart';
import 'package:test_lectorapp/utils/json_utils.dart';

/// Construye un JWT sin firma válida (la app solo decodifica el payload para mirar `exp`).
String fakeJwt(Map<String, dynamic> payload) {
  String enc(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(json.encode(m))).replaceAll('=', '');
  return '${enc({'alg': 'HS256', 'typ': 'JWT'})}.${enc(payload)}.firma';
}

void main() {
  group('asBool', () {
    test('acepta bool, 1/0 y strings', () {
      expect(asBool(true), isTrue);
      expect(asBool(1), isTrue);
      expect(asBool('1'), isTrue);
      expect(asBool('true'), isTrue);
      expect(asBool(false), isFalse);
      expect(asBool(0), isFalse);
      expect(asBool('0'), isFalse);
    });

    test('usa el fallback si el valor es null', () {
      expect(asBool(null), isFalse);
      expect(asBool(null, fallback: true), isTrue);
    });
  });

  group('UserProfile.fromJson', () {
    test('no falla si los booleanos llegan como 1/0 desde MySQL', () {
      final profile = UserProfile.fromJson({
        'username': 'ana',
        'is_profile_public': 1,
        'are_stats_public': 0,
        'is_own_profile': 1,
        'is_private_lock': 0,
        'library': [],
      });
      expect(profile.isProfilePublic, isTrue);
      expect(profile.areStatsPublic, isFalse);
      expect(profile.isOwnProfile, isTrue);
      expect(profile.isPrivateLock, isFalse);
    });

    test('are_stats_public ausente → true por defecto', () {
      final profile = UserProfile.fromJson({'username': 'ana'});
      expect(profile.areStatsPublic, isTrue);
    });

    test('convierte avatares DiceBear SVG a PNG', () {
      final profile = UserProfile.fromJson({
        'username': 'ana',
        'avatar_url': 'https://api.dicebear.com/7.x/bottts/svg?seed=ana',
      });
      expect(profile.safeAvatarUrl, contains('/png'));
      expect(profile.safeAvatarUrl, isNot(contains('/svg')));
    });
  });

  group('ReadingLog.fromJson', () {
    test('normaliza author/authors, likes y has_liked', () {
      final log = ReadingLog.fromJson({
        'id': '7',
        'author': 'Autora',
        'likes_count': '3',
        'has_liked': 1,
        'is_log_public': 1,
      });
      expect(log.id, 7);
      expect(log.authors, 'Autora');
      expect(log.likesCount, 3);
      expect(log.hasLiked, isTrue);
      expect(log.isLogPublic, isTrue);
    });
  });

  group('AuthService.isJwtValid', () {
    test('token no expirado → válido', () {
      final exp = DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000;
      expect(AuthService.isJwtValid(fakeJwt({'id': 1, 'exp': exp})), isTrue);
    });

    test('token expirado → inválido', () {
      final exp = DateTime.now().subtract(const Duration(minutes: 1)).millisecondsSinceEpoch ~/ 1000;
      expect(AuthService.isJwtValid(fakeJwt({'id': 1, 'exp': exp})), isFalse);
    });

    test('basura, null o sin exp → inválido', () {
      expect(AuthService.isJwtValid(null), isFalse);
      expect(AuthService.isJwtValid(''), isFalse);
      expect(AuthService.isJwtValid('no.es.jwt'), isFalse);
      expect(AuthService.isJwtValid(fakeJwt({'id': 1})), isFalse);
    });
  });

  group('ApiClient.extractErrorMessage', () {
    test('lee { error } del backend', () {
      expect(
        ApiClient.extractErrorMessage(401, '{"error":"Credenciales inválidas","code":"UNAUTHORIZED"}'),
        'Credenciales inválidas',
      );
    });

    test('acepta { message } (formato antiguo)', () {
      expect(ApiClient.extractErrorMessage(400, '{"message":"Algo falló"}'), 'Algo falló');
    });

    test('HTML de Nginx en un 502 → mensaje genérico, sin FormatException', () {
      expect(
        ApiClient.extractErrorMessage(502, '<html><body>Bad Gateway</body></html>'),
        'El servidor no está disponible. Intenta más tarde.',
      );
    });

    test('4xx sin cuerpo → "Error <código>"', () {
      expect(ApiClient.extractErrorMessage(404, ''), 'Error 404');
    });
  });
}
