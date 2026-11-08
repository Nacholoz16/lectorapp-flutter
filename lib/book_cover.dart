import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'widgets/book_loader.dart';

class BookCover extends StatelessWidget {
  final String? src;
  final String title;
  final String author;

  const BookCover({
    super.key,
    this.src,
    required this.title,
    required this.author,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: src != null && src!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: src!,
                fadeInDuration: const Duration(milliseconds: 300),
                fadeOutDuration: const Duration(milliseconds: 300),
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: primaryColor.withValues(alpha: 0.1),
                  child: Center(child: BookLoader(color: primaryColor)),
                ),
                errorWidget: (context, url, error) =>
                    _buildPlaceholder(context),
              )
            : _buildPlaceholder(context),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withValues(alpha: 0.4),
            primaryColor.withValues(alpha: 0.8),
          ],
        ),
      ),
      padding: const EdgeInsets.all(8.0),
      child: Center(
        child: Text(
          title.isNotEmpty ? title : 'Sin Portada',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Lora',
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
