import 'package:flutter/material.dart';
import 'auth_controller.dart';
import 'package:provider/provider.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthController>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0E),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const Text(
                  'Crear cuenta',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white)),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white)),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _loading
                      ? null
                      : () async {
                          setState(() => _loading = true);
                          final error = await auth.register(
                            _emailController.text.trim(),
                            _passwordController.text.trim(),
                          );
                          setState(() => _loading = false);
                          if (error != null) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text(error)));
                          } else {
                            Navigator.pop(context);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent[400],
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text('Registrarse',
                          style: TextStyle(fontSize: 18, color: Colors.black)),
                ),
                const SizedBox(height: 15),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('¿Ya tienes cuenta? Inicia sesión',
                      style: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
