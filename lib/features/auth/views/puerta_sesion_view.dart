import 'package:flutter/material.dart';

import '../models/usuario.dart';
import '../viewmodels/auth_view_model.dart';
import 'login_view.dart';
import 'registro_view.dart';

/// Muestra carga, login/registro o la app según el estado de la sesión.
class PuertaSesionView extends StatefulWidget {
  const PuertaSesionView({
    super.key,
    required this.viewModel,
    required this.sesionBuilder,
  });

  final AuthViewModel viewModel;

  /// Contenido que se muestra con sesión iniciada.
  final Widget Function(BuildContext context, Usuario usuario) sesionBuilder;

  @override
  State<PuertaSesionView> createState() => _PuertaSesionViewState();
}

class _PuertaSesionViewState extends State<PuertaSesionView> {
  bool _mostrarRegistro = false;

  void _cambiarA({required bool registro}) {
    widget.viewModel.limpiarError();
    setState(() => _mostrarRegistro = registro);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;
        if (vm.iniciando) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final usuario = vm.usuario;
        if (usuario != null) return widget.sesionBuilder(context, usuario);
        if (_mostrarRegistro) {
          return RegistroView(
            viewModel: vm,
            onIrALogin: () => _cambiarA(registro: false),
          );
        }
        return LoginView(
          viewModel: vm,
          onIrARegistro: () => _cambiarA(registro: true),
        );
      },
    );
  }
}
