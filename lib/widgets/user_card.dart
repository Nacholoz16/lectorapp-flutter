import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:test_lectorapp/book_cover.dart';

class UserCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String mode; // 'feed' o 'review'
  final VoidCallback? onBookClick;

  const UserCard({
    super.key,
    required this.item,
    this.mode = 'feed',
    this.onBookClick,
  });

  // Colores Pastel para los estados
  Color _getStatusColor(String status, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (status.toLowerCase()) {
      case 'terminado':
        return isDark
            ? const Color(0xFF66BB6A)
            : const Color(0xFF81C784); // Verde Pastel
      case 'abandonado':
        return isDark
            ? const Color(0xFFEF5350)
            : const Color(0xFFE57373); // Rojo Pastel
      case 'leyendo':
        return Theme.of(context).primaryColor; // Toma el color Salvia/Rosa/Azul
      default:
        return Colors.grey.shade400;
    }
  }

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
    final date = DateTime.tryParse(item['created_at'] ?? '') ?? DateTime.now();
    final formattedDate = DateFormat('MMM d', 'es').format(date);

    String avatarUrl = item['avatar_url'] ??
        'https://api.dicebear.com/7.x/bottts/png?seed=${item['username']}';
    if (avatarUrl.contains('/svg'))
      avatarUrl = avatarUrl.replaceAll('/svg', '/png');

    return Container(
      // Márgenes para separarla del fondo y crear el efecto burbuja
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24.0), // Radio gigante
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.08), // Resplandor ultra suave
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
              padding: const EdgeInsets.all(20.0), // Más respiro interior
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: CachedNetworkImageProvider(avatarUrl),
                    backgroundColor: primaryColor
                        .withOpacity(0.1), // Fondo suave para el avatar
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              item['username'] ?? 'Usuario',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formattedDate,
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // BADGES SUAVES
                        if (mode == 'feed' && item['status'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(item['status'], context)
                                  .withOpacity(0.15),
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

            // TEXTO DE LA RESEÑA (Itálica y elegante)
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
                      color: primaryColor.withOpacity(0.05), // Cápsula pastel
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
                                  fontFamily: 'Lora', // Título en Serif
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
                                    color: Colors.grey.shade600,
                                    letterSpacing: 0.5),
                              ),
                              const SizedBox(height: 8),
                              // Estrellas amarillas pastel redondeadas
                              if (item['rating'] != null)
                                Row(
                                  children: List.generate(5, (index) {
                                    return Icon(
                                      index < (item['rating'] as num).toInt()
                                          ? Icons.star_rounded
                                          : Icons.star_border_rounded,
                                      size: 18,
                                      color: const Color(0xFFFFD54F),
                                    );
                                  }),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ACTIONS (Botón Compartir)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _share(context),
                    icon: Icon(Icons.ios_share_rounded,
                        color: Colors.grey.shade500, size: 20),
                    label: Text('Compartir',
                        style: TextStyle(color: Colors.grey.shade500)),
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
