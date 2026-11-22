import 'dart:async';

import 'package:flutter/material.dart';

import '../services/account_service.dart';
import '../services/api_client.dart';
import '../services/theme_service.dart';
import '../theme/lector_colors.dart';
import '../ui/account_copy.dart';
import '../ui/feedback.dart';
import 'deactivate_account_screen.dart';
import 'login_screen.dart';

/// Perfil → ⚙ → Cuenta → "Eliminar mi cuenta" (tarea 2.2). También se llega desde el modo solo
/// lectura de una cuenta desactivada (`DeactivatedScreen`).
///
/// Explica qué se borra (y qué no), ofrece desactivar como alternativa si la cuenta está activa,
/// pide la contraseña y una confirmación final. Al terminar limpia el teléfono y vuelve a Login.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _passwordController = TextEditingController();

  bool _obscure = true;
  bool _submitting = false;
  String? _passwordError;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      setState(() => _passwordError = 'Escribe tu contraseña para confirmar');
      return;
    }
    setState(() => _passwordError = null);

    final danger = context.lector.danger;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar tu cuenta para siempre?'),
        content: const Text(
          'Se borrarán tu cuenta, tus lecturas, reseñas, sesiones y metas. '
          'No podremos recuperarlas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: danger),
            child: const Text('Eliminar para siempre'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Se capturan antes del await: al terminar se reemplaza toda la pila por Login.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _submitting = true);
    try {
      await AccountService().deleteAccount(password);
      unawaited(navigator.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      ));
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(accountDeletedMessage)));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      if (e.isInvalidPassword) {
        // Junto al campo; lo escrito se conserva para corregirlo. La sesión sigue intacta.
        setState(() => _passwordError = 'La contraseña no es correcta');
      } else {
        showError(context, e, fallback: 'No pudimos eliminar tu cuenta.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showError(context, e, fallback: 'No pudimos eliminar tu cuenta.');
    }
  }

  void _openDeactivate() {
    unawaited(Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) => const DeactivateAccountScreen(),
    )));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lector;
    // La alternativa "desactivar" solo tiene sentido si la cuenta está activa.
    final isActive = !AccountService().isDeactivated.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Eliminar mi cuenta')),
      body: SafeArea(
        child: SingleChildScrollView(
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
                        color: c.danger.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.delete_forever_outlined,
                          size: 40, color: c.danger),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Semantics(
                  header: true,
                  child: Text(
                    'Eliminar tu cuenta para siempre',
                    textAlign: TextAlign.center,
                    style: ThemeService.titleStyle
                        .copyWith(fontSize: 24, color: c.textPrimary),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Se borra todo lo que guardaste en LectorApp. No se puede deshacer.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.textSecondary, fontSize: 15, height: 1.45),
                ),
                const SizedBox(height: 24),
                const _Point(
                  icon: Icons.menu_book_outlined,
                  text: 'Tus lecturas, reseñas y notas, públicas y privadas.',
                ),
                const _Point(
                  icon: Icons.timer_outlined,
                  text: 'Tus sesiones de lectura, tu reto anual y tus estadísticas.',
                ),
                const _Point(
                  icon: Icons.favorite_border_rounded,
                  text: 'Los "me gusta" que diste y los que recibieron tus reseñas.',
                ),
                const _Point(
                  icon: Icons.person_off_outlined,
                  text: 'Tu perfil y tu sesión en todos tus dispositivos. Tu nombre de '
                      'usuario y tu correo quedarán libres.',
                ),
                const _Point(
                  icon: Icons.local_library_outlined,
                  text: 'Los libros del catálogo no se borran: los comparten todos los '
                      'lectores.',
                ),
                if (isActive) ...[
                  const SizedBox(height: 4),
                  _BreakCard(onDeactivate: _submitting ? null : _openDeactivate),
                ],
                const SizedBox(height: 24),
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
                // Botón destructivo: fondo `danger` y texto `onInk` (contraste verificado en
                // test/theme_contrast_test.dart para los 4 temas).
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: c.danger,
                    foregroundColor: c.onInk,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: _submitting
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: c.onInk,
                            semanticsLabel: 'Eliminando tu cuenta',
                          ),
                        )
                      : const Text('Eliminar mi cuenta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Alternativa reversible: "¿Solo quieres un descanso?" → desactivar.
class _BreakCard extends StatelessWidget {
  final VoidCallback? onDeactivate;

  const _BreakCard({required this.onDeactivate});

  @override
  Widget build(BuildContext context) {
    final c = context.lector;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: c.accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(ThemeService.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              '¿Solo quieres un descanso?',
              style: ThemeService.titleStyle.copyWith(fontSize: 18, color: c.textPrimary),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Desactiva tu cuenta: tu perfil se oculta y tu biblioteca te espera '
            'para cuando quieras volver.',
            style: TextStyle(color: c.textPrimary, fontSize: 15, height: 1.45),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: onDeactivate,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: const Text('Desactivar mi cuenta'),
            ),
          ),
        ],
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
