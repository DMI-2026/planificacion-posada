import '../models/usuario.dart';

/// Acceso a la sesión (patrón Repository).
abstract class AuthRepository {
  /// Emite el usuario con sesión; `null` si no hay sesión.
  Stream<Usuario?> get sesion;

  Future<Usuario?> iniciarSesion({
    required String correo,
    required String contrasena,
  });

  Future<Usuario?> registrar({
    required String nombre,
    required String correo,
    required String contrasena,
  });

  Future<void> cerrarSesion();
}
