import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:test_lectorapp/book_cover.dart';
import 'package:test_lectorapp/utils/json_utils.dart';
import '../theme/lector_colors.dart';

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

  Color _getStatusColor(String status, BuildContext context) =>
      context.lector.statusColor(status);

  Future<void> _share(BuildContext context) async {
    final bookId =
        item['book']?['external_id'] ?? item['book']?['google_id'] ?? '';
    final url = 'https://nacholoz3d.cl/libro/$bookId';
    await Share.share('¡Encontré esto en la app y está genial! $url',
        subject: 'Mira este contenido');
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final hasLiked = asBool(item['has_liked']);
    final date = DateTime.tryParse(item['created_at'] ?? '') ?? DateTime.now();
    final formattedDate = DateFormat('MMM d', 'es').format(date);

    String avatarUrl = item['avatar_url'] ??
        'https://api.dicebear.com/7.x/bottts/png?seed=${item['username']}';
    if (avatarUrl.contains('/svg')) {
      avatarUrl = avatarUrl.replaceAll('/svg', '/png');
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24.0),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onUserClick,
                    child: CircleAvatar(
                      radius: 24,
                      backgroundImage: CachedNetworkImageProvider(avatarUrl),
                      backgroundColor: primaryColor.withValues(alpha: 0.1),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: onUserClick,
                              child: Text(
                                item['username'] ?? 'Usuario',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formattedDate,
                              style: TextStyle(
                                  color: context.lector.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (mode == 'feed' && item['status'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(item['status'], context)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              item['status'].toString().toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(item['status'], context),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // TEXTO DE LA RESEÑA
            if (item['review_text'] != null &&
                item['review_text'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0)
                    .copyWith(bottom: 16),
                child: Text(
                  '"${item['review_text']}"',
                  style: const TextStyle(
                      fontSize: 15, height: 1.6, fontStyle: FontStyle.italic),
                ),
              ),

            // BOOK EMBED (Solo Feed)
            if (mode == 'feed')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0)
                    .copyWith(bottom: 16),
                child: InkWell(
                  onTap: onBookClick,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 60,
                          height: 90,
                          child: BookCover(
                            src: item['cover_url'],
                            title: item['title'] ?? '',
                            author: item['author'] ?? item['authors'] ?? '',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['title'] ?? 'Sin título',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Lora',
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                (item['author'] ?? item['authors'] ?? '')
                                    .toString()
                                    .toUpperCase(),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: context.lector.textSecondary,
                                    letterSpacing: 0.5),
                              ),
                              const SizedBox(height: 8),
                              if (item['rating'] != null && item['status'] != 'leyendo')
                                Row(
                                  children: List.generate(5, (index) {
                                    return Icon(
                                      index < (item['rating'] as num).toInt()
                                          ? Icons.star_rounded
                                          : Icons.star_border_rounded,
                                      size: 18,
                                      color: context.lector.star,
                                    );
                                  }),
                                ),
                              if (item['status'] == 'leyendo') ...[
                                const SizedBox(height: 6),
                                Builder(builder: (context) {
                                  final currentPage = (item['current_page'] as num?)?.toInt() ?? 0;
                                  final pageCount = (item['page_count'] as num?)?.toInt();
                                  final double progress = (pageCount != null && pageCount > 0)
                                      ? (currentPage / pageCount).clamp(0.0, 1.0)
                                      : 0.0;
                                  final int percentage = (progress * 100).round();

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            pageCount != null ? '$currentPage / $pageCount pág.' : '$currentPage pág.',
                                            style: TextStyle(fontSize: 11, color: context.lector.textSecondary),
                                          ),
                                          if (pageCount != null)
                                            Text(
                                              '$percentage%',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryColor),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: progress,
                                          minHeight: 5,
                                          backgroundColor: primaryColor.withValues(alpha: 0.15),
                                          color: primaryColor,
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ACTIONS
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      hasLiked ? Icons.favorite : Icons.favorite_border,
                      color: hasLiked ? context.lector.danger : context.lector.textSecondary,
                      size: 22,
                    ),
                    onPressed: onLikeClick,
                  ),
                  Text(
                    '${item['likes_count'] ?? 0}',
                    style: TextStyle(
                      color: hasLiked ? context.lector.danger : context.lector.textSecondary,
                      fontWeight: hasLiked ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _share(context),
                    icon: Icon(Icons.ios_share_rounded,
                        color: context.lector.textSecondary, size: 20),
                    label: Text('Compartir',
                        style: TextStyle(color: context.lector.textSecondary)),
                    style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20))),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
