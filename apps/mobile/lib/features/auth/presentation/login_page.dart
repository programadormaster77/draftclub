import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool isLogin = true;
  bool isLoading = false;
  String errorMessage = '';

  Future<void> _handleAuth() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      User? user;
      if (isLogin) {
        user = await _authService.signIn(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } else {
        user = await _authService.signUp(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      }

      if (user == null) {
        setState(() {
          errorMessage = 'No se pudo iniciar sesión. Intenta nuevamente.';
        });
      }

      // 🚫 NO navegamos manualmente
      // 🔥 AuthStateHandler detectará automáticamente el cambio en la sesión
      // y redirigirá al flujo correcto (ProfileGate → Dashboard o ProfileSetup)
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = switch (e.code) {
          'user-not-found' => 'No existe un usuario con ese correo.',
          'wrong-password' => 'Contraseña incorrecta.',
          'invalid-email' => 'Correo inválido.',
          'email-already-in-use' => 'Este correo ya está registrado.',
          'weak-password' => 'La contraseña es demasiado débil.',
          'too-many-requests' => 'Demasiados intentos, intenta más tarde.',
          _ => 'Error: ${e.message ?? 'Error desconocido.'}',
        };
      });
      debugPrint('Error FirebaseAuth: ${e.code} - ${e.message}');
    } catch (e) {
      setState(() {
        errorMessage = 'Error inesperado: $e';
      });
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'DraftClub ⚽',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey)),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey)),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue)),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: isLoading ? null : _handleAuth,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 50),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        isLogin ? 'Iniciar sesión' : 'Registrarse',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                      ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => setState(() => isLogin = !isLogin),
                child: Text(
                  isLogin
                      ? '¿No tienes cuenta? Regístrate'
                      : '¿Ya tienes cuenta? Inicia sesión',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              if (errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    errorMessage,
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
