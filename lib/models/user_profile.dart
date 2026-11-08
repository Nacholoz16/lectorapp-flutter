import '../utils/json_utils.dart';
import 'reading_log.dart';

/// Modelo tipado para el perfil de un usuario.
class UserProfile {
  final String username;
  final String? bio;
  final String? avatarUrl;
  final bool isProfilePublic;
  final bool areStatsPublic;
  final bool isOwnProfile;
  final bool isPrivateLock;
  final List<ReadingLog> library;

  const UserProfile({
    required this.username,
    this.bio,
    this.avatarUrl,
    this.isProfilePublic = true,
    this.areStatsPublic = true,
    this.isOwnProfile = false,
    this.isPrivateLock = false,
    this.library = const [],
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawLibrary = json['library'] as List<dynamic>? ?? [];
    return UserProfile(
      username: json['username'] ?? '',
      bio: json['bio'],
      avatarUrl: json['avatar_url'],
      isProfilePublic: asBool(json['is_profile_public']),
      areStatsPublic: asBool(json['are_stats_public'], fallback: true),
      isOwnProfile: asBool(json['is_own_profile']),
      isPrivateLock: asBool(json['is_private_lock']),
      library: rawLibrary
          .map((item) => ReadingLog.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  /// URL del avatar normalizada (svg → png).
  String get safeAvatarUrl {
    String url = avatarUrl ??
        'https://api.dicebear.com/7.x/bottts/png?seed=$username';
    if (url.contains('/svg')) {
      url = url.replaceAll('/svg', '/png');
    }
    return url;
  }
}
