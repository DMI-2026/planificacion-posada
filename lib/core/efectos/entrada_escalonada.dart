import 'package:flutter/material.dart';

import 'movimiento.dart';

/// Anima a su hijo al aparecer con desvanecido, deslizamiento y escala, con un
/// retraso proporcional a [indice] (para listas escalonadas).
///
/// No usa temporizadores: el retraso es parte de la curva del controlador.
/// Con movimiento reducido el hijo aparece directamente.
class EntradaEscalonada extends StatefulWidget {
  const EntradaEscalonada({
    super.key,
    required this.indice,
    required this.child,
    this.intervalo = const Duration(milliseconds: 70),
    this.duracion = const Duration(milliseconds: 520),
    this.desplazamiento = 24,
    this.maxRetrasos = 12,
  });

  /// Envuelve cada widget con su índice para armar una lista escalonada.
  static List<Widget> lista(List<Widget> hijos) => [
    for (var i = 0; i < hijos.length; i++)
      EntradaEscalonada(indice: i, child: hijos[i]),
  ];

  final int indice;
  final Widget child;

  /// Retraso entre elementos consecutivos.
  final Duration intervalo;

  /// Duración de la animación de cada elemento.
  final Duration duracion;

  /// Distancia vertical inicial del deslizamiento.
  final double desplazamiento;

  /// Tope de elementos que acumulan retraso (los demás entran junto al último).
  final int maxRetrasos;

  @override
  State<EntradaEscalonada> createState() => _EntradaEscalonadaState();
}

class _EntradaEscalonadaState extends State<EntradaEscalonada>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador;
  late final Animation<double> _curva;
  bool _iniciada = false;

  @override
  void initState() {
    super.initState();
    final retraso =
        widget.intervalo * widget.indice.clamp(0, widget.maxRetrasos);
    final total = retraso + widget.duracion;
    _controlador = AnimationController(vsync: this, duration: total);
    _curva = CurvedAnimation(
      parent: _controlador,
      curve: Interval(
        retraso.inMicroseconds / total.inMicroseconds,
        1,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iniciada) return;
    _iniciada = true;
    if (movimientoReducido(context)) {
      _controlador.value = 1;
    } else {
      _controlador.forward();
    }
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curva,
      child: widget.child,
      builder: (context, hijo) {
        final v = _curva.value;
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * widget.desplazamiento),
            child: Transform.scale(scale: 0.94 + 0.06 * v, child: hijo),
          ),
        );
      },
    );
  }
}
