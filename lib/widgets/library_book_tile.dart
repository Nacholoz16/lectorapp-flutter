import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../book_cover.dart';
import '../models/reading_log.dart';
import '../theme/lector_colors.dart';
import 'book_stats_modal.dart';
import 'edit_book_modal.dart';
import 'status_chip.dart';

/// Fila de un libro en "Mi biblioteca": portada, título, autor, estado y progreso.
/// Tocarla abre la edición; el ícono de barras, las estadísticas de ese libro.
class LibraryBookTile extends StatelessWidget {
  final ReadingLog log;

  const LibraryBookTile({super.key, required this.log});

  Map<String, dynamic> get _logMap => {
        'id': log.id,
        'title': log.title,
        'author': log.authors,
        'authors': log.authors,
        'cover_url': log.coverUrl,
        'cover_image': log.coverUrl,
        'external_id': log.externalId,
        'status': log.status,
        'rating': log.rating,
        'review_text': log.reviewText,
        'start_date': log.startDate?.toIso8601String(),
        'finish_date': log.finishDate?.toIso8601String(),
        'is_log_public': log.isLogPublic,
        'page_count': log.pageCount,
        'isbn': log.isbn,
        'published_year': log.publishedYear,
        'current_page': log.currentPage,
      };

  Future<void> _openEdit(BuildContext context) => showModalBottomSheet<Object?>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => EditBookModal(readingLog: _logMap),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.lector;
    final isReading = log.status.toLowerCase() == 'leyendo';
    final pages = log.pageCount ?? 0;
    final progress =
        pages > 0 ? (log.currentPage / pages).clamp(0.0, 1.0) : 0.0;
    final percentage = (progress * 100).round();

    final spoken = <String>[
      '«${log.title ?? ''}»',
      if ((log.authors ?? '').isNotEmpty) 'de ${log.authors}',
      statusLabel(log.status),
      if (isReading && pages > 0) 'página ${log.currentPage} de $pages',
      if (!isReading && log.rating != null) '${log.rating} de 5 estrellas',
      if (!log.isLogPublic) 'privado',
    ].join(', ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: spoken,
            hint: 'Editar lectura',
            excludeSemantics: true,
            child: InkWell(
              onTap: () => _openEdit(context),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 4, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 54,
                      height: 81,
                      child: BookCover(
                        src: log.coverUrl,
                        title: log.title ?? '',
                        author: log.authors ?? '',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            log.title ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.lora(
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                              height: 1.2,
                              color: c.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(log.authors ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 13, color: c.textSecondary)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              StatusChip(status: log.status),
                              if (!isReading && log.rating != null) ...[
                                const SizedBox(width: 10),
                                Icon(Icons.star_rounded,
                                    color: c.star, size: 18),
                                Text(' ${log.rating}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: c.textSecondary)),
                              ],
                              if (!log.isLogPublic) ...[
                                const SizedBox(width: 10),
                                Icon(Icons.lock_outline_rounded,
                                    size: 16, color: c.iconInactive),
                              ],
                            ],
                          ),
                          if (isReading) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                        value: progress, minHeight: 5),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  pages > 0
                                      ? '$percentage %'
                                      : 'Pág. ${log.currentPage}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: c.ink),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Fuera del Semantics agrupado: acción propia para TalkBack.
        Padding(
          padding: const EdgeInsets.only(top: 8, right: 8),
          child: IconButton(
            icon: Icon(Icons.bar_chart_rounded, color: c.ink),
            tooltip: 'Estadísticas de «${log.title ?? 'este libro'}»',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => BookStatsModal(readingLog: _logMap),
            ),
          ),
        ),
      ],
    );
  }
}
