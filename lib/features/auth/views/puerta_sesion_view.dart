import 'package:flutter/material.dart';

import '../../../core/efectos/efectos.dart';
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
        final usuario = vm.usuario;
        if (!vm.iniciando && usuario != null) {
          return widget.sesionBuilder(context, usuario);
        }
        final Widget pantalla;
        if (vm.iniciando) {
          pantalla = const Scaffold(
            key: ValueKey('cargando'),
            backgroundColor: Colors.transparent,
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (_mostrarRegistro) {
          pantalla = RegistroView(
            key: const ValueKey('registro'),
            viewModel: vm,
            conFondo: false,
            onIrALogin: () => _cambiarA(registro: false),
          );
        } else {
          pantalla = LoginView(
            key: const ValueKey('login'),
            viewModel: vm,
            conFondo: false,
            onIrARegistro: () => _cambiarA(registro: true),
          );
        }
        // El cielo vive fuera del cambio de pantalla para no reiniciarse.
        return FondoNocheMagica(
          child: AnimatedSwitcher(
            duration: movimientoReducido(context)
                ? Duration.zero
                : const Duration(milliseconds: 450),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (hijo, animacion) => FadeTransition(
              opacity: animacion,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(animacion),
                child: hijo,
              ),
            ),
            child: pantalla,
          ),
        );
      },
    );
  }
}
