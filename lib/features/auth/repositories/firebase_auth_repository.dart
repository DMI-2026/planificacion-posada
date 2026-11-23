import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/errors/auth_failure.dart';
import '../models/usuario.dart';
import 'auth_repository.dart';

/// Traduce el código de error de Firebase a una falla de la app.
AuthFailure authFailureDesde(String codigo) => switch (codigo) {
  'invalid-credential' ||
  'wrong-password' ||
  'user-not-found' ||
  'invalid-email' => const CredencialesInvalidas(),
  'email-already-in-use' => const CorreoYaRegistrado(),
  'weak-password' => const ContrasenaDebil(),
  'too-many-requests' => const DemasiadosIntentos(),
  'network-request-failed' => const SinConexion(),
  _ => const AuthDesconocida(),
};

/// Arma un [Usuario] a partir de los datos (posiblemente nulos) de Firebase.
Usuario usuarioDesdeDatos({
  required String uid,
  required String? correo,
  required String? nombre,
}) => Usuario(id: uid, correo: correo ?? '', nombre: nombre ?? '');

Usuario? _aUsuario(User? u) => u == null
    ? null
    : usuarioDesdeDatos(uid: u.uid, correo: u.email, nombre: u.displayName);

/// Sesión con Firebase Auth (correo y contraseña).
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  /// Firebase guarda la sesión en el dispositivo: al abrir la app este stream
  /// emite al usuario que ya había entrado.
  @override
  Stream<Usuario?> get sesion => _auth.userChanges().map(_aUsuario);

  @override
  Future<Usuario?> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: correo,
        password: contrasena,
      );
      return _aUsuario(cred.user);
    } on FirebaseException catch (e) {
      throw authFailureDesde(e.code);
    }
  }

  @override
  Future<Usuario?> registrar({
    required String nombre,
    required String correo,
    required String contrasena,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: correo,
        password: contrasena,
      );
      final user = cred.user!;
      await user.updateDisplayName(nombre);
      return usuarioDesdeDatos(uid: user.uid, correo: correo, nombre: nombre);
    } on FirebaseException catch (e) {
      throw authFailureDesde(e.code);
    }
  }

  @override
  Future<void> cerrarSesion() => _auth.signOut();
}
