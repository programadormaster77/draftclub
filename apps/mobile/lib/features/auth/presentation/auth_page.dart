import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/auth_service.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool isLogin = true;
  bool isLoading = false;

  Future<void> _handleAuth() async {
    setState(() => isLoading = true);
    try {
      if (isLogin) {
        await _authService.signIn(
          _emailController.text,
          _passwordController.text,
        );
      } else {
        await _authService.signUp(
          _emailController.text,
          _passwordController.text,
        );
      }

      if (!mounted) return;
      context.go('/feed');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0E),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.sports_soccer, color: Colors.white, size: 80),
                const SizedBox(height: 20),
                Text(
                  isLogin ? 'Iniciar sesión' : 'Crear cuenta',
                  style: const TextStyle(
                    fontSize: 26,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 25),

                // Campo Email
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Correo electrónico',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),

                // Campo Contraseña
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 25),

                // Botón principal
                ElevatedButton(
                  onPressed: isLoading ? null : _handleAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0E6FFF),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          isLogin ? 'Entrar' : 'Registrarme',
                          style: const TextStyle(fontSize: 18),
                        ),
                ),
                const SizedBox(height: 15),

                // Texto alternativo
                TextButton(
                  onPressed: () {
                    setState(() {
                      isLogin = !isLogin;
                    });
                  },
                  child: Text(
                    isLogin
                        ? '¿No tienes cuenta? Crear una'
                        : '¿Ya tienes cuenta? Inicia sesión',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
