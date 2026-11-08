import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:test_lectorapp/book_cover.dart';
import 'package:test_lectorapp/utils/json_utils.dart';
import '../services/preferences_service.dart';
import '../theme/lector_colors.dart';
import 'status_chip.dart';

/// Una lectura en el feed (`mode: 'feed'`) o en la lista de reseñas de un libro
/// (`mode: 'review'`).
///
/// En el feed hay dos vistas ([FeedLayout], elegible en Perfil → Ajustes → Vista del feed):
/// - `cards` (por defecto): el libro es protagonista — portada grande, título, estrellas o
///   progreso y los pensamientos resumidos con "Leer más".
/// - `compact`: sin tarjeta, separada por líneas; más lecturas por pantalla.
///
/// Accesibilidad: TalkBack la recorre en paradas con sentido — quién y qué hizo (abre su
/// perfil), el libro (abre el detalle), los pensamientos y las acciones.
class UserCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String mode; // 'feed' o 'review'
  final FeedLayout layout;
  final VoidCallback? onBookClick;
  final VoidCallback? onLikeClick;
  final VoidCallback? onUserClick;

  const UserCard({
    super.key,
    required this.item,
    this.mode = 'feed',
    this.layout = FeedLayout.cards,
    this.onBookClick,
    this.onLikeClick,
    this.onUserClick,
  });

  String get _title =>
      (item['title'] ?? item['book']?['title'] ?? 'Sin título').toString();
  String get _author =>
      (item['author'] ?? item['authors'] ?? item['book']?['authors'] ?? '')
          .toString();
  String get _username => (item['username'] ?? 'Usuario').toString();
  String? get _status => item['status']?.toString();
  String get _review => (item['review_text'] ?? '').toString().trim();
  int get _rating => asInt(item['rating']);
  bool get _isReading => _status == 'leyendo';
  int get _currentPage => asInt(item['current_page']);
  int get _pageCount => asInt(item['page_count']);

  DateTime get _date =>
      DateTime.tryParse(item['created_at'] ?? '')?.toLocal() ?? DateTime.now();

  String get _avatarUrl {
    final url = (item['avatar_url'] ??
            'https://api.dicebear.com/7.x/bottts/png?seed=${item['username']}')
        .toString();
    return url.contains('/svg') ? url.replaceAll('/svg', '/png') : url;
  }

  Future<void> _share() async {
    final bookId = item['external_id'] ??
        item['book']?['external_id'] ??
        item['google_id'] ??
        item['book']?['google_id'];
    final url = bookId != null
        ? 'https://nacholoz3d.cl/libro/$bookId'
        : 'https://nacholoz3d.cl';
    final by = _author.isNotEmpty ? ' de $_author' : '';
    await Share.share('Mira «$_title»$by en LectorApp: $url', subject: _title);
  }

  /// "terminó", "está leyendo"...
  static String _verb(String? status) {
    switch (status) {
      case 'terminado':
        return 'terminó';
      case 'abandonado':
        return 'lo dejó';
      case 'leyendo':
        return 'está leyendo';
      default:
        return 'registró';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (mode == 'review') return _buildReview(context);
    return layout == FeedLayout.compact
        ? _buildCompact(context)
        : _buildCard(context);
  }

  // ─── Vista B: tarjeta con el libro protagonista ────────────────────────────────────────

  Widget _buildCard(BuildContext context) {
    final c = context.lector;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
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
            _byline(context,
                avatarRadius: 14,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10)),
            Semantics(
              button: onBookClick != null,
              label: _bookSpoken(),
              hint: onBookClick != null ? 'Ver detalles del libro' : null,
              excludeSemantics: true,
              child: InkWell(
                onTap: onBookClick,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 92,
                        height: 138,
                        child: BookCover(
                            src: item['cover_url'],
                            title: _title,
                            author: _author),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.lora(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                                color: c.textPrimary,
                              ),
                            ),
                            if (_author.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(_author,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 13, color: c.textSecondary)),
                            ],
                            const SizedBox(height: 10),
                            if (!_isReading && _rating > 0) _stars(c, 18),
                            if (_isReading) _progress(c),
                            if (!_isReading && _rating == 0 && _status != null)
                              StatusChip(status: _status),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_review.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: _ExpandableText(text: _review, maxLines: 4),
              ),
            _actions(context, const EdgeInsets.fromLTRB(6, 2, 6, 4)),
          ],
        ),
      ),
    );
  }

  // ─── Vista C: lista compacta ───────────────────────────────────────────────────────────

  Widget _buildCompact(BuildContext context) {
    final c = context.lector;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: GestureDetector(
              onTap: onUserClick,
              child: CircleAvatar(
                radius: 20,
                backgroundImage: CachedNetworkImageProvider(_avatarUrl),
                backgroundColor: c.accent.withValues(alpha: 0.15),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _byline(context, showAvatar: false, padding: EdgeInsets.zero),
                Semantics(
                  button: onBookClick != null,
                  label: _bookSpoken(),
                  hint: onBookClick != null ? 'Ver detalles del libro' : null,
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: onBookClick,
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 26,
                              height: 39,
                              child: BookCover(
                                  src: item['cover_url'],
                                  title: _title,
                                  author: _author),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                _title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: c.textPrimary,
                                ),
                              ),
                            ),
                            if (!_isReading && _rating > 0) ...[
                              const SizedBox(width: 8),
                              _stars(c, 14),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (_isReading)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: SizedBox(width: 180, child: _progress(c)),
                  ),
                if (_review.isNotEmpty)
                  _ExpandableText(text: _review, maxLines: 6, fontSize: 15),
                _actions(context, EdgeInsets.zero),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Reseñas en el detalle de un libro ─────────────────────────────────────────────────

  Widget _buildReview(BuildContext context) {
    final c = context.lector;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _byline(context,
                avatarRadius: 18,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8)),
            if (_rating > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Semantics(
                  label: 'Calificación $_rating de 5',
                  excludeSemantics: true,
                  child: _stars(c, 16),
                ),
              ),
            if (_review.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _ExpandableText(text: _review, maxLines: 6),
              ),
            _actions(context, const EdgeInsets.fromLTRB(6, 2, 6, 4)),
          ],
        ),
      ),
    );
  }

  // ─── Piezas comunes ────────────────────────────────────────────────────────────────────

  /// "test001 terminó · 22 jul" (un solo botón → perfil).
  Widget _byline(
    BuildContext context, {
    bool showAvatar = true,
    double avatarRadius = 14,
    required EdgeInsets padding,
  }) {
    final c = context.lector;
    final verb = mode == 'feed' && _status != null ? ' ${_verb(_status)}' : '';
    final shortDate = DateFormat('d MMM', 'es').format(_date);
    final longDate = DateFormat("d 'de' MMMM", 'es').format(_date);
    final spoken = mode == 'feed' && _status != null
        ? '$_username ${_verb(_status)} «$_title», el $longDate'
        : '$_username, el $longDate';

    return Semantics(
      button: onUserClick != null,
      label: spoken,
      hint: onUserClick != null ? 'Ver perfil' : null,
      excludeSemantics: true,
      child: InkWell(
        onTap: onUserClick,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: padding,
          child: Row(
            children: [
              if (showAvatar) ...[
                CircleAvatar(
                  radius: avatarRadius,
                  backgroundImage: CachedNetworkImageProvider(_avatarUrl),
                  backgroundColor: c.accent.withValues(alpha: 0.15),
                ),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: _username,
                      style: TextStyle(
                          fontWeight: FontWeight.w800, color: c.textPrimary),
                    ),
                    TextSpan(
                      text: '$verb · $shortDate',
                      style: TextStyle(color: c.textSecondary),
                    ),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _bookSpoken() => [
        '«$_title»',
        if (_author.isNotEmpty) 'de $_author',
        if (!_isReading && _rating > 0) 'Calificación $_rating de 5',
        if (_isReading && _pageCount > 0)
          'Página $_currentPage de $_pageCount, ${(_currentPage / _pageCount * 100).clamp(0, 100).round()} por ciento',
      ].join('. ');

  Widget _stars(LectorColors c, double size) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(
              i <= _rating ? Icons.star_rounded : Icons.star_border_rounded,
              size: size,
              color: c.star,
            ),
        ],
      );

  Widget _progress(LectorColors c) {
    final hasPages = _pageCount > 0;
    final progress =
        hasPages ? (_currentPage / _pageCount).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              hasPages
                  ? 'Pág. $_currentPage de $_pageCount'
                  : 'Pág. $_currentPage',
              style: TextStyle(fontSize: 12, color: c.textSecondary),
            ),
            if (hasPages)
              Text('${(progress * 100).round()} %',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: c.ink)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: progress, minHeight: 5),
        ),
      ],
    );
  }

  Widget _actions(BuildContext context, EdgeInsets padding) {
    final c = context.lector;
    final hasLiked = asBool(item['has_liked']);
    final likes = asInt(item['likes_count']);
    return Padding(
      padding: padding,
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
                  padding: const EdgeInsets.symmetric(horizontal: 10),
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
                          hasLiked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          key: ValueKey(hasLiked),
                          color: hasLiked ? c.danger : c.textSecondary,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$likes',
                        style: TextStyle(
                          color: hasLiked ? c.danger : c.textSecondary,
                          fontWeight:
                              hasLiked ? FontWeight.w700 : FontWeight.w500,
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
          IconButton(
            onPressed: _share,
            tooltip: 'Compartir «$_title»',
            icon:
                Icon(Icons.ios_share_rounded, color: c.textSecondary, size: 20),
          ),
        ],
      ),
    );
  }
}

/// Texto que se recorta a [maxLines] con "Leer más" / "Leer menos".
class _ExpandableText extends StatefulWidget {
  final String text;
  final int maxLines;
  final double fontSize;

  const _ExpandableText(
      {required this.text, required this.maxLines, this.fontSize = 15.5});

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = context.lector;
    final style = TextStyle(
        fontSize: widget.fontSize, height: 1.55, color: c.textPrimary);

    return LayoutBuilder(builder: (context, constraints) {
      // ¿El texto cabe en maxLines? Si cabe, no se muestra "Leer más".
      final painter = TextPainter(
        text: TextSpan(text: widget.text, style: style),
        maxLines: widget.maxLines,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: constraints.maxWidth);
      final overflows = painter.didExceedMaxLines;
      painter.dispose();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.text,
            style: style,
            maxLines: _expanded ? null : widget.maxLines,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
          if (overflows)
            TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(48, 40),
                tapTargetSize: MaterialTapTargetSize.padded,
                foregroundColor: c.ink,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              child: Text(_expanded ? 'Leer menos' : 'Leer más'),
            ),
        ],
      );
    });
  }
}
