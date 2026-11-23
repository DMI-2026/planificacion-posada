import 'package:flutter/material.dart';

import '../../../core/efectos/efectos.dart';
import '../viewmodels/auth_view_model.dart';
import 'auth_marco.dart';

/// Pantalla de inicio de sesión.
class LoginView extends StatefulWidget {
  const LoginView({
    super.key,
    required this.viewModel,
    this.onIrARegistro,
    this.conFondo = true,
  });

  final AuthViewModel viewModel;

  /// Si es `false`, quien aloja la vista pinta el cielo.
  final bool conFondo;
  final VoidCallback? onIrARegistro;

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  void _enviar() => widget.viewModel.iniciarSesion(
    correo: _correo.text,
    contrasena: _contrasena.text,
  );

  @override
  Widget build(BuildContext context) {
    return MarcoAuth(
      subtitulo: 'Entra para ver la posada y confirmar tu asistencia.',
      conFondo: widget.conFondo,
      child: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          final vm = widget.viewModel;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _correo,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Correo',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contrasena,
                obscureText: true,
                onSubmitted: (_) => _enviar(),
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              ErrorAuth(mensaje: vm.error),
              const SizedBox(height: 20),
              Center(
                child: BotonBrillante(
                  onPressed: vm.cargando ? null : _enviar,
                  etiqueta: 'Iniciar sesión',
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: widget.onIrARegistro,
                child: const Text('¿No tienes cuenta? Regístrate'),
              ),
            ],
          );
        },
      ),
    );
  }
}
