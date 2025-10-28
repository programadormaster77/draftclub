import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// ===============================================================
/// 🔐 AuthService — Servicio central de autenticación
/// ===============================================================
/// Maneja el flujo de:
///  - Registro de usuarios
///  - Inicio de sesión
///  - Cierre de sesión
///  - Escucha en tiempo real del estado de autenticación
/// ===============================================================
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 🔄 Escucha global de cambios de autenticación
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// 🧩 Obtiene el usuario actual
  User? get currentUser => _auth.currentUser;

  /// 🆕 Crear un nuevo usuario con email y contraseña
  Future<User?> signUp(String email, String password) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('⚠️ Error en signUp: ${e.code} — ${e.message}');
      throw Exception(_mapFirebaseError(e.code));
    } catch (e) {
      debugPrint('⚠️ Error desconocido en signUp: $e');
      throw Exception('Error al registrar el usuario.');
    }
  }

  /// 🔑 Iniciar sesión con email y contraseña
  Future<User?> signIn(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('⚠️ Error en signIn: ${e.code} — ${e.message}');
      throw Exception(_mapFirebaseError(e.code));
    } catch (e) {
      debugPrint('⚠️ Error desconocido en signIn: $e');
      throw Exception('Error al iniciar sesión.');
    }
  }

  /// 🚪 Cerrar sesión del usuario actual
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      debugPrint('✅ Sesión cerrada correctamente.');
    } on FirebaseAuthException catch (e) {
      debugPrint('⚠️ Error al cerrar sesión: ${e.code} — ${e.message}');
      throw Exception('No se pudo cerrar sesión. Intenta de nuevo.');
    } catch (e) {
      debugPrint('⚠️ Error desconocido al cerrar sesión: $e');
      throw Exception('Ocurrió un error al cerrar sesión.');
    }
  }

  /// 🧠 Traductor de errores de FirebaseAuth a mensajes más claros
  String _mapFirebaseError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'El correo electrónico no es válido.';
      case 'user-disabled':
        return 'Esta cuenta ha sido desactivada.';
      case 'user-not-found':
        return 'No se encontró ninguna cuenta con ese correo.';
      case 'wrong-password':
        return 'Contraseña incorrecta.';
      case 'email-already-in-use':
        return 'Este correo ya está registrado.';
      case 'weak-password':
        return 'La contraseña es demasiado débil.';
      default:
        return 'Ocurrió un error inesperado. Intenta de nuevo.';
    }
  }
}
