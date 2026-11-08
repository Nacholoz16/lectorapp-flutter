import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:test_lectorapp/book_cover.dart';
import 'package:test_lectorapp/utils/json_utils.dart';
import '../theme/lector_colors.dart';
import 'status_chip.dart';

/// Tarjeta de una lectura en el feed (`mode: 'feed'`) o en la lista de reseñas de un libro
/// (`mode: 'review'`).
///
/// Accesibilidad: TalkBack la recorre en 4 paradas con sentido — autor (abre su perfil),
/// pensamientos, libro (abre el detalle) y acciones — en vez de una docena de fragmentos.
class UserCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String mode; // 'feed' o 'review'
  final VoidCallback? onBookClick;
  final VoidCallback? onLikeClick;
  final VoidCallback? onUserClick;

  const UserCard({
    super.key,
    required this.item,
    this.mode = 'feed',
    this.onBookClick,
    this.onLikeClick,
    this.onUserClick,
  });

  String get _title => (item['title'] ?? item['book']?['title'] ?? 'Sin título').toString();
  String get _author =>
      (item['author'] ?? item['authors'] ?? item['book']?['authors'] ?? '').toString();
  String get _username => (item['username'] ?? 'Usuario').toString();
  String? get _status => item['status']?.toString();
  String get _review => (item['review_text'] ?? '').toString().trim();
  int get _rating => asInt(item['rating']);

  Future<void> _share() async {
    final bookId = item['external_id'] ??
        item['book']?['external_id'] ??
        item['google_id'] ??
        item['book']?['google_id'];
    final url = bookId != null ? 'https://nacholoz3d.cl/libro/$bookId' : 'https://nacholoz3d.cl';
    final by = _author.isNotEmpty ? ' de $_author' : '';
    await Share.share('Mira «$_title»$by en LectorApp: $url', subject: _title);
  }

  /// "terminó", "está leyendo"... para la frase que lee TalkBack.
  static String _verb(String? status) {
    switch (status) {
      case 'terminado':
        return 'terminó';
      case 'abandonado':
        return 'dejó';
      case 'leyendo':
        return 'está leyendo';
      default:
        return 'registró';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lector;
    final cardColor = Theme.of(context).cardColor;
    final hasLiked = asBool(item['has_liked']);
    final likes = asInt(item['likes_count']);
    final date = DateTime.tryParse(item['created_at'] ?? '')?.toLocal() ?? DateTime.now();
    final shortDate = DateFormat('d MMM', 'es').format(date);
    final longDate = DateFormat("d 'de' MMMM", 'es').format(date);

    String avatarUrl = item['avatar_url'] ??
        'https://api.dicebear.com/7.x/bottts/png?seed=${item['username']}';
    if (avatarUrl.contains('/svg')) {
      avatarUrl = avatarUrl.replaceAll('/svg', '/png');
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: Theme.of(context).brightness == Brightness.dark
            ? null
            : [
                BoxShadow(
                  color: c.accent.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AUTOR: avatar + nombre + fecha + estado (un solo botón → perfil)
            Semantics(
              button: onUserClick != null,
              label: mode == 'feed' && _status != null
                  ? '$_username ${_verb(_status)} «$_title», el $longDate'
                  : '$_username, el $longDate',
              hint: onUserClick != null ? 'Ver perfil' : null,
              excludeSemantics: true,
              child: InkWell(
                onTap: onUserClick,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundImage: CachedNetworkImageProvider(avatarUrl),
                        backgroundColor: c.accent.withValues(alpha: 0.15),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              children: [
                                Text(
                                  _username,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: c.textPrimary,
                                  ),
                                ),
                                Text(
                                  shortDate,
                                  style: TextStyle(color: c.textSecondary, fontSize: 13),
                                ),
                              ],
                            ),
                            if (mode == 'feed' && _status != null) ...[
                              const SizedBox(height: 6),
                              StatusChip(status: _status),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // PENSAMIENTOS (sin comillas ni cursiva: los bloques en cursiva cansan)
            if (_review.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Container(
                  padding: const EdgeInsets.only(left: 14),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: c.accent.withValues(alpha: 0.7), width: 3),
                    ),
                  ),
                  child: Text(
                    _review,
                    style: TextStyle(fontSize: 15.5, height: 1.55, color: c.textPrimary),
                  ),
                ),
              ),

            // LIBRO (solo feed) → detalle
            if (mode == 'feed') _buildBookEmbed(context, c),

            // ACCIONES
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
              child: Row(
                children: [
                  Semantics(
                    button: true,
                    toggled: hasLiked,
                    label: hasLiked ? 'Quitar me gusta' : 'Me gusta',
                    value: likes == 1 ? '1 me gusta' : '$likes me gusta',
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: onLikeClick == null
                          ? null
                          : () {
                              HapticFeedback.lightImpact().catchError((_) {});
                              onLikeClick!();
                            },
                      borderRadius: BorderRadius.circular(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedSwitcher(
                                duration: MediaQuery.of(context).disableAnimations
                                    ? Duration.zero
                                    : const Duration(milliseconds: 200),
                                transitionBuilder: (child, anim) =>
                                    ScaleTransition(scale: anim, child: child),
                                child: Icon(
                                  hasLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  key: ValueKey(hasLiked),
                                  color: hasLiked ? c.danger : c.textSecondary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$likes',
                                style: TextStyle(
                                  color: hasLiked ? c.danger : c.textSecondary,
                                  fontWeight: hasLiked ? FontWeight.w700 : FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _share,
                    icon: Icon(Icons.ios_share_rounded, color: c.textSecondary, size: 20),
                    label: Text('Compartir', style: TextStyle(color: c.textSecondary)),
                    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookEmbed(BuildContext context, LectorColors c) {
    final isReading = _status == 'leyendo';
    final currentPage = asInt(item['current_page']);
    final pageCount = asInt(item['page_count']);
    final hasPages = pageCount > 0;
    final progress = hasPages ? (currentPage / pageCount).clamp(0.0, 1.0) : 0.0;
    final percentage = (progress * 100).round();

    final details = <String>[
      '«$_title»',
      if (_author.isNotEmpty) 'de $_author',
      if (!isReading && _rating > 0) 'Calificación $_rating de 5',
      if (isReading && hasPages) 'Página $currentPage de $pageCount, $percentage por ciento',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Semantics(
        button: onBookClick != null,
        label: details.join('. '),
        hint: onBookClick != null ? 'Ver detalles del libro' : null,
        excludeSemantics: true,
        child: InkWell(
          onTap: onBookClick,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  height: 84,
                  child: BookCover(src: item['cover_url'], title: _title, author: _author),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _title,
                        style: GoogleFonts.lora(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_author.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          _author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: c.textSecondary),
                        ),
                      ],
                      const SizedBox(height: 8),
                      if (!isReading && _rating > 0)
                        Row(
                          children: [
                            for (var i = 1; i <= 5; i++)
                              Icon(
                                i <= _rating ? Icons.star_rounded : Icons.star_border_rounded,
                                size: 18,
                                color: c.star,
                              ),
                          ],
                        ),
                      if (isReading) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              hasPages ? 'Pág. $currentPage de $pageCount' : 'Pág. $currentPage',
                              style: TextStyle(fontSize: 12, color: c.textSecondary),
                            ),
                            if (hasPages)
                              Text(
                                '$percentage %',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: c.ink,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(value: progress, minHeight: 5),
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
    );
  }
}
