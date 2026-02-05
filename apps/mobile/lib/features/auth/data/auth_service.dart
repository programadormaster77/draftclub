import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// ===============================================================
/// 🔐 AuthService — Servicio central de autenticación (versión global)
/// ===============================================================
/// 🔹 Compatibilidad total con email/password.
/// 🔹 Añadido soporte completo para Google y Facebook.
/// 🔹 Crea automáticamente el documento base `users/<uid>`
///     en Firestore al registrarse o autenticarse por primera vez.
/// ===============================================================
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 🔄 Escucha global de cambios de autenticación
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// 🧩 Obtiene el usuario actual
  User? get currentUser => _auth.currentUser;

  // ===============================================================
  // 🧱 REGISTRO / LOGIN TRADICIONAL (EMAIL + PASSWORD)
  // ===============================================================

  /// 🆕 Crear un nuevo usuario con email y contraseña
  Future<User?> signUp(String email, String password) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final user = result.user;
      if (user != null) {
        await _createUserDocument(user);
        debugPrint('✅ Usuario creado y documento base en Firestore listo.');
      }

      return user;
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

      final user = result.user;
      if (user != null) {
        await _createUserDocument(user);
        debugPrint('✅ Sesión iniciada y documento Firestore verificado.');
      }

      return user;
    } on FirebaseAuthException catch (e) {
      debugPrint('⚠️ Error en signIn: ${e.code} — ${e.message}');
      throw Exception(_mapFirebaseError(e.code));
    } catch (e) {
      debugPrint('⚠️ Error desconocido en signIn: $e');
      throw Exception('Error al iniciar sesión.');
    }
  }

  // ===============================================================
  // 🔁 RECUPERACIÓN DE CUENTA (EMAIL)
  // ===============================================================

  /// 📩 Envía correo para restablecer contraseña
  /// ✅ UX seguro: NO revela si existe o no la cuenta asociada al correo.
  ///
  /// IMPORTANTE:
  /// - Si Firebase devuelve `user-not-found`, tratamos como éxito silencioso.
  /// - Los únicos errores que vale la pena propagar son: correo inválido,
  ///   correo faltante, rate limit, etc.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      debugPrint('📩 Solicitud de restablecimiento enviada (si aplica).');
    } on FirebaseAuthException catch (e) {
      debugPrint('⚠️ Error en sendPasswordResetEmail: ${e.code} — ${e.message}');

      // ✅ UX seguro: éxito silencioso para evitar enumeración de cuentas
      if (e.code == 'user-not-found') {
        debugPrint('🟡 user-not-found: manejado como éxito silencioso por UX.');
        return;
      }

      throw Exception(_mapFirebaseError(e.code));
    } catch (e) {
      debugPrint('⚠️ Error desconocido en sendPasswordResetEmail: $e');
      throw Exception('No se pudo iniciar la recuperación. Intenta de nuevo.');
    }
  }

  // ===============================================================
  // 🔵 LOGIN CON GOOGLE
  // ===============================================================

  Future<User?> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint('🟡 Inicio de sesión con Google cancelado por el usuario.');
        return null;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      final user = result.user;

      if (user != null) {
        await _createUserDocument(user);
        debugPrint('✅ Sesión iniciada con Google: ${user.email}');
      }

      return user;
    } on FirebaseAuthException catch (e) {
      debugPrint('⚠️ Error Google Sign-In: ${e.code} — ${e.message}');
      throw Exception('Error al iniciar sesión con Google.');
    } catch (e) {
      debugPrint('⚠️ Error desconocido en Google Sign-In: $e');
      throw Exception('Error al autenticar con Google.');
    }
  }

  // ===============================================================
  // 🔷 LOGIN CON FACEBOOK
  // ===============================================================

  Future<User?> signInWithFacebook() async {
    try {
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );

      if (result.status == LoginStatus.success) {
        final AccessToken token = result.accessToken!;
        final facebookCredential =
            FacebookAuthProvider.credential(token.tokenString);

        final userCred = await _auth.signInWithCredential(facebookCredential);
        final user = userCred.user;

        if (user != null) {
          await _createUserDocument(user);
          debugPrint('✅ Sesión iniciada con Facebook: ${user.email}');
        }

        return user;
      } else if (result.status == LoginStatus.cancelled) {
        debugPrint('🟡 Inicio de sesión con Facebook cancelado.');
        return null;
      } else {
        debugPrint('⚠️ Error Facebook Login: ${result.message}');
        throw Exception(
            'Error desconocido en el inicio de sesión con Facebook.');
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('⚠️ Error FacebookAuth: ${e.code} — ${e.message}');
      throw Exception('Error al iniciar sesión con Facebook.');
    } catch (e) {
      debugPrint('⚠️ Error general en Facebook Sign-In: $e');
      throw Exception('Ocurrió un error al autenticar con Facebook.');
    }
  }

  // ===============================================================
  // 🚪 CIERRE DE SESIÓN
  // ===============================================================

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await GoogleSignIn().signOut();
      await FacebookAuth.instance.logOut();

      debugPrint('✅ Sesión cerrada correctamente.');
    } on FirebaseAuthException catch (e) {
      debugPrint('⚠️ Error al cerrar sesión: ${e.code} — ${e.message}');
      throw Exception('No se pudo cerrar sesión. Intenta de nuevo.');
    } catch (e) {
      debugPrint('⚠️ Error desconocido al cerrar sesión: $e');
      throw Exception('Ocurrió un error al cerrar sesión.');
    }
  }

  // ===============================================================
  // 🧩 Creación / verificación del documento Firestore del usuario
  // ===============================================================

  Future<void> _createUserDocument(User user) async {
    final userDoc =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snapshot = await userDoc.get();

    if (!snapshot.exists) {
      await userDoc.set({
        'uid': user.uid,
        'email': user.email,
        'name': user.displayName ?? '',
        'photoUrl': user.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('🧾 Documento base creado en Firestore para ${user.email}');
    }
  }

  // ===============================================================
  // 🧠 Traductor de errores Firebase → mensajes legibles
  // ===============================================================

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'El correo electrónico no es válido.';
      case 'missing-email':
        return 'Debes ingresar un correo electrónico.';
      case 'user-disabled':
        return 'Esta cuenta ha sido desactivada.';
      case 'user-not-found':
        // ⚠️ Para login puede usarse, pero en LoginPage ya lo convertimos a mensaje neutro.
        return 'No se encontró ninguna cuenta con ese correo.';
      case 'wrong-password':
        return 'Contraseña incorrecta.';
      case 'email-already-in-use':
        return 'Este correo ya está registrado.';
      case 'weak-password':
        return 'La contraseña es demasiado débil.';
      case 'too-many-requests':
        return 'Demasiados intentos, intenta más tarde.';
      default:
        return 'Ocurrió un error inesperado. Intenta de nuevo.';
    }
  }
}
