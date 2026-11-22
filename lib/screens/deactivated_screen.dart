import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/account_service.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../theme/lector_colors.dart';
import '../ui/account_copy.dart';
import '../ui/feedback.dart';
import 'library_screen.dart';
import 'login_screen.dart';

/// Modo solo lectura de una cuenta desactivada (tarea 2.1, decisión D7).
///
/// Lo muestra `TabsScreen` en lugar de las pestañas mientras `AccountService().isDeactivated`
/// sea `true`. Solo la biblioteca (sin añadir, editar ni cronómetro), con un aviso arriba y las
/// acciones "Reactivar mi cuenta" y "Cerrar sesión". Solo llama a endpoints que la API permite
/// con la cuenta desactivada (biblioteca, estadísticas de sus libros, estado, reactivar, logout),
/// así que nunca provoca otro `403 ACCOUNT_DEACTIVATED`.
class DeactivatedScreen extends StatefulWidget {
  const DeactivatedScreen({super.key});

  @override
  State<DeactivatedScreen> createState() => _DeactivatedScreenState();
}

class _DeactivatedScreenState extends State<DeactivatedScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // El dato local es solo una pista: si la cuenta se reactivó desde otro teléfono, la API lo
    // dice aquí y TabsScreen vuelve sola a las pestañas. Sin red, se queda como está.
    unawaited(AccountService().fetchStatus().then((_) {}, onError: (_) {}));
  }

  Future<void> _reactivate() async {
    setState(() => _busy = true);
    final AccountStatusInfo info;
    try {
      info = await AccountService().fetchStatus();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showError(context, e,
          fallback: 'No pudimos revisar tu cuenta. Inténtalo de nuevo.',
          onRetry: _reactivate);
      return;
    }
    // Ya estaba activa (reactivada en otro teléfono): TabsScreen ya cambió de pantalla.
    if (!mounted || !info.isDeactivated) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Reactivar tu cuenta?'),
        content: Text(
          'Tu perfil volverá a estar visible. '
          '${reactivateReadingsText(info.restorableReadings)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reactivar'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed != true) {
      setState(() => _busy = false);
      return;
    }

    // Antes del await: al reactivar, TabsScreen reemplaza esta pantalla por las pestañas.
    final messenger = ScaffoldMessenger.of(context);
    try {
      final restored = await AccountService().reactivate();
      unawaitedHaptic(HapticFeedback.lightImpact());
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(reactivatedMessage(restored))));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showError(context, e, fallback: 'No pudimos reactivar tu cuenta.');
    }
  }

  Future<void> _logout() async {
    setState(() => _busy = true);
    await AuthService().logout();
    if (!mounted) return;
    unawaited(Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lector;
    return LibraryScreen(
      readOnly: true,
      // Indicador compacto y fijo: el estado y "Reactivar" siempre a la vista (el aviso grande
      // de abajo se desplaza con la lista).
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            ExcludeSemantics(
              child: Icon(Icons.pause_circle_outline_rounded, color: c.ink),
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text('Cuenta desactivada', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          Tooltip(
            message: 'Reactivar mi cuenta',
            child: TextButton(
              onPressed: _busy ? null : _reactivate,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: const Text('Reactivar'),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      banner: _DeactivatedBanner(
        busy: _busy,
        onReactivate: _reactivate,
        onLogout: _logout,
      ),
    );
  }
}

/// Aviso fijo arriba de la biblioteca: qué significa estar desactivada y cómo volver.
class _DeactivatedBanner extends StatelessWidget {
  final bool busy;
  final VoidCallback onReactivate;
  final VoidCallback onLogout;

  const _DeactivatedBanner({
    required this.busy,
    required this.onReactivate,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.lector;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        decoration: BoxDecoration(
          color: c.accent.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(ThemeService.radiusCard),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(Icons.pause_circle_outline_rounded,
                      color: c.ink, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Tu cuenta está desactivada',
                      style: ThemeService.titleStyle
                          .copyWith(fontSize: 18, color: c.textPrimary),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Tu perfil está oculto y tus lecturas son privadas. Puedes ver tu '
              'biblioteca; para añadir, editar o compartir, reactiva tu cuenta.',
              style: TextStyle(color: c.textPrimary, fontSize: 15, height: 1.45),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: busy ? null : onReactivate,
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.play_circle_outline_rounded),
              label: const Text('Reactivar mi cuenta'),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: busy ? null : onLogout,
              style: TextButton.styleFrom(
                foregroundColor: c.danger,
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}
