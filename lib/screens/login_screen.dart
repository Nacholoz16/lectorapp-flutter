import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'tabs_screen.dart'; // A donde iremos tras loguearnos
import 'register_screen.dart';

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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const TabsScreen()),
        );
      }
    } catch (e) {
      // Equivalente a tu ToastController
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.auto_stories, size: 64, color: primaryColor),
              ),
              const SizedBox(height: 24),
              Text(
                'LectorApp',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFamily:
                          'Lora', // Forzamos Lora para el título principal
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tu rincón de lectura acogedor',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 48),

              // Inputs ultra limpios (El ThemeService dibuja el fondo y los bordes redondos)
              TextField(
                controller: _identifierController,
                decoration: const InputDecoration(
                  hintText:
                      'Email o Usuario', // Usamos hintText para un look más moderno
                  prefixIcon: Icon(Icons.person_outline, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: 'Contraseña',
                  prefixIcon: Icon(Icons.lock_outline, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 40),

              // Botón de Login (El ThemeService le da la forma de píldora y el color)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _onLogin,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
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
                  const Text('¿Aún no tienes tu biblioteca?',
                      style: TextStyle(color: Colors.grey)),
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
