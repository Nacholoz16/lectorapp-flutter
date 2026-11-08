import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/reading_service.dart';
import '../theme/lector_colors.dart';

class EditBookModal extends StatefulWidget {
  final Map<String, dynamic> readingLog;

  const EditBookModal({super.key, required this.readingLog});

  @override
  State<EditBookModal> createState() => _EditBookModalState();
}

class _EditBookModalState extends State<EditBookModal> {
  late String _status;
  late int _rating;
  late TextEditingController _reviewController;
  late TextEditingController _currentPageController;
  DateTime? _startDate;
  DateTime? _endDate;
  late bool _isPublic;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _status = widget.readingLog['status'] ?? 'leyendo';
    _rating = (widget.readingLog['rating'] as num?)?.toInt() ?? 0;
    _reviewController =
        TextEditingController(text: widget.readingLog['review_text'] ?? '');
    _currentPageController = TextEditingController(
        text: (widget.readingLog['current_page'] ?? 0).toString());

    if (widget.readingLog['start_date'] != null) {
      _startDate = DateTime.tryParse(widget.readingLog['start_date']);
    }
    if (widget.readingLog['finish_date'] != null) {
      _endDate = DateTime.tryParse(widget.readingLog['finish_date']);
    }
    _isPublic = widget.readingLog['is_log_public'] == true ||
        widget.readingLog['is_log_public'] == 1;
  }

  @override
  void dispose() {
    _reviewController.dispose();
    _currentPageController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final payload = {
      'status': _status,
      'rating': _rating > 0 ? _rating : null,
      'review_text': _reviewController.text,
      'start_date': _startDate != null
          ? DateFormat('yyyy-MM-dd').format(_startDate!)
          : null,
      'finish_date':
          _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null,
      'is_log_public': _isPublic,
      'current_page': int.tryParse(_currentPageController.text) ?? 0
    };

    try {
      await ReadingService()
          .updateLog(widget.readingLog['id'].toString(), payload);
      if (mounted) Navigator.pop(context, {'action': 'updated'});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Theme.of(context).colorScheme.error));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar opinión?'),
        content: const Text(
            'Esta acción no se puede deshacer. Se borrará tu reseña y calificación.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar', style: TextStyle(color: context.lector.danger)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isSaving = true);
      try {
        await ReadingService().deleteLog(widget.readingLog['id'].toString());
        if (mounted) Navigator.pop(context, {'action': 'deleted'});
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error: $e'), backgroundColor: Theme.of(context).colorScheme.error));
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
                title: const Text('Editar Lectura',
                    style: TextStyle(fontSize: 18)),
                centerTitle: true,
                actions: [
                  IconButton(
                      icon: Icon(Icons.delete_outline, color: context.lector.danger),
                      onPressed: _isSaving ? null : _confirmDelete),
                  TextButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : Text('Guardar',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor)),
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Portada + Info
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: widget.readingLog['cover_image'] ??
                                widget.readingLog['cover_url'] ??
                                '',
                            fadeInDuration: Duration.zero,
                            fadeOutDuration: Duration.zero,
                            width: 60,
                            height: 90,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) =>
                                Container(
                                  width: 60,
                                  height: 90,
                                  color: Theme.of(context)
                                      .primaryColor
                                      .withValues(alpha: 0.2),
                                  child: const Icon(Icons.auto_stories),
                                ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.readingLog['title'] ?? '',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              Text(
                                  widget.readingLog['author'] ??
                                      widget.readingLog['authors'] ??
                                      '',
                                  style:
                                      TextStyle(color: context.lector.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Estado
                    const Text('Estado de lectura',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['leyendo', 'terminado', 'abandonado']
                          .map((status) {
                        final isActive = _status == status;
                        return ChoiceChip(
                          label: Text(status.toUpperCase()),
                          selected: isActive,
                          selectedColor: Theme.of(context)
                              .primaryColor
                              .withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                              color: isActive
                                  ? Theme.of(context).primaryColor
                                  : context.lector.textSecondary),
                          onSelected: (_) =>
                              setState(() => _status = status),
                        );
                      }).toList(),
                    ),
                    if (_status == 'leyendo') ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text('Página actual:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 100,
                            child: TextField(
                              controller: _currentPageController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: '0',
                                suffixText: widget.readingLog['page_count'] != null
                                    ? '/ ${widget.readingLog['page_count']}'
                                    : '',
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Rating (solo si no está leyendo)
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
                                color: context.lector.star,
                                size: 32),
                            onPressed: () =>
                                setState(() => _rating = index + 1),
                          );
                        }),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Fechas de lectura (ahora funcional)
                    Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        title: const Text('Fechas de lectura (Opcional)',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        tilePadding: EdgeInsets.zero,
                        initiallyExpanded:
                            _startDate != null || _endDate != null,
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

                    // Reseña
                    const Text('Tu opinión',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _reviewController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Edita tu opinión...',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Switch privacidad
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_isPublic ? 'Público' : 'Privado',
                          style:
                              const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(_isPublic
                          ? 'Visible en tu perfil y feed'
                          : 'Solo tú puedes verlo'),
                      value: _isPublic,
                      activeThumbColor: Theme.of(context).primaryColor,
                      secondary: Icon(
                          _isPublic ? Icons.public : Icons.lock_outline),
                      onChanged: (val) =>
                          setState(() => _isPublic = val),
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
