import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/auth_failure.dart';
import '../models/usuario.dart';
import '../repositories/auth_repository.dart';

/// Estado de la sesión (patrón Observer).
class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._repository) {
    _suscripcion = _repository.sesion.listen(
      _alCambiarSesion,
      onError: (Object _) => _alCambiarSesion(null),
    );
  }

  final AuthRepository _repository;
  late final StreamSubscription<Usuario?> _suscripcion;

  bool _iniciando = true;
  bool _cargando = false;
  String _error = '';
  Usuario? _usuario;

  // Mientras se registra, las emisiones de sesión se retienen: Firebase emite
  // al crear la cuenta, antes de guardar el nombre, y la app crearía el
  // participante con un nombre incompleto.
  bool _registrando = false;
  bool _hayRetenida = false;
  Usuario? _retenida;

  bool get iniciando => _iniciando;
  bool get cargando => _cargando;

  /// Mensaje del último error; `''` si no hay.
  String get error => _error;
  Usuario? get usuario => _usuario;

  static final _formatoCorreo = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? validarCorreo(String correo) =>
      _formatoCorreo.hasMatch(correo.trim())
      ? null
      : 'Escribe un correo válido.';

  static String? validarContrasena(String contrasena) => contrasena.length >= 6
      ? null
      : 'La contraseña debe tener al menos 6 caracteres.';

  static String? validarNombre(String nombre) =>
      nombre.trim().isNotEmpty ? null : 'Escribe tu nombre.';

  void _alCambiarSesion(Usuario? usuario) {
    if (_registrando) {
      _retenida = usuario;
      _hayRetenida = true;
      return;
    }
    _aplicarSesion(usuario);
  }

  void _aplicarSesion(Usuario? usuario) {
    _usuario = usuario;
    _iniciando = false;
    notifyListeners();
  }

  /// Valida antes de llamar al repositorio: un dato mal escrito no gasta red.
  Future<bool> _ejecutar(
    List<String?> validaciones,
    Future<Object?> Function() accion,
  ) async {
    final invalido = validaciones.firstWhere(
      (m) => m != null,
      orElse: () => null,
    );
    if (invalido != null) {
      _error = invalido;
      notifyListeners();
      return false;
    }
    _cargando = true;
    _error = '';
    notifyListeners();
    try {
      await accion();
      return true;
    } on AuthFailure catch (e) {
      _error = _mensaje(e);
      return false;
    } catch (_) {
      _error = _mensaje(const AuthDesconocida());
      return false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<bool> iniciarSesion({
    required String correo,
    required String contrasena,
  }) => _ejecutar(
    [validarCorreo(correo), validarContrasena(contrasena)],
    () => _repository.iniciarSesion(
      correo: correo.trim(),
      contrasena: contrasena,
    ),
  );

  Future<bool> registrar({
    required String nombre,
    required String correo,
    required String contrasena,
  }) async {
    _registrando = true;
    Usuario? registrado;
    try {
      return await _ejecutar(
        [
          validarNombre(nombre),
          validarCorreo(correo),
          validarContrasena(contrasena),
        ],
        () async => registrado = await _repository.registrar(
          nombre: nombre.trim(),
          correo: correo.trim(),
          contrasena: contrasena,
        ),
      );
    } finally {
      _registrando = false;
      if (registrado != null) {
        _hayRetenida = false;
        _aplicarSesion(registrado);
      } else if (_hayRetenida) {
        _hayRetenida = false;
        _aplicarSesion(_retenida);
      }
    }
  }

  /// Al cambiar entre login y registro, el error de una no se queda en la otra.
  void limpiarError() {
    if (_error.isEmpty) return;
    _error = '';
    notifyListeners();
  }

  Future<void> cerrarSesion() => _repository.cerrarSesion();

  String _mensaje(AuthFailure falla) => switch (falla) {
    CredencialesInvalidas() => 'Correo o contraseña incorrectos.',
    CorreoYaRegistrado() => 'El correo ya está registrado.',
    ContrasenaDebil() => 'La contraseña es muy débil.',
    DemasiadosIntentos() => 'Demasiados intentos. Intenta más tarde.',
    SinConexion() => 'Sin conexión. Revisa tu red e intenta de nuevo.',
    AuthDesconocida() => 'Ocurrió un error inesperado. Intenta de nuevo.',
  };

  @override
  void dispose() {
    _suscripcion.cancel();
    super.dispose();
  }
}
