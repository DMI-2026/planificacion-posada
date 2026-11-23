import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Transición de página «noche»: aparece con desvanecido, escala suave y un
/// leve desenfoque que se disipa. El desenfoque solo existe mientras dura la
/// animación. Con movimiento reducido solo hay desvanecido.
class TransicionNochePageTransitionsBuilder extends PageTransitionsBuilder {
  const TransicionNochePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curva = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return FadeTransition(opacity: curva, child: child);
    }
    return AnimatedBuilder(
      animation: curva,
      child: child,
      builder: (context, hijo) {
        final v = curva.value;
        Widget r = Transform.scale(scale: 0.94 + 0.06 * v, child: hijo);
        if (v < 1) {
          final sigma = (1 - v) * 5;
          if (sigma > 0.1) {
            r = ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: r,
            );
          }
        }
        return Opacity(opacity: v.clamp(0.0, 1.0), child: r);
      },
    );
  }
}
