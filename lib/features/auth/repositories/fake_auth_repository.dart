import 'dart:async';

import '../../../core/errors/auth_failure.dart';
import '../models/usuario.dart';
import 'auth_repository.dart';

/// Sesión en memoria para pruebas y para trabajar sin nube.
class FakeAuthRepository implements AuthRepository {
  static const correoDemo = 'demo@posada.mx';
  static const contrasenaDemo = 'posada2026';

  FakeAuthRepository({Usuario? sesionInicial}) : _actual = sesionInicial {
    _cuentas[correoDemo] = (
      contrasena: contrasenaDemo,
      usuario: const Usuario(id: 'u-demo', correo: correoDemo, nombre: 'Demo'),
    );
  }

  final _cambios = StreamController<Usuario?>.broadcast();
  final _cuentas = <String, ({String contrasena, Usuario usuario})>{};
  Usuario? _actual;

  /// Veces que se llamó a [iniciarSesion] o [registrar] (para probar que la
  /// validación del viewmodel evita llegar aquí).
  int intentos = 0;

  @override
  Stream<Usuario?> get sesion async* {
    yield _actual;
    yield* _cambios.stream;
  }

  /// Fuerza una emisión de sesión (para simular el orden de eventos de Firebase).
  void emitirParaPruebas(Usuario? usuario) => _emitir(usuario);

  void _emitir(Usuario? usuario) {
    _actual = usuario;
    _cambios.add(usuario);
  }

  @override
  Future<Usuario?> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    intentos++;
    final cuenta = _cuentas[correo.trim()];
    if (cuenta == null || cuenta.contrasena != contrasena) {
      throw const CredencialesInvalidas();
    }
    _emitir(cuenta.usuario);
    return cuenta.usuario;
  }

  @override
  Future<Usuario?> registrar({
    required String nombre,
    required String correo,
    required String contrasena,
  }) async {
    intentos++;
    final limpio = correo.trim();
    if (_cuentas.containsKey(limpio)) throw const CorreoYaRegistrado();
    final usuario = Usuario(
      id: 'u-${_cuentas.length + 1}',
      correo: limpio,
      nombre: nombre,
    );
    _cuentas[limpio] = (contrasena: contrasena, usuario: usuario);
    _emitir(usuario);
    return usuario;
  }

  @override
  Future<void> cerrarSesion() async => _emitir(null);
}
