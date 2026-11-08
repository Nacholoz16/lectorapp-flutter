import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const String kNotificationChannelId = 'reading_timer_channel';
const int kNotificationId = 888;

// ─── Entry point del servicio en segundo plano ───────────────────────────────
// NOTA: Esta función corre en un isolate separado. NO puede usar
// FlutterBackgroundService() ni ningún plugin de UI directamente.
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  int seconds = 0;
  bool isRunning = false;
  bool isFinished = false;
  String bookTitle = 'Sesión de Lectura';
  Map<String, dynamic>? selectedLog;
  DateTime? startTime;
  int accumulatedSeconds = 0;

  Timer? ticker;

  String _fmt(int totalSeconds) {
    final h = (totalSeconds / 3600).floor();
    final m = ((totalSeconds % 3600) / 60).floor();
    final s = totalSeconds % 60;
    final hStr = h > 0 ? '${h.toString().padLeft(2, '0')}:' : '';
    return '$hStr${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void pushUpdate() {
    service.invoke('update', {
      'seconds': seconds,
      'isRunning': isRunning,
      'isFinished': isFinished,
      'selectedLog': selectedLog,
    });

    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: bookTitle,
        content: isRunning
            ? 'Leyendo… ${_fmt(seconds)}'
            : 'Pausado — ${_fmt(seconds)}',
      );
    }
  }

  void startTicking() {
    ticker?.cancel();
    startTime = DateTime.now();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (isRunning && startTime != null) {
        final elapsed = DateTime.now().difference(startTime!).inSeconds;
        seconds = accumulatedSeconds + elapsed;
        pushUpdate();
      }
    });
  }

  // ── Comandos desde la UI ──────────────────────────────────────────────────

  service.on('startTimer').listen((event) {
    if (event != null) {
      bookTitle = event['bookTitle'] ?? 'Sesión de Lectura';
      selectedLog = event['selectedLog'];
      final initial = event['seconds'];
      if (initial != null) {
        seconds = initial as int;
        accumulatedSeconds = seconds;
      }
    }
    isRunning = true;
    isFinished = false;
    accumulatedSeconds = seconds;
    startTime = DateTime.now();
    startTicking();
    pushUpdate();
  });

  service.on('pauseTimer').listen((_) {
    if (!isRunning) return;
    if (startTime != null) {
      accumulatedSeconds += DateTime.now().difference(startTime!).inSeconds;
      seconds = accumulatedSeconds;
    }
    isRunning = false;
    ticker?.cancel();
    pushUpdate();
  });

  service.on('resumeTimer').listen((_) {
    if (isRunning || isFinished) return;
    isRunning = true;
    startTime = DateTime.now();
    startTicking();
    pushUpdate();
  });

  service.on('stopTimer').listen((_) async {
    if (isRunning && startTime != null) {
      accumulatedSeconds += DateTime.now().difference(startTime!).inSeconds;
      seconds = accumulatedSeconds;
    }
    isRunning = false;
    isFinished = true;
    ticker?.cancel();

    // Notificar a la UI con el tiempo final
    service.invoke('update', {
      'seconds': seconds,
      'isRunning': false,
      'isFinished': true,
      'selectedLog': selectedLog,
    });

    // Detener el servicio
    if (service is AndroidServiceInstance) {
      service.stopSelf();
    }
  });

  service.on('stopService').listen((_) {
    ticker?.cancel();
    if (service is AndroidServiceInstance) {
      service.stopSelf();
    }
  });
}

// ─── Clase pública de acceso al servicio ─────────────────────────────────────
class TimerBackgroundService {
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    // Crear canal de notificaciones (requerido en Android 8+)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      kNotificationChannelId,
      'Sesión de Lectura',
      description: 'Cronómetro de lectura en segundo plano',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );

    final FlutterLocalNotificationsPlugin notificationsPlugin =
        FlutterLocalNotificationsPlugin();
    await notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: kNotificationChannelId,
        initialNotificationTitle: 'Sesión de Lectura',
        initialNotificationContent: 'Listo para iniciar…',
        foregroundServiceNotificationId: kNotificationId,
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: (_) => true,
      ),
    );
  }

  static Future<void> start({
    required String bookTitle,
    Map<String, dynamic>? selectedLog,
    int initialSeconds = 0,
  }) async {
    final service = FlutterBackgroundService();
    final running = await service.isRunning();
    if (!running) {
      await service.startService();
      // Pequeña espera para que el engine del isolate esté listo
      await Future.delayed(const Duration(milliseconds: 300));
    }
    service.invoke('startTimer', {
      'bookTitle': bookTitle,
      'selectedLog': selectedLog,
      'seconds': initialSeconds,
    });
  }

  static void pause() => FlutterBackgroundService().invoke('pauseTimer');
  static void resume() => FlutterBackgroundService().invoke('resumeTimer');
  static void stop() => FlutterBackgroundService().invoke('stopTimer');
  static void stopService() =>
      FlutterBackgroundService().invoke('stopService');
}
