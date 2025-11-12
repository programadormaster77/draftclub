import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/auth_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';

/// ===============================================================
/// ⚽ DraftClub — Login/Registro Premium (glass optimizado, fondo visible)
/// ===============================================================
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

  // ===============================================================
  // 🧠 Flujo principal de login / registro
  // ===============================================================
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
    } catch (e) {
      setState(() => errorMessage = 'Error inesperado: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    try {
      setState(() => isLoading = true);
      final user = await _authService.signInWithGoogle();
      if (user != null) debugPrint('✅ Google: ${user.email}');
    } catch (_) {
      setState(() => errorMessage = 'Error al conectar con Google.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ===============================================================
  // 🎨 UI — Versión final con transparencia calibrada
  // ===============================================================
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              fit: StackFit.expand,
              children: [
                // 🏟️ Fondo futbolístico
                Image.asset(
                  'assets/backgrounds/login_bg.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),

                // 🌈 Iluminación dinámica más viva
                AnimatedContainer(
                  duration: const Duration(seconds: 5),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 1.5,
                      colors: [
                        Colors.blueAccent.withOpacity(0.35),
                        Colors.amberAccent.withOpacity(0.12),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .moveY(begin: -0.02, end: 0.02, duration: 5.seconds),

                // 🌌 Capa oscura ligera (para mantener contraste sin apagar fondo)
                Container(color: Colors.black.withOpacity(0.25)),

                // 💎 Contenedor principal (Glass Blur optimizado)
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    top: 30,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 40,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight * 0.8,
                      ),
                      child: IntrinsicHeight(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: 10,
                              sigmaY: 10,
                            ), // 🔥 Blur más ligero → fondo más visible
                            child: Container(
                              width: size.width * 0.88,
                              constraints: const BoxConstraints(maxWidth: 430),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 36,
                              ),
                              decoration: BoxDecoration(
                                // 🔵 Más transparencia → siluetas perceptibles
                                color: Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(26),
                                border: Border.all(
                                  color: Colors.white
                                      .withOpacity(0.15), // borde visible
                                  width: 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blueAccent.withOpacity(0.18),
                                    blurRadius: 25,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: _buildContent(context),
                            ),
                          ),
                        ).animate().fadeIn(duration: 900.ms).slideY(begin: 0.1),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ===============================================================
  // 🧩 Contenido principal
  // ===============================================================
  Widget _buildContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/icons/draftclub_logo.png', height: 80)
            .animate()
            .fadeIn(duration: 600.ms),
        const SizedBox(height: 10),
        const Text(
          'Tu carrera comienza aquí',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'DraftClub',
          style: TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const Text(
          'Tu carrera, tu club.',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        const SizedBox(height: 32),
        _buildInputField(
          controller: _emailController,
          label: 'Correo electrónico',
          icon: Icons.email_outlined,
        ),
        const SizedBox(height: 16),
        _buildInputField(
          controller: _passwordController,
          label: 'Contraseña',
          icon: Icons.lock_outline,
          isPassword: true,
        ),
        const SizedBox(height: 24),
        _buildMainButton(),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () => setState(() => isLogin = !isLogin),
          child: Text(
            isLogin
                ? '¿No tienes cuenta? Regístrate'
                : '¿Ya tienes cuenta? Inicia sesión',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: const [
            Expanded(child: Divider(color: Colors.white24)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'O continúa con',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
            Expanded(child: Divider(color: Colors.white24)),
          ],
        ),
        const SizedBox(height: 22),
        Center(
          child: _socialButton(
            asset: 'assets/icons/google_logo.png',
            color: const Color(0xFFDB4437),
            onTap: _handleGoogleLogin,
          ),
        ),
        if (errorMessage.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            errorMessage,
            style: const TextStyle(color: Colors.redAccent),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  // ===============================================================
  // 🔧 Widgets auxiliares
  // ===============================================================
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
      ),
    );
  }

  Widget _buildMainButton() {
    return ElevatedButton(
      onPressed: isLoading ? null : _handleAuth,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueAccent,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        shadowColor: Colors.blueAccent.withOpacity(0.4),
        elevation: 6,
      ),
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Text(
              isLogin ? 'Iniciar sesión' : 'Crear cuenta',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }

  Widget _socialButton({
    required String asset,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: 60,
        height: 60,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.1),
          border: Border.all(color: color, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Image.asset(asset, fit: BoxFit.contain),
      ),
    );
  }
}
