import 'dart:async';

import 'package:flutter/material.dart';

import '../services/account_service.dart';
import '../services/api_client.dart';
import '../services/theme_service.dart';
import '../theme/lector_colors.dart';
import '../ui/account_copy.dart';
import '../ui/feedback.dart';
import '../widgets/state_views.dart';

/// Perfil → ⚙ → Cuenta → "Desactivar mi cuenta" (tarea 2.1, decisión D7).
///
/// Explica ANTES de confirmar qué va a pasar (cuántas lecturas públicas pasarán a privadas,
/// perfil oculto, biblioteca en modo lectura), pide la contraseña y una última confirmación.
/// Al terminar, la app pasa sola al modo solo lectura (ver `TabsScreen`).
class DeactivateAccountScreen extends StatefulWidget {
  const DeactivateAccountScreen({super.key});

  @override
  State<DeactivateAccountScreen> createState() =>
      _DeactivateAccountScreenState();
}

class _DeactivateAccountScreenState extends State<DeactivateAccountScreen> {
  final _passwordController = TextEditingController();

  AccountStatusInfo? _info;
  String? _loadError;
  bool _obscure = true;
  bool _submitting = false;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  /// Pide a la API cuántas lecturas públicas hay: el texto lo dice antes de confirmar.
  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final info = await AccountService().fetchStatus();
      if (!mounted) return;
      setState(() => _info = info);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError =
          friendlyError(e, fallback: 'No pudimos cargar los datos de tu cuenta.'));
    }
  }

  Future<void> _submit() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      setState(() => _passwordError = 'Escribe tu contraseña para confirmar');
      return;
    }
    setState(() => _passwordError = null);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Desactivar tu cuenta?'),
        content: Text(
          '${deactivateReadingsText(_info?.publicReadings ?? 0)} '
          'Tu perfil quedará oculto hasta que la reactives.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Se capturan antes del await: al desactivar, TabsScreen cambia al modo solo lectura y
    // esta pantalla se cierra.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _submitting = true);
    try {
      final hidden = await AccountService().deactivate(password);
      navigator.popUntil((route) => route.isFirst);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(deactivatedMessage(hidden))));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      if (e.isInvalidPassword) {
        // Junto al campo, no solo en un aviso; lo escrito se conserva para corregirlo.
        setState(() => _passwordError = 'La contraseña no es correcta');
      } else {
        showError(context, e, fallback: 'No pudimos desactivar tu cuenta.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showError(context, e, fallback: 'No pudimos desactivar tu cuenta.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Desactivar mi cuenta')),
      body: SafeArea(
        child: _loadError != null
            ? ErrorState(message: _loadError!, onRetry: _load)
            : _info == null
                ? const Center(child: CircularProgressIndicator())
                : _buildContent(context.lector, _info!),
      ),
    );
  }

  Widget _buildContent(LectorColors c, AccountStatusInfo info) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(
              child: Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.pause_circle_outline_rounded,
                      size: 40, color: c.ink),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Semantics(
              header: true,
              child: Text(
                'Tómate un descanso',
                textAlign: TextAlign.center,
                style: ThemeService.titleStyle
                    .copyWith(fontSize: 24, color: c.textPrimary),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Desactivar tu cuenta es temporal: tu biblioteca se queda contigo y '
              'puedes volver cuando quieras.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 15, height: 1.45),
            ),
            const SizedBox(height: 24),
            _Point(
              icon: Icons.lock_outline_rounded,
              text: deactivateReadingsText(info.publicReadings),
            ),
            const _Point(
              icon: Icons.visibility_off_outlined,
              text: 'Tu perfil quedará oculto: nadie podrá verlo y tus '
                  '"me gusta" dejarán de contar mientras tanto.',
            ),
            const _Point(
              icon: Icons.collections_bookmark_outlined,
              text: 'Podrás entrar y ver tu biblioteca, pero no añadir, editar '
                  'ni compartir lecturas.',
            ),
            const _Point(
              icon: Icons.replay_rounded,
              text: 'Para volver, entra a LectorApp y toca "Reactivar mi cuenta".',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _obscure,
              enabled: !_submitting,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Tu contraseña',
                helperText: 'Para confirmar que eres tú',
                errorText: _passwordError,
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
                  icon: Icon(_obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              child: _submitting
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Theme.of(context).colorScheme.onPrimary,
                        semanticsLabel: 'Desactivando',
                      ),
                    )
                  : const Text('Desactivar mi cuenta'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una línea de la explicación: ícono decorativo + frase.
class _Point extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Point({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final c = context.lector;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Icon(icon, color: c.ink, size: 24)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: c.textPrimary, fontSize: 15, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
