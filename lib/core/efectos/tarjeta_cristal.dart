import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'movimiento.dart';

/// Contenedor «cristal» (glassmorphism): desenfoque del fondo, relleno en
/// degradado translúcido, borde con degradado y brillo interior suave.
///
/// En web/escritorio, con puntero, se inclina en 3D hacia el cursor y rebota
/// al presionarse. Con movimiento reducido no hay inclinación ni rebote.
/// Úsala en superficies, no en pantalla completa por elemento (el desenfoque
/// es costoso).
class TarjetaCristal extends StatefulWidget {
  const TarjetaCristal({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radio = 24,
    this.desenfoque = 18,
    this.inclinacion = true,
    this.onTap,
    this.acento,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radio;

  /// Sigma del desenfoque del fondo.
  final double desenfoque;

  /// Activa la inclinación 3D con el puntero.
  final bool inclinacion;

  /// Si se indica, la tarjeta es pulsable (con efecto de ondas).
  final VoidCallback? onTap;

  /// Color del brillo del borde (por defecto dorado).
  final Color? acento;

  /// Base opaca equivalente del cristal; los textos claros mantienen
  /// contraste AA sobre ella.
  static const Color base = Color(0xFF141C4A);

  @override
  State<TarjetaCristal> createState() => _TarjetaCristalState();
}

class _TarjetaCristalState extends State<TarjetaCristal> {
  Offset _cursor = Offset.zero; // -1..1 respecto al centro
  bool _presionada = false;

  void _mover(PointerEvent e, Size tam) {
    if (tam.isEmpty) return;
    setState(() {
      _cursor = Offset(
        (e.localPosition.dx / tam.width * 2 - 1).clamp(-1.0, 1.0),
        (e.localPosition.dy / tam.height * 2 - 1).clamp(-1.0, 1.0),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final reducido = movimientoReducido(context);
    final animar = !reducido;
    final acento = widget.acento ?? const Color(0xFFFFC857);
    final forma = BorderRadius.circular(widget.radio);

    Widget cristal = ClipRRect(
      borderRadius: forma,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: widget.desenfoque,
          sigmaY: widget.desenfoque,
        ),
        child: CustomPaint(
          foregroundPainter: _BordeCristalPainter(
            radio: widget.radio,
            acento: acento,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: forma,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  TarjetaCristal.base.withValues(alpha: 0.78),
                  const Color(0xFF0B1030).withValues(alpha: 0.82),
                ],
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: forma,
                gradient: RadialGradient(
                  center: Alignment(-0.7 + _cursor.dx * 0.4, -0.9),
                  radius: 1.1,
                  colors: [
                    Colors.white.withValues(alpha: 0.10),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
              child: widget.onTap == null
                  ? Padding(padding: widget.padding, child: widget.child)
                  : Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        borderRadius: forma,
                        onTap: widget.onTap,
                        onHighlightChanged: (v) =>
                            setState(() => _presionada = v),
                        child: Padding(
                          padding: widget.padding,
                          child: widget.child,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );

    if (!animar) return cristal;

    cristal = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: forma,
        boxShadow: [
          BoxShadow(
            color: acento.withValues(alpha: 0.10),
            blurRadius: 28,
            spreadRadius: -4,
          ),
          const BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: cristal,
    );

    return Builder(
      builder: (context) {
        final inclina = widget.inclinacion && !_presionada;
        return MouseRegion(
          onHover: widget.inclinacion
              ? (e) => context.size == null ? null : _mover(e, context.size!)
              : null,
          onExit: (_) => setState(() => _cursor = Offset.zero),
          child: TweenAnimationBuilder<Offset>(
            tween: Tween(end: inclina ? _cursor : Offset.zero),
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            child: cristal,
            builder: (context, v, hijo) {
              final m = Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateX(-v.dy * 0.09)
                ..rotateY(v.dx * 0.09);
              return AnimatedScale(
                scale: _presionada ? 0.975 : 1,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                child: Transform(
                  alignment: Alignment.center,
                  transform: m,
                  child: hijo,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _BordeCristalPainter extends CustomPainter {
  const _BordeCristalPainter({required this.radio, required this.acento});

  final double radio;
  final Color acento;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.5);
    final borde = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          acento.withValues(alpha: 0.70),
          Colors.white.withValues(alpha: 0.10),
          const Color(0xFFFF4FD8).withValues(alpha: 0.35),
        ],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radio)),
      borde,
    );
  }

  @override
  bool shouldRepaint(_BordeCristalPainter anterior) =>
      anterior.radio != radio || anterior.acento != acento;
}
