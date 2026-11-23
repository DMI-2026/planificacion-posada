import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'movimiento.dart';

/// Título con degradado dorado que se desplaza lentamente y destellos que
/// titilan. Con movimiento reducido el degradado queda fijo y sin destellos
/// animados.
class TituloMagico extends StatefulWidget {
  const TituloMagico(this.texto, {super.key, this.estilo, this.textAlign});

  final String texto;
  final TextStyle? estilo;
  final TextAlign? textAlign;

  @override
  State<TituloMagico> createState() => _TituloMagicoState();
}

class _TituloMagicoState extends State<TituloMagico>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
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
    final base =
        widget.estilo ??
        Theme.of(context).textTheme.headlineMedium ??
        const TextStyle();
    final quieto = movimientoReducido(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedBuilder(
          animation: _controlador,
          builder: (context, _) {
            final d = quieto ? 0.3 : _controlador.value;
            return ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (rect) => LinearGradient(
                colors: const [
                  Color(0xFFFFC857),
                  Color(0xFFFFF3CF),
                  Color(0xFFFFC857),
                  Color(0xFFFF9EE6),
                  Color(0xFFFFC857),
                ],
                stops: const [0, 0.25, 0.5, 0.75, 1],
                tileMode: TileMode.repeated,
                transform: GradientTranslation(rect.width * 2 * d),
              ).createShader(Rect.fromLTWH(0, 0, rect.width * 2, rect.height)),
              child: Text(
                widget.texto,
                textAlign: widget.textAlign,
                style: base.copyWith(color: Colors.white),
              ),
            );
          },
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: CustomPaint(
                painter: _DestellosPainter(
                  reloj: _controlador,
                  estatico: quieto,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Traslada un degradado en horizontal.
class GradientTranslation extends GradientTransform {
  const GradientTranslation(this.dx);

  final double dx;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(-dx, 0, 0);
}

class _DestellosPainter extends CustomPainter {
  _DestellosPainter({required this.reloj, required this.estatico})
    : super(repaint: reloj);

  final AnimationController reloj;
  final bool estatico;
  static const _puntos = [
    (0.08, 0.15, 0.0),
    (0.46, 0.0, 0.33),
    (0.93, 0.2, 0.66),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()..color = const Color(0xFFFFF3CF);
    for (final p in _puntos) {
      final fase = estatico ? 0.5 : (reloj.value + p.$3) % 1.0;
      final escala = math.sin(fase * math.pi).clamp(0.0, 1.0);
      if (escala <= 0.02) continue;
      final c = Offset(p.$1 * size.width, p.$2 * size.height);
      final r = 6.0 * escala;
      final estrella = Path()
        ..moveTo(c.dx, c.dy - r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r);
      canvas.drawPath(estrella, pincel);
    }
  }

  @override
  bool shouldRepaint(_DestellosPainter anterior) =>
      anterior.estatico != estatico;
}
