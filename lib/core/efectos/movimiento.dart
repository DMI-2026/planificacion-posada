import 'package:flutter/widgets.dart';

/// Indica si la persona pidió reducir el movimiento (accesibilidad del
/// sistema). Todos los efectos animados muestran un cuadro estático cuando
/// devuelve `true`.
bool movimientoReducido(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;
