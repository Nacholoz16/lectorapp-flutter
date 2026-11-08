import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'tabs_screen.dart'; // A donde iremos tras loguearnos
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import '../theme/lector_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import '../ui/feedback.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Equivalente a tu objeto 'credentials'
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _onLogin() async {
    setState(() => _isLoading = true);

    try {
      await AuthService().login(
        _identifierController.text.trim(),
        _passwordController.text.trim(),
      );

      // Si el login es exitoso, navegamos a los Tabs (Home) destruyendo la pantalla de login
      if (mounted) {
        unawaited(Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const TabsScreen()),
        ));
      }
    } catch (e) {
      if (mounted) {
        showError(context, e, fallback: 'No pudimos iniciar sesión. Inténtalo de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Usamos el color primario del tema actual
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          // Añadido para evitar desbordes con el teclado
          padding: const EdgeInsets.all(32.0), // Un poco más de margen lateral
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              // Logo suave
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.auto_stories, size: 64, color: primaryColor),
              ),
              const SizedBox(height: 24),
              Text(
                'LectorApp',
                style: GoogleFonts.lora(
                  textStyle: Theme.of(context).textTheme.headlineMedium,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tu rincón de lectura acogedor',
                style: TextStyle(color: context.lector.textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 48),

              // Inputs ultra limpios (El ThemeService dibuja el fondo y los bordes redondos)
              TextField(
                controller: _identifierController,
                decoration: InputDecoration(
                  hintText:
                      'Email o Usuario', // Usamos hintText para un look más moderno
                  prefixIcon: Icon(Icons.person_outline, color: context.lector.textSecondary),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Contraseña',
                  prefixIcon: Icon(Icons.lock_outline, color: context.lector.textSecondary),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    final id = _identifierController.text.trim();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ForgotPasswordScreen(
                          initialEmail: id.contains('@') ? id : null,
                        ),
                      ),
                    );
                  },
                  child: const Text('¿Olvidaste tu contraseña?'),
                ),
              ),
              const SizedBox(height: 24),

              // Botón de Login (El ThemeService le da la forma de píldora y el color)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _onLogin,
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Theme.of(context).colorScheme.onPrimary, strokeWidth: 2))
                      : const Text('Ingresar',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),

              // Botón de registro discreto
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('¿Aún no tienes tu biblioteca?',
                      style: TextStyle(color: context.lector.textSecondary)),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const RegisterScreen()),
                      );
                    },
                    child: Text(
                      'Regístrate',
                      style: TextStyle(
                          color: primaryColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
