/// Modelo tipado para un libro.
/// Normaliza la discrepancia `author`/`authors` del backend.
class Book {
  final String? externalId;
  final String title;
  final String authors;
  final String? coverUrl;
  final String? isbn;
  final int? pageCount;
  final int? publishedYear;
  final bool isLocal;

  const Book({
    this.externalId,
    this.title = '',
    this.authors = 'Desconocido',
    this.coverUrl,
    this.isbn,
    this.pageCount,
    this.publishedYear,
    this.isLocal = false,
  });

  /// Crea un Book desde un Map (respuesta de API).
  /// Maneja ambas variantes: `author` y `authors`.
  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      externalId:
          (json['external_id'] ?? json['google_id'] ?? json['id'])?.toString(),
      title: json['title'] ?? '',
      authors: json['authors'] ?? json['author'] ?? 'Desconocido',
      coverUrl: json['cover_url'] ?? json['cover_image'],
      isbn: json['isbn']?.toString(),
      pageCount: json['page_count'] is int
          ? json['page_count']
          : int.tryParse(json['page_count']?.toString() ?? ''),
      publishedYear: json['published_year'] is int
          ? json['published_year']
          : int.tryParse(json['published_year']?.toString() ?? ''),
      isLocal: json['is_local'] == true,
    );
  }

  /// Convierte a Map para enviar a la API.
  Map<String, dynamic> toJson() {
    return {
      'external_id': externalId,
      'title': title,
      'authors': authors,
      'cover_url': coverUrl,
      'isbn': isbn,
      'page_count': pageCount,
      'published_year': publishedYear,
    };
  }
}
