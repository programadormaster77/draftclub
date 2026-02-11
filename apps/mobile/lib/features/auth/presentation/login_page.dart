import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../data/auth_service.dart';
import 'forgot_password_page.dart';

/// ===============================================================
/// ⚽ DraftClub — Login/Registro Premium (con password fuerte + ojito)
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
  final _confirmController = TextEditingController();

  bool isLogin = true;
  bool isLoading = false;
  String errorMessage = '';

  bool _showPassword = false;
  bool _showConfirm = false;

  // =========================
  // 🔐 Reglas password fuerte
  // =========================
  bool get _hasMinLen => _passwordController.text.length >= 8;
  bool get _hasUpper => RegExp(r'[A-Z]').hasMatch(_passwordController.text);
  bool get _hasLower => RegExp(r'[a-z]').hasMatch(_passwordController.text);
  bool get _hasNumber => RegExp(r'\d').hasMatch(_passwordController.text);
  bool get _hasSpecial =>
      RegExp(r'[!@#$%^&*(),.?":{}|<>_\-\[\]\\\/~`+=;]').hasMatch(_passwordController.text);
  bool get _noSpaces => !RegExp(r'\s').hasMatch(_passwordController.text);

  int get _strengthScore => [
        _hasMinLen,
        _hasUpper,
        _hasLower,
        _hasNumber,
        _hasSpecial,
        _noSpaces,
      ].where((e) => e).length;

  bool get _passwordStrong => _strengthScore == 6;

  bool get _passwordsMatch =>
      _passwordController.text.isNotEmpty &&
      _passwordController.text == _confirmController.text;

  bool get _canSubmit {
    if (isLoading) return false;
    if (_emailController.text.trim().isEmpty) return false;
    if (_passwordController.text.trim().isEmpty) return false;

    if (isLogin) {
      // En login NO bloqueamos por password fuerte (si el usuario ya tenía una clave vieja).
      return true;
    }

    // En registro SÍ exigimos fuerte + confirmación
    return _passwordStrong && _passwordsMatch;
  }

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onTyping);
    _confirmController.addListener(_onTyping);
    _emailController.addListener(_onTyping);
  }

  void _onTyping() {
    if (!mounted) return;
    setState(() {
      // refresca checklist + botón
      if (errorMessage.isNotEmpty) errorMessage = '';
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

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
        // 🔐 Validación extra por seguridad (aunque el botón ya bloquea)
        if (!_passwordStrong) {
          setState(() => errorMessage = 'Tu contraseña no cumple los requisitos de seguridad.');
          return;
        }
        if (!_passwordsMatch) {
          setState(() => errorMessage = 'Las contraseñas no coinciden.');
          return;
        }

        user = await _authService.signUp(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      }

      if (user == null) {
        setState(() => errorMessage = 'No se pudo iniciar sesión. Intenta nuevamente.');
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        // ✅ UX seguro: no confirmamos existencia de cuenta.
        errorMessage = switch (e.code) {
          'wrong-password' => 'Correo o contraseña incorrectos.',
          'user-not-found' => 'Correo o contraseña incorrectos.',
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
  // 🎨 UI — Premium glass (misma estética)
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
                Image.asset(
                  'assets/backgrounds/login_bg.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),

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

                Container(color: Colors.black.withOpacity(0.25)),

                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    top: 30,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 40,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight * 0.8),
                      child: IntrinsicHeight(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              width: size.width * 0.88,
                              constraints: const BoxConstraints(maxWidth: 430),
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(26),
                                border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.0),
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

  Widget _buildContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/icons/draftclub_logo.png', height: 80).animate().fadeIn(duration: 600.ms),
        const SizedBox(height: 10),
        Text(
          isLogin ? 'Tu carrera comienza aquí' : 'Crea tu cuenta y arranca',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.8,
          ),
          textAlign: TextAlign.center,
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
        const Text('Tu carrera, tu club.', style: TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 32),

        _buildInputField(
          controller: _emailController,
          label: 'Correo electrónico',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),

        _buildPasswordField(
          controller: _passwordController,
          label: 'Contraseña',
          icon: Icons.lock_outline,
          show: _showPassword,
          onToggle: () => setState(() => _showPassword = !_showPassword),
        ),

        // ✅ Recuperación (solo login)
        if (isLogin) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: isLoading
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ForgotPasswordPage(
                            prefilledEmail: _emailController.text.trim(),
                          ),
                        ),
                      );
                    },
              child: const Text(
                '¿Olvidaste tu contraseña?',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
        ],

        // ✅ Confirmar + seguridad (solo registro)
        if (!isLogin) ...[
          const SizedBox(height: 16),
          _buildPasswordField(
            controller: _confirmController,
            label: 'Confirmar contraseña',
            icon: Icons.verified_outlined,
            show: _showConfirm,
            onToggle: () => setState(() => _showConfirm = !_showConfirm),
          ),
          const SizedBox(height: 14),
          _PasswordStrengthCard(
            score: _strengthScore,
            hasMinLen: _hasMinLen,
            hasUpper: _hasUpper,
            hasLower: _hasLower,
            hasNumber: _hasNumber,
            hasSpecial: _hasSpecial,
            noSpaces: _noSpaces,
            matches: _passwordsMatch,
          ),
        ],

        const SizedBox(height: 16),
        _buildMainButton(),

        const SizedBox(height: 20),
        TextButton(
          onPressed: () => setState(() {
            isLogin = !isLogin;
            errorMessage = '';
          }),
          child: Text(
            isLogin ? '¿No tienes cuenta? Regístrate' : '¿Ya tienes cuenta? Inicia sesión',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),

        const SizedBox(height: 10),
        Row(
          children: const [
            Expanded(child: Divider(color: Colors.white24)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('O continúa con', style: TextStyle(color: Colors.grey, fontSize: 12)),
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
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

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool show,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: !show,
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
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            show ? Icons.visibility_off : Icons.visibility,
            color: Colors.white70,
          ),
          tooltip: show ? 'Ocultar' : 'Mostrar',
        ),
      ),
    );
  }

  Widget _buildMainButton() {
    return ElevatedButton(
      onPressed: _canSubmit ? _handleAuth : null,
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
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
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
      onTap: isLoading ? null : onTap,
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

/// ===============================================================
/// 🔐 Password Strength Card (estética DraftClub)
// ===============================================================
class _PasswordStrengthCard extends StatelessWidget {
  final int score; // 0..6
  final bool hasMinLen;
  final bool hasUpper;
  final bool hasLower;
  final bool hasNumber;
  final bool hasSpecial;
  final bool noSpaces;
  final bool matches;

  const _PasswordStrengthCard({
    required this.score,
    required this.hasMinLen,
    required this.hasUpper,
    required this.hasLower,
    required this.hasNumber,
    required this.hasSpecial,
    required this.noSpaces,
    required this.matches,
  });

  @override
  Widget build(BuildContext context) {
   final double pct = (score / 6).toDouble().clamp(0.0, 1.0);


    Color barColor;
    if (score <= 2) {
      barColor = Colors.redAccent;
    } else if (score <= 4) {
      barColor = Colors.amberAccent;
    } else {
      barColor = const Color(0xFF4CD964);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barra
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 10,
              color: Colors.white.withOpacity(0.10),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: pct,
                child: Container(color: barColor),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Checklist en 2 columnas
          Wrap(
            runSpacing: 8,
            spacing: 12,
            children: [
              _RuleChip(ok: hasMinLen, text: '8+ caracteres'),
              _RuleChip(ok: hasUpper, text: '1 mayúscula'),
              _RuleChip(ok: hasLower, text: '1 minúscula'),
              _RuleChip(ok: hasNumber, text: '1 número'),
              _RuleChip(ok: hasSpecial, text: '1 símbolo'),
              _RuleChip(ok: noSpaces, text: 'sin espacios'),
            ],
          ),
          const SizedBox(height: 10),

          // Confirmación
          Row(
            children: [
              Icon(
                matches ? Icons.verified : Icons.info_outline,
                size: 16,
                color: matches ? const Color(0xFF4CD964) : Colors.white70,
              ),
              const SizedBox(width: 8),
              Text(
                matches ? 'Las contraseñas coinciden' : 'Confirma la contraseña arriba',
                style: TextStyle(
                  color: matches ? const Color(0xFF4CD964) : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RuleChip extends StatelessWidget {
  final bool ok;
  final String text;

  const _RuleChip({required this.ok, required this.text});

  @override
  Widget build(BuildContext context) {
    final c = ok ? const Color(0xFF4CD964) : Colors.white.withOpacity(0.22);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(ok ? 0.75 : 1.0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ok ? c : Colors.transparent,
              border: Border.all(color: c, width: 1),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: ok ? c : Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
