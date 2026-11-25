import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/direccion.dart';

/// D-pad y botón de cohete en pantalla. El D-pad mantiene la dirección
/// mientras el dedo está apoyado.
class ControlesTactiles extends StatelessWidget {
  const ControlesTactiles({
    super.key,
    required this.onDireccion,
    required this.onCohete,
  });

  final ValueChanged<Direccion?> onDireccion;
  final VoidCallback onCohete;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _DPad(onDireccion: onDireccion),
        _BotonCohete(onCohete: onCohete),
      ],
    );
  }
}

class _DPad extends StatelessWidget {
  const _DPad({required this.onDireccion});

  final ValueChanged<Direccion?> onDireccion;

  static const double _lado = 156;
  static const double _boton = 52;

  @override
  Widget build(BuildContext context) {
    Widget tecla(Direccion d, IconData icono, Alignment alineacion) => Align(
      alignment: alineacion,
      child: Semantics(
        button: true,
        label: 'Mover ${d.name}',
        child: Listener(
          key: Key('dpad-${d.name}'),
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => onDireccion(d),
          onPointerUp: (_) => onDireccion(null),
          onPointerCancel: (_) => onDireccion(null),
          child: Container(
            width: _boton,
            height: _boton,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.indigoClaro.withValues(alpha: 0.85),
              border: Border.all(color: const Color(0x66FFFFFF)),
            ),
            child: Icon(icono, color: AppTheme.texto, size: 30),
          ),
        ),
      ),
    );
    return SizedBox(
      key: const Key('dpad'),
      width: _lado,
      height: _lado,
      child: Stack(
        children: [
          tecla(Direccion.arriba, Icons.keyboard_arrow_up, Alignment.topCenter),
          tecla(
            Direccion.abajo,
            Icons.keyboard_arrow_down,
            Alignment.bottomCenter,
          ),
          tecla(
            Direccion.izquierda,
            Icons.keyboard_arrow_left,
            Alignment.centerLeft,
          ),
          tecla(
            Direccion.derecha,
            Icons.keyboard_arrow_right,
            Alignment.centerRight,
          ),
        ],
      ),
    );
  }
}

class _BotonCohete extends StatelessWidget {
  const _BotonCohete({required this.onCohete});

  final VoidCallback onCohete;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Colocar cohete',
      child: Listener(
        key: const Key('boton-cohete'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => onCohete(),
        child: Container(
          width: 92,
          height: 92,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [Color(0xFFFF6B6B), AppTheme.rojoFestivo],
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x99D62839),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Icon(Icons.rocket_launch, color: Colors.white, size: 42),
        ),
      ),
    );
  }
}
