/// Modelo tipado para un registro de lectura (reading log).
class ReadingLog {
  final int? id;
  final String? title;
  final String? authors;
  final String? coverUrl;
  final String? externalId;
  final String status;
  final int? rating;
  final String? reviewText;
  final DateTime? startDate;
  final DateTime? finishDate;
  final int? durationDays;
  final bool isLogPublic;
  final String? username;
  final String? avatarUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? pageCount;
  final String? isbn;
  final int? publishedYear;
  final int likesCount;
  final bool hasLiked;
  final int currentPage;

  const ReadingLog({
    this.id,
    this.title,
    this.authors,
    this.coverUrl,
    this.externalId,
    this.status = 'leyendo',
    this.rating,
    this.reviewText,
    this.startDate,
    this.finishDate,
    this.durationDays,
    this.isLogPublic = false,
    this.username,
    this.avatarUrl,
    this.createdAt,
    this.updatedAt,
    this.pageCount,
    this.isbn,
    this.publishedYear,
    this.likesCount = 0,
    this.hasLiked = false,
    this.currentPage = 0,
  });

  /// Crea un ReadingLog desde un Map (respuesta de API).
  factory ReadingLog.fromJson(Map<String, dynamic> json) {
    return ReadingLog(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      title: json['title'],
      authors: json['authors'] ?? json['author'],
      coverUrl: json['cover_url'] ?? json['cover_image'],
      externalId: json['external_id']?.toString(),
      status: json['status'] ?? 'leyendo',
      rating: json['rating'] is int
          ? json['rating']
          : (json['rating'] as num?)?.toInt(),
      reviewText: json['review_text'],
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'].toString())
          : null,
      finishDate: json['finish_date'] != null
          ? DateTime.tryParse(json['finish_date'].toString())
          : null,
      durationDays: json['duration_days'] is int
          ? json['duration_days']
          : int.tryParse(json['duration_days']?.toString() ?? ''),
      isLogPublic:
          json['is_log_public'] == true || json['is_log_public'] == 1,
      username: json['username'],
      avatarUrl: json['avatar_url'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      pageCount: json['page_count'] is int
          ? json['page_count']
          : int.tryParse(json['page_count']?.toString() ?? ''),
      isbn: json['isbn']?.toString(),
      publishedYear: json['published_year'] is int
          ? json['published_year']
          : int.tryParse(json['published_year']?.toString() ?? ''),
      likesCount: json['likes_count'] is int
          ? json['likes_count']
          : int.tryParse(json['likes_count']?.toString() ?? '') ?? 0,
      hasLiked: json['has_liked'] == true || json['has_liked'] == 1,
      currentPage: json['current_page'] is int
          ? json['current_page']
          : int.tryParse(json['current_page']?.toString() ?? '') ?? 0,
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

  /// Convierte a Map para enviar a la API (update/create payload).
  Map<String, dynamic> toLogPayload() {
    return {
      'status': status,
      'rating': rating != null && rating! > 0 ? rating : null,
      'review_text': reviewText ?? '',
      'start_date': startDate?.toIso8601String().split('T').first,
      'finish_date': finishDate?.toIso8601String().split('T').first,
      'is_log_public': isLogPublic,
      'current_page': currentPage,
    };
  }
}
