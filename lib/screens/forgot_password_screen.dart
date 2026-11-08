import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../theme/lector_colors.dart';
import '../ui/feedback.dart';
import 'tabs_screen.dart';

/// Recuperar la cuenta con un código de 6 dígitos enviado por email.
///
/// Paso 1: email → "Enviar código". Paso 2: código + contraseña nueva → sesión iniciada.
/// La API no revela si el email existe; por eso el paso 2 dice "si está registrado".
class ForgotPasswordScreen extends StatefulWidget {
  /// Email ya escrito en el login (si el usuario puso un email y no un username).
  final String? initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const _resendSeconds = 60;
  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  late final TextEditingController _emailController;
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _codeSent = false;
  bool _isLoading = false;
  bool _obscure = true;
  String? _emailError;
  String? _codeError;
  String? _passwordError;
  int _resendIn = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String get _email => _emailController.text.trim().toLowerCase();

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendIn = _resendSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  Future<void> _sendCode() async {
    if (!_emailRegex.hasMatch(_email)) {
      setState(() => _emailError = 'Escribe un email válido');
      return;
    }
    setState(() {
      _emailError = null;
      _isLoading = true;
    });
    try {
      await AuthService().requestPasswordReset(_email);
      if (!mounted) return;
      setState(() => _codeSent = true);
      _startResendCountdown();
    } catch (e) {
      if (mounted) showError(context, e, fallback: 'No pudimos enviar el código. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final code = _codeController.text.trim();
    final password = _passwordController.text.trim();
    setState(() {
      _codeError = RegExp(r'^\d{6}$').hasMatch(code) ? null : 'El código tiene 6 dígitos';
      _passwordError = password.length < 8 ? 'Usa al menos 8 caracteres' : null;
    });
    if (_codeError != null || _passwordError != null) return;

    setState(() => _isLoading = true);
    try {
      await AuthService().resetPassword(email: _email, code: code, password: password);
      if (!mounted) return;
      showSuccess(context, 'Listo, tu contraseña se actualizó');
      unawaited(Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const TabsScreen()),
        (_) => false,
      ));
    } catch (e) {
      if (!mounted) return;
      // Código inválido/vencido: se muestra junto al campo, no solo en un aviso.
      if (e is ApiException && e.statusCode == 400) {
        setState(() => _codeError = friendlyError(e));
      } else {
        showError(context, e, fallback: 'No pudimos cambiar la contraseña. Inténtalo de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lector;
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar cuenta')),
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
                        color: c.accent.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _codeSent ? Icons.mark_email_read_outlined : Icons.lock_reset_rounded,
                        size: 40,
                        color: c.ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Semantics(
                  header: true,
                  child: Text(
                    _codeSent ? 'Revisa tu correo' : '¿Olvidaste tu contraseña?',
                    textAlign: TextAlign.center,
                    style: ThemeService.titleStyle.copyWith(fontSize: 24, color: c.textPrimary),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _codeSent
                      ? 'Si $_email está registrado, te enviamos un código de 6 dígitos. '
                          'Vence en 15 minutos. Revisa también la carpeta de spam.'
                      : 'Escribe el email de tu cuenta y te enviaremos un código para crear una contraseña nueva.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.textSecondary, fontSize: 15, height: 1.45),
                ),
                const SizedBox(height: 28),
                if (!_codeSent) ..._buildEmailStep() else ..._buildCodeStep(c),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildEmailStep() => [
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.send,
          autofillHints: const [AutofillHints.email],
          autofocus: (widget.initialEmail ?? '').isEmpty,
          onSubmitted: (_) => _sendCode(),
          decoration: InputDecoration(
            labelText: 'Email',
            prefixIcon: const Icon(Icons.alternate_email_rounded),
            errorText: _emailError,
          ),
        ),
        const SizedBox(height: 24),
        _primaryButton('Enviar código', _sendCode),
      ];

  List<Widget> _buildCodeStep(LectorColors c) => [
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.oneTimeCode],
          autofocus: true,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            labelText: 'Código',
            counterText: '',
            errorText: _codeError,
            errorMaxLines: 2,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
          onSubmitted: (_) => _resetPassword(),
          decoration: InputDecoration(
            labelText: 'Contraseña nueva',
            helperText: 'Al menos 8 caracteres',
            errorText: _passwordError,
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _primaryButton('Cambiar contraseña', _resetPassword),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: _isLoading || _resendIn > 0 ? null : _sendCode,
              child: Text(_resendIn > 0 ? 'Reenviar código en $_resendIn s' : 'Reenviar código'),
            ),
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () => setState(() {
                        _codeSent = false;
                        _codeController.clear();
                        _codeError = null;
                      }),
              child: const Text('Usar otro email'),
            ),
          ],
        ),
      ];

  Widget _primaryButton(String label, VoidCallback onPressed) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton(
      onPressed: _isLoading ? null : onPressed,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      child: _isLoading
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: scheme.onPrimary,
                semanticsLabel: 'Cargando',
              ),
            )
          : Text(label),
    );
  }
}
