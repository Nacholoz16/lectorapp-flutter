import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/reading_service.dart';
import '../services/timer_background_service.dart';

class ReadingTimerModal extends StatefulWidget {
  final List<dynamic> readingLogs; // Lista de libros en estado 'leyendo'

  const ReadingTimerModal({super.key, required this.readingLogs});

  @override
  State<ReadingTimerModal> createState() => _ReadingTimerModalState();
}

class _ReadingTimerModalState extends State<ReadingTimerModal> {
  StreamSubscription<Map<String, dynamic>?>? _serviceSubscription;
  int _seconds = 0;
  bool _isRunning = false;
  bool _isFinished = false;
  bool _isSaving = false;

  Map<String, dynamic>? _selectedLog;
  final TextEditingController _pagesReadController =
      TextEditingController(text: '0');
  final TextEditingController _currentPageController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.readingLogs.isNotEmpty) {
      _selectedLog = widget.readingLogs.first;
      _updateCurrentPageText();
    }

    // En web/escritorio (vista previa de diseño) no hay servicio en segundo plano:
    // el modal se dibuja, pero el cronómetro no corre.
    if (!TimerBackgroundService.isSupported) return;

    unawaited(_requestNotificationPermission());

    _serviceSubscription = FlutterBackgroundService()
        .on('update')
        .listen((event) {
      if (event != null && mounted) {
        setState(() {
          _seconds = event['seconds'] ?? _seconds;
          _isRunning = event['isRunning'] ?? _isRunning;
          _isFinished = event['isFinished'] ?? _isFinished;
          // Solo reescribir el campo de página si cambió el libro; si no, cada
          // 'update' (1 por segundo) borraría lo que el usuario está escribiendo.
          if (event['selectedLog'] != null) {
            final incoming = Map<String, dynamic>.from(event['selectedLog']);
            final changedBook = incoming['id'] != _selectedLog?['id'];
            _selectedLog = incoming;
            if (changedBook) _updateCurrentPageText();
          }
        });
      }
    });
  }

  Future<void> _requestNotificationPermission() async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  void _updateCurrentPageText() {
    if (_selectedLog != null) {
      final cp =
          _selectedLog!['current_page'] ?? _selectedLog!['currentPage'] ?? 0;
      _currentPageController.text = cp.toString();
    }
  }

  @override
  void dispose() {
    _serviceSubscription?.cancel();
    _pagesReadController.dispose();
    _currentPageController.dispose();
    super.dispose();
  }

  void _startTimer() async {
    final title = _selectedLog?['title'] ?? 'Sesión de Lectura';
    await TimerBackgroundService.start(
      bookTitle: title,
      selectedLog: _selectedLog,
      initialSeconds: _seconds,
    );
    if (!mounted) return;
    setState(() {
      _isRunning = true;
    });
  }

  void _pauseTimer() {
    TimerBackgroundService.pause();
    setState(() {
      _isRunning = false;
    });
  }

  void _stopTimer() {
    TimerBackgroundService.stop();
    setState(() {
      _isRunning = false;
      _isFinished = true;
    });
  }

  String _formatDuration(int totalSeconds) {
    final hours = (totalSeconds / 3600).floor();
    final minutes = ((totalSeconds % 3600) / 60).floor();
    final seconds = totalSeconds % 60;

    final hStr = hours > 0 ? '${hours.toString().padLeft(2, '0')}:' : '';
    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');
    return '$hStr$mStr:$sStr';
  }

  Future<void> _saveSession() async {
    if (_selectedLog == null) return;
    final logId = _selectedLog!['id'];
    if (logId == null) return;

    final durationMinutes = (math.max(1, (_seconds / 60).round()));
    final pagesRead = int.tryParse(_pagesReadController.text) ?? 0;
    final currentPage = int.tryParse(_currentPageController.text);

    setState(() => _isSaving = true);
    try {
      await ReadingService().recordSession(
        logId is int ? logId : int.parse(logId.toString()),
        durationMinutes: durationMinutes,
        pagesRead: pagesRead,
        currentPage: currentPage,
      );

      TimerBackgroundService.stopService();

      if (mounted) {
        Navigator.pop(context, {'saved': true, 'minutes': durationMinutes});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar la sesión: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timer_outlined, size: 24),
                SizedBox(width: 8),
                Text(
                  'Sesión de Lectura',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Lora',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (widget.readingLogs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.menu_book_rounded,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No tienes libros en estado "LEYENDO" actualmente.\nAgrega uno desde el buscador para iniciar el cronómetro.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              )
            else ...[
              // Selector de Libro
              if (!_isRunning && !_isFinished) ...[
                DropdownButtonFormField<Map<String, dynamic>>(
                  initialValue: _selectedLog,
                  decoration: InputDecoration(
                    labelText: 'Selecciona el libro que vas a leer',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  items: widget.readingLogs.map((log) {
                    final title = log['title'] ?? 'Sin título';
                    return DropdownMenuItem<Map<String, dynamic>>(
                      value: log as Map<String, dynamic>,
                      child: Text(title, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedLog = val;
                      _updateCurrentPageText();
                    });
                  },
                ),
                const SizedBox(height: 24),
              ],

              // Temporizador
              Text(
                _formatDuration(_seconds),
                style: TextStyle(
                  fontSize: 54,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: _isRunning ? primaryColor : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 24),

              // Controles del Timer
              if (!_isFinished)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!_isRunning)
                      ElevatedButton.icon(
                        onPressed: _startTimer,
                        icon: const Icon(Icons.play_arrow_rounded, size: 28),
                        label: Text(
                          _seconds == 0 ? 'Iniciar Lectura' : 'Reanudar',
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      )
                    else ...[
                      OutlinedButton.icon(
                        onPressed: _pauseTimer,
                        icon: const Icon(Icons.pause_rounded, size: 24),
                        label: const Text('Pausar'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: _stopTimer,
                        icon: const Icon(Icons.stop_rounded, size: 24),
                        label: const Text('Finalizar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade400,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ],
                )
              else ...[
                // Formulario de Cierre de Sesión
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '¡Excelente lectura! Lograste ${math.max(1, (_seconds / 60).round())} minutos.',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _pagesReadController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Páginas leídas hoy',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _currentPageController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Página actual',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveSession,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Guardar Sesión',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
