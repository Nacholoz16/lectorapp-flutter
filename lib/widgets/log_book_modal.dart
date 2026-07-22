import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart'; // <-- IMPORTANTE AÑADIR ESTO
import '../services/reading_service.dart';

class LogBookModal extends StatefulWidget {
  final Map<String, dynamic> book;

  const LogBookModal({super.key, required this.book});

  @override
  State<LogBookModal> createState() => _LogBookModalState();
}

class _LogBookModalState extends State<LogBookModal> {
  String _status = 'leyendo';
  int _rating = 0;
  final TextEditingController _reviewController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isPublic = false;
  bool _datesExpanded = false;
  bool _isSaving = false;

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart)
          _startDate = picked;
        else
          _endDate = picked;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    final payload = {
      'bookData': {
        'external_id': widget.book['external_id'] ?? widget.book['google_id'],
        'title': widget.book['title'],
        'authors': widget.book['authors'] ?? widget.book['author'],
        'cover_url': widget.book['cover_url'],
        'isbn': widget.book['isbn'],
        'page_count': widget.book['page_count']
      },
      'logData': {
        'status': _status,
        'rating': _rating > 0 ? _rating : null,
        'review_text': _reviewController.text,
        'start_date': _startDate != null
            ? DateFormat('yyyy-MM-dd').format(_startDate!)
            : null,
        'finish_date': _endDate != null
            ? DateFormat('yyyy-MM-dd').format(_endDate!)
            : null,
        'is_log_public': _isPublic
      }
    };

    try {
      await ReadingService().createLog(payload);
      if (mounted) Navigator.pop(context, {'saved': true});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Usamos FractionallySizedBox para asegurar el 90% de pantalla sin forzar cálculos pesados
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // 2. ¡LA MAGIA! Scaffold maneja el teclado nativamente sin repintar toda tu UI
        resizeToAvoidBottomInset: true,
        body: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // HEADER (100% aislado del teclado)
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
                title: const Text('Registrar Lectura',
                    style: TextStyle(fontSize: 18)),
                centerTitle: true,
                actions: [
                  TextButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text('Guardar',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor)),
                  )
                ],
              ),

              // CONTENIDO SCROLLABLE (El Scaffold lo encogerá suavemente cuando el teclado suba)
              Expanded(
                child: ListView(
                  padding:
                      const EdgeInsets.all(16), // Volvemos al padding normal
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: widget.book['cover_url'] ??
                                'https://via.placeholder.com/60x90',
                            width: 60,
                            height: 90,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.auto_stories),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.book['title'] ?? '',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              Text(widget.book['authors'] ?? '',
                                  style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('Estado de lectura',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children:
                          ['leyendo', 'terminado', 'abandonado'].map((status) {
                        final isActive = _status == status;
                        return ChoiceChip(
                          label: Text(status.toUpperCase()),
                          selected: isActive,
                          selectedColor:
                              Theme.of(context).primaryColor.withOpacity(0.2),
                          labelStyle: TextStyle(
                              color: isActive
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey),
                          onSelected: (_) => setState(() => _status = status),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    if (_status != 'leyendo') ...[
                      const Text('Tu calificación',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        children: List.generate(5, (index) {
                          return IconButton(
                            icon: Icon(
                                index < _rating
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: const Color(0xFFFFD54F),
                                size: 32),
                            onPressed: () =>
                                setState(() => _rating = index + 1),
                          );
                        }),
                      ),
                      const SizedBox(height: 24),
                    ],
                    Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        title: const Text('Fechas de lectura (Opcional)',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        tilePadding: EdgeInsets.zero,
                        onExpansionChanged: (val) =>
                            setState(() => _datesExpanded = val),
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Fecha de inicio'),
                            subtitle: Text(_startDate != null
                                ? DateFormat('dd MMM yyyy', 'es')
                                    .format(_startDate!)
                                : 'Toca para seleccionar'),
                            trailing: const Icon(Icons.calendar_today),
                            onTap: () => _selectDate(context, true),
                          ),
                          if (_status == 'terminado')
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Fecha de fin'),
                              subtitle: Text(_endDate != null
                                  ? DateFormat('dd MMM yyyy', 'es')
                                      .format(_endDate!)
                                  : 'Toca para seleccionar'),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: () => _selectDate(context, false),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Tu opinión',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _reviewController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: '¿Qué te pareció? Comparte tu opinión...',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_isPublic ? 'Público' : 'Privado',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(_isPublic
                          ? 'Visible en tu perfil y feed'
                          : 'Solo tú puedes verlo'),
                      value: _isPublic,
                      activeColor: Theme.of(context).primaryColor,
                      secondary:
                          Icon(_isPublic ? Icons.public : Icons.lock_outline),
                      onChanged: (val) => setState(() => _isPublic = val),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
