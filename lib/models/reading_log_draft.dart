import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Estado completo del formulario de una lectura (crear o editar).
///
/// Se usa para dos cosas:
/// 1. Saber si hay cambios sin guardar (comparando con el estado inicial).
/// 2. Guardar un **borrador local** para que nada de lo escrito se pierda si se cierra la hoja,
///    se cae la app o falla la red (ver skill `lectorapp-ux-patterns` §3).
@immutable
class ReadingLogDraft {
  final String status;
  final int rating;
  final String currentPage;
  final String review;
  final bool isPublic;
  final DateTime? startDate;
  final DateTime? endDate;

  const ReadingLogDraft({
    required this.status,
    required this.rating,
    required this.currentPage,
    required this.review,
    required this.isPublic,
    this.startDate,
    this.endDate,
  });

  Map<String, dynamic> toJson() => {
        'status': status,
        'rating': rating,
        'current_page': currentPage,
        'review': review,
        'is_public': isPublic,
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
      };

  factory ReadingLogDraft.fromJson(Map<String, dynamic> json) => ReadingLogDraft(
        status: json['status'] as String? ?? 'leyendo',
        rating: (json['rating'] as num?)?.toInt() ?? 0,
        currentPage: json['current_page'] as String? ?? '0',
        review: json['review'] as String? ?? '',
        isPublic: json['is_public'] as bool? ?? false,
        startDate: DateTime.tryParse(json['start_date'] as String? ?? ''),
        endDate: DateTime.tryParse(json['end_date'] as String? ?? ''),
      );

  static bool _sameDay(DateTime? a, DateTime? b) =>
      (a == null && b == null) ||
      (a != null &&
          b != null &&
          a.year == b.year &&
          a.month == b.month &&
          a.day == b.day);

  @override
  bool operator ==(Object other) =>
      other is ReadingLogDraft &&
      other.status == status &&
      other.rating == rating &&
      (int.tryParse(other.currentPage) ?? 0) == (int.tryParse(currentPage) ?? 0) &&
      other.review.trim() == review.trim() &&
      other.isPublic == isPublic &&
      _sameDay(other.startDate, startDate) &&
      _sameDay(other.endDate, endDate);

  @override
  int get hashCode => Object.hash(status, rating, int.tryParse(currentPage) ?? 0,
      review.trim(), isPublic, startDate?.day, endDate?.day);
}

/// Persistencia de borradores en el teléfono (SharedPreferences), uno por libro o registro.
class ReadingLogDraftStore {
  ReadingLogDraftStore._();

  static String _key(String id) => 'reading_draft_$id';

  static Future<ReadingLogDraft?> load(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(id));
      if (raw == null) return null;
      return ReadingLogDraft.fromJson(json.decode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null; // Un borrador corrupto no debe impedir abrir el formulario.
    }
  }

  static Future<void> save(String id, ReadingLogDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(id), json.encode(draft.toJson()));
  }

  static Future<void> clear(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(id));
  }
}
