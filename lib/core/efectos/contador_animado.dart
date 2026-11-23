import 'package:flutter/material.dart';

import 'movimiento.dart';

/// Número que cuenta hasta [valor] al aparecer y cada vez que cambia.
/// Con movimiento reducido muestra el valor final sin animación.
class ContadorAnimado extends StatelessWidget {
  const ContadorAnimado({
    super.key,
    required this.valor,
    this.estilo,
    this.duracion = const Duration(milliseconds: 1200),
    this.curva = Curves.easeOutCubic,
    this.formato,
  });

  final int valor;
  final TextStyle? estilo;
  final Duration duracion;
  final Curve curva;

  /// Convierte el número en texto (por defecto, `toString`).
  final String Function(int)? formato;

  @override
  Widget build(BuildContext context) {
    String texto(int v) => formato?.call(v) ?? '$v';
    final estiloFinal = estilo ?? DefaultTextStyle.of(context).style;
    final cifras = [const FontFeature.tabularFigures()];
    final conCifras = estiloFinal.copyWith(fontFeatures: cifras);
    if (movimientoReducido(context)) {
      return Text(texto(valor), style: conCifras);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: valor.toDouble()),
      duration: duracion,
      curve: curva,
      builder: (context, v, _) => Text(texto(v.round()), style: conCifras),
    );
  }
}
