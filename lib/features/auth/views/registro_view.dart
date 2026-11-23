import 'package:flutter/material.dart';

import '../../../core/efectos/efectos.dart';
import '../viewmodels/auth_view_model.dart';
import 'auth_marco.dart';

/// Pantalla de registro de cuenta nueva.
class RegistroView extends StatefulWidget {
  const RegistroView({
    super.key,
    required this.viewModel,
    this.onIrALogin,
    this.conFondo = true,
  });

  final AuthViewModel viewModel;

  /// Si es `false`, quien aloja la vista pinta el cielo.
  final bool conFondo;
  final VoidCallback? onIrALogin;

  @override
  State<RegistroView> createState() => _RegistroViewState();
}

class _RegistroViewState extends State<RegistroView> {
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  void _enviar() => widget.viewModel.registrar(
    nombre: _nombre.text,
    correo: _correo.text,
    contrasena: _contrasena.text,
  );

  @override
  Widget build(BuildContext context) {
    return MarcoAuth(
      subtitulo: 'Crea tu cuenta para unirte a la posada.',
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
                controller: _nombre,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _correo,
                keyboardType: TextInputType.emailAddress,
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
                  etiqueta: 'Registrarme',
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: widget.onIrALogin,
                child: const Text('¿Ya tienes cuenta? Inicia sesión'),
              ),
            ],
          );
        },
      ),
    );
  }
}
