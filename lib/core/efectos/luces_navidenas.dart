import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'movimiento.dart';

/// Guirnalda de focos de colores con pulso de brillo, pensada para colgar
/// bajo una barra superior o encabezado.
///
/// Solo repinta (sin reconstruir widgets). Con movimiento reducido muestra los
/// focos encendidos y fijos.
class LucesNavidenas extends StatefulWidget {
  const LucesNavidenas({
    super.key,
    this.altura = 28,
    this.colores = const [
      Color(0xFFFF4D5E),
      Color(0xFFFFC857),
      Color(0xFF2EE6C8),
      Color(0xFFFF4FD8),
      Color(0xFF7C8CFF),
    ],
    this.separacion = 34,
  });

  /// Alto total del trazo (cable + focos + resplandor).
  final double altura;

  /// Colores que se repiten a lo largo del cable.
  final List<Color> colores;

  /// Distancia aproximada entre focos, en píxeles.
  final double separacion;

  @override
  State<LucesNavidenas> createState() => _LucesNavidenasState();
}

class _LucesNavidenasState extends State<LucesNavidenas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (movimientoReducido(context)) {
      _controlador.stop();
    } else if (!_controlador.isAnimating) {
      _controlador.repeat();
    }
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quieto = movimientoReducido(context);
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox(
          height: widget.altura,
          width: double.infinity,
          child: CustomPaint(
            painter: _LucesPainter(
              reloj: _controlador,
              colores: widget.colores,
              separacion: widget.separacion,
              estatico: quieto,
            ),
          ),
        ),
      ),
    );
  }
}

class _LucesPainter extends CustomPainter {
  _LucesPainter({
    required this.reloj,
    required this.colores,
    required this.separacion,
    required this.estatico,
  }) : super(repaint: reloj);

  final AnimationController reloj;
  final List<Color> colores;
  final double separacion;
  final bool estatico;
  final Paint _pincel = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final t = estatico ? 0.25 : reloj.value;
    final cable = Paint()
      ..color = const Color(0xFF1B2250)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final tramos = math.max(1, (size.width / (separacion * 4)).round());
    final ancho = size.width / tramos;
    final caida = size.height * 0.34;
    final trazo = Path()..moveTo(0, 2);
    for (var i = 0; i < tramos; i++) {
      trazo.quadraticBezierTo(
        i * ancho + ancho / 2,
        2 + caida * 2,
        (i + 1) * ancho,
        2,
      );
    }
    canvas.drawPath(trazo, cable);

    final n = (size.width / separacion).floor();
    for (var i = 0; i < n; i++) {
      final x = (i + 0.5) * size.width / n;
      final u = (x % ancho) / ancho;
      final y = 2 + 4 * caida * u * (1 - u);
      final color = colores[i % colores.length];
      final pulso =
          0.5 + 0.5 * math.sin(t * math.pi * 2 + i * 1.7 + (i.isEven ? 0 : 1));
      final c = Offset(x, y + 6);
      _pincel.color = color.withValues(alpha: 0.10 + 0.22 * pulso);
      canvas.drawCircle(c, 13, _pincel);
      _pincel.color = color.withValues(alpha: 0.18 + 0.2 * pulso);
      canvas.drawCircle(c, 8, _pincel);
      _pincel.color = Color.lerp(
        color,
        Colors.white,
        0.25 * pulso,
      )!.withValues(alpha: 0.75 + 0.25 * pulso);
      canvas.drawOval(
        Rect.fromCenter(center: c, width: 6.5, height: 9),
        _pincel,
      );
    }
  }

  @override
  bool shouldRepaint(_LucesPainter anterior) =>
      anterior.estatico != estatico ||
      anterior.colores != colores ||
      anterior.separacion != separacion;
}
