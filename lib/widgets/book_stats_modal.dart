import 'package:flutter/material.dart';
import '../services/reading_service.dart';
import '../book_cover.dart';

class BookStatsModal extends StatefulWidget {
  final Map<String, dynamic> readingLog;

  const BookStatsModal({super.key, required this.readingLog});

  @override
  State<BookStatsModal> createState() => _BookStatsModalState();
}

class _BookStatsModalState extends State<BookStatsModal> {
  bool _isLoading = true;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadBookStats();
  }

  Future<void> _loadBookStats() async {
    final logId = widget.readingLog['id'];
    if (logId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final res = await ReadingService().getBookStats(
        logId is int ? logId : int.parse(logId.toString()),
      );
      if (mounted) {
        setState(() {
          _stats = res;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final title = widget.readingLog['title'] ?? 'Sin título';
    final author = widget.readingLog['authors'] ?? widget.readingLog['author'] ?? 'Desconocido';
    final coverUrl = widget.readingLog['cover_url'] ?? widget.readingLog['cover_image'];
    final status = widget.readingLog['status'] ?? 'leyendo';
    final currentPage = widget.readingLog['current_page'] ?? widget.readingLog['currentPage'] ?? 0;
    final pageCount = widget.readingLog['page_count'];

    final totalMinutes = _stats?['total_minutes'] ?? 0;
    final hours = (totalMinutes / 60).floor();
    final minutes = totalMinutes % 60;
    final timeStr = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
    final totalSessions = _stats?['total_sessions'] ?? 0;
    final avgSession = _stats?['avg_session_minutes'] ?? 0;

    final double progress = (pageCount != null && pageCount > 0)
        ? (currentPage / pageCount).clamp(0.0, 1.0)
        : 0.0;
    final int percentage = (progress * 100).round();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Book Header
            Row(
              children: [
                SizedBox(
                  width: 50,
                  height: 75,
                  child: BookCover(
                    src: coverUrl,
                    title: title,
                    author: author,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Lora'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(author,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      const SizedBox(height: 6),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status.toString().toUpperCase(),
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: primaryColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            const Text(
              'Estadísticas del Libro',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),

            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()))
            else ...[
              // Grid of Metrics
              Row(
                children: [
                  Expanded(
                    child: _buildTile(
                      icon: Icons.access_time_filled_rounded,
                      color: const Color(0xFF4995FF),
                      label: 'Tiempo Dedicado',
                      value: timeStr,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTile(
                      icon: Icons.timer_outlined,
                      color: const Color(0xFF66BB6A),
                      label: 'Sesiones Totales',
                      value: '$totalSessions',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTile(
                      icon: Icons.speed_rounded,
                      color: const Color(0xFFAB47BC),
                      label: 'Promedio Sesión',
                      value: '$avgSession min',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTile(
                      icon: Icons.menu_book_rounded,
                      color: const Color(0xFFFFB74D),
                      label: 'Progreso',
                      value: pageCount != null ? '$percentage%' : '$currentPage pág.',
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
        ],
      ),
    );
  }
}
