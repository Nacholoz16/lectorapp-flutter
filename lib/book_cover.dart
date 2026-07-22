import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
        borderRadius:
            BorderRadius.circular(16.0), // Bordes suaves para el libro
        boxShadow: [
          BoxShadow(
            color:
                primaryColor.withOpacity(0.2), // Sombra coloreada y translúcida
            blurRadius: 20,
            offset: const Offset(0, 10), // Cae suavemente hacia abajo
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: src != null && src!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: src!,
                fit: BoxFit.cover,
                // Mientras descarga la primera vez, mostramos tu diseño Lora
                placeholder: (context, url) => _buildPlaceholder(context),
                // Si la URL está rota o no hay internet, mostramos tu diseño
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
            primaryColor.withOpacity(0.4),
            primaryColor.withOpacity(0.8),
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
            fontFamily: 'Lora', // Toque literario para las portadas vacías
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
