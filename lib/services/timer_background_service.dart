import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
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
  String bookTitle = 'Sesión de lectura';
  Map<String, dynamic>? selectedLog;
  DateTime? startTime;
  int accumulatedSeconds = 0;

  Timer? ticker;

  String fmt(int totalSeconds) {
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
            ? 'Leyendo… ${fmt(seconds)}'
            : 'Pausado — ${fmt(seconds)}',
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
      bookTitle = event['bookTitle'] ?? 'Sesión de lectura';
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
      unawaited(service.stopSelf());
    }
  });

  service.on('stopService').listen((_) {
    ticker?.cancel();
    if (service is AndroidServiceInstance) {
      service.stopSelf();
    }
  });

  // Todos los listeners están registrados: avisar a la UI que ya puede enviar comandos.
  service.invoke('ready');
}

// ─── Clase pública de acceso al servicio ─────────────────────────────────────
class TimerBackgroundService {
  /// El servicio en segundo plano solo existe en Android/iOS. En web (vista previa de diseño
  /// en el navegador) o escritorio no hay implementación y `configure` lanzaría una excepción
  /// antes de `runApp`, dejando la app en blanco.
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> initializeService() async {
    if (!isSupported) return;
    final service = FlutterBackgroundService();

    // Crear canal de notificaciones (requerido en Android 8+)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      kNotificationChannelId,
      'Sesión de lectura',
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
        initialNotificationTitle: 'Sesión de lectura',
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
    if (!isSupported) return;
    final service = FlutterBackgroundService();
    final running = await service.isRunning();
    if (!running) {
      // Escuchar 'ready' ANTES de arrancar para no perder el evento. Si el isolate
      // no responde a tiempo (dispositivo lento), se envía el comando igualmente.
      final ready = service.on('ready').first.timeout(
            const Duration(seconds: 3),
            onTimeout: () => null,
          );
      await service.startService();
      await ready;
    }
    service.invoke('startTimer', {
      'bookTitle': bookTitle,
      'selectedLog': selectedLog,
      'seconds': initialSeconds,
    });
  }

  static void pause() => _invoke('pauseTimer');
  static void resume() => _invoke('resumeTimer');
  static void stop() => _invoke('stopTimer');
  static void stopService() => _invoke('stopService');

  static void _invoke(String method) {
    if (isSupported) FlutterBackgroundService().invoke(method);
  }
}
