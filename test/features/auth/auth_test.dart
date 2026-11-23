import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planificacion_posada/core/errors/auth_failure.dart';
import 'package:planificacion_posada/features/auth/models/usuario.dart';
import 'package:planificacion_posada/features/auth/repositories/fake_auth_repository.dart';
import 'package:planificacion_posada/features/auth/repositories/firebase_auth_repository.dart';
import 'package:planificacion_posada/features/auth/viewmodels/auth_view_model.dart';

Future<void> esperar() => Future<void>.delayed(Duration.zero);

void main() {
  group('authFailureDesde', () {
    test('mapea los códigos de Firebase', () {
      expect(
        authFailureDesde('invalid-credential'),
        isA<CredencialesInvalidas>(),
      );
      expect(authFailureDesde('wrong-password'), isA<CredencialesInvalidas>());
      expect(authFailureDesde('user-not-found'), isA<CredencialesInvalidas>());
      expect(authFailureDesde('invalid-email'), isA<CredencialesInvalidas>());
      expect(
        authFailureDesde('email-already-in-use'),
        isA<CorreoYaRegistrado>(),
      );
      expect(authFailureDesde('weak-password'), isA<ContrasenaDebil>());
      expect(authFailureDesde('too-many-requests'), isA<DemasiadosIntentos>());
      expect(authFailureDesde('network-request-failed'), isA<SinConexion>());
      expect(authFailureDesde('otro'), isA<AuthDesconocida>());
    });

    test('usuarioDesdeFirebase nunca expone null en correo/nombre', () {
      final u = usuarioDesdeDatos(uid: 'x', correo: null, nombre: null);
      expect(u, isA<Usuario>());
      expect(u.correo, '');
      expect(u.nombre, '');
      // FirebaseException es la excepción que se traduce.
      expect(FirebaseAuthException(code: 'x'), isA<FirebaseException>());
    });
  });

  group('AuthViewModel validación', () {
    test('validarCorreo', () {
      expect(AuthViewModel.validarCorreo('ana@utez.edu.mx'), isNull);
      expect(AuthViewModel.validarCorreo('  ana@utez.edu.mx '), isNull);
      expect(AuthViewModel.validarCorreo('ana'), 'Escribe un correo válido.');
      expect(AuthViewModel.validarCorreo('a@b'), 'Escribe un correo válido.');
    });

    test('validarContrasena exige 6 caracteres', () {
      expect(
        AuthViewModel.validarContrasena('12345'),
        'La contraseña debe tener al menos 6 caracteres.',
      );
      expect(AuthViewModel.validarContrasena('123456'), isNull);
    });

    test('validarNombre no acepta vacío', () {
      expect(AuthViewModel.validarNombre('  '), 'Escribe tu nombre.');
      expect(AuthViewModel.validarNombre(' Ana '), isNull);
    });
  });

  group('AuthViewModel con FakeAuthRepository', () {
    late FakeAuthRepository repo;
    late AuthViewModel vm;

    setUp(() async {
      repo = FakeAuthRepository();
      vm = AuthViewModel(repo);
      await esperar();
    });
    tearDown(() => vm.dispose());

    test('sin sesión inicial: usuario null e iniciando false', () {
      expect(vm.iniciando, isFalse);
      expect(vm.usuario, isNull);
    });

    test('iniciar sesión correcto', () async {
      final ok = await vm.iniciarSesion(
        correo: FakeAuthRepository.correoDemo,
        contrasena: FakeAuthRepository.contrasenaDemo,
      );
      await esperar();
      expect(ok, isTrue);
      expect(vm.usuario?.correo, FakeAuthRepository.correoDemo);
      expect(vm.error, '');
    });

    test('credenciales incorrectas dejan mensaje y sin sesión', () async {
      final ok = await vm.iniciarSesion(
        correo: FakeAuthRepository.correoDemo,
        contrasena: 'incorrecta',
      );
      expect(ok, isFalse);
      expect(vm.error, 'Correo o contraseña incorrectos.');
      expect(vm.usuario, isNull);
    });

    test('datos inválidos no llegan al repositorio', () async {
      expect(
        await vm.iniciarSesion(correo: 'x', contrasena: '123456'),
        isFalse,
      );
      expect(vm.error, 'Escribe un correo válido.');
      expect(
        await vm.iniciarSesion(correo: 'a@b.mx', contrasena: '123'),
        isFalse,
      );
      expect(vm.error, 'La contraseña debe tener al menos 6 caracteres.');
      expect(repo.intentos, 0);
    });

    test('registrar valida nombre y crea sesión', () async {
      expect(
        await vm.registrar(nombre: ' ', correo: 'a@b.mx', contrasena: '123456'),
        isFalse,
      );
      expect(vm.error, 'Escribe tu nombre.');
      expect(
        await vm.registrar(
          nombre: 'Ana',
          correo: 'ana@b.mx',
          contrasena: '123456',
        ),
        isTrue,
      );
      await esperar();
      expect(vm.usuario?.nombre, 'Ana');
    });

    test('registrar un correo existente', () async {
      final ok = await vm.registrar(
        nombre: 'Otra',
        correo: FakeAuthRepository.correoDemo,
        contrasena: '123456',
      );
      expect(ok, isFalse);
      expect(vm.error, 'El correo ya está registrado.');
    });

    test('cerrar sesión limpia el usuario', () async {
      await vm.iniciarSesion(
        correo: FakeAuthRepository.correoDemo,
        contrasena: FakeAuthRepository.contrasenaDemo,
      );
      await vm.cerrarSesion();
      await esperar();
      expect(vm.usuario, isNull);
    });
  });
}
