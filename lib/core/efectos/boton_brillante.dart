import 'package:flutter/material.dart';

import 'movimiento.dart';

/// Botón de acción principal con degradado festivo, brillo que lo recorre,
/// resplandor que pulsa y rebote al presionar.
///
/// Con `onPressed == null` queda deshabilitado y apagado. Con movimiento
/// reducido no hay brillo ni pulso. Es accesible por teclado (InkWell).
class BotonBrillante extends StatefulWidget {
  const BotonBrillante({
    super.key,
    required this.onPressed,
    required this.etiqueta,
    this.icono,
  });

  final VoidCallback? onPressed;
  final String etiqueta;
  final IconData? icono;

  @override
  State<BotonBrillante> createState() => _BotonBrillanteState();
}

class _BotonBrillanteState extends State<BotonBrillante>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  bool _presionado = false;

  bool get _activo => widget.onPressed != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sincronizar();
  }

  @override
  void didUpdateWidget(BotonBrillante anterior) {
    super.didUpdateWidget(anterior);
    _sincronizar();
  }

  void _sincronizar() {
    final animar = _activo && !movimientoReducido(context);
    if (!animar) {
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
    const forma = StadiumBorder();
    final reducido = movimientoReducido(context);
    return AnimatedScale(
      scale: _presionado ? 0.94 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutBack,
      child: AnimatedBuilder(
        animation: _controlador,
        builder: (context, hijo) {
          final pulso = reducido
              ? 0.5
              : 0.5 + 0.5 * (1 - (_controlador.value * 2 - 1).abs());
          return DecoratedBox(
            decoration: ShapeDecoration(
              shape: forma,
              shadows: _activo
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFF4D5E)
                            .withValues(alpha: 0.30 + 0.30 * pulso),
                        blurRadius: 14 + 14 * pulso,
                        spreadRadius: 1 + 2 * pulso,
                      ),
                    ]
                  : const [],
            ),
            child: hijo,
          );
        },
        child: Material(
          color: Colors.transparent,
          shape: forma,
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: ShapeDecoration(
              shape: forma,
              gradient: LinearGradient(
                colors: _activo
                    ? const [Color(0xFFC2182B), Color(0xFFB5179E)]
                    : const [Color(0xFF3A3F66), Color(0xFF3A3F66)],
              ),
            ),
            child: InkWell(
              customBorder: forma,
              onTap: widget.onPressed,
              onHighlightChanged: (v) => setState(() => _presionado = v),
              child: CustomPaint(
                foregroundPainter: _BrilloPainter(
                  reloj: _controlador,
                  activo: _activo && !reducido,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icono != null) ...[
                        Icon(widget.icono, size: 20, color: Colors.white),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        widget.etiqueta,
                        style: TextStyle(
                          color: _activo
                              ? Colors.white
                              : const Color(0xFFC9CBE8),
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrilloPainter extends CustomPainter {
  _BrilloPainter({required this.reloj, required this.activo})
    : super(repaint: reloj);

  final AnimationController reloj;
  final bool activo;

  @override
  void paint(Canvas canvas, Size size) {
    if (!activo) return;
    // La franja cruza el botón durante el 55 % del ciclo y descansa el resto.
    final f = (reloj.value / 0.55).clamp(0.0, 1.0);
    if (f >= 1) return;
    final x = -size.width * 0.4 + f * size.width * 1.8;
    final rect = Rect.fromLTWH(x, 0, size.width * 0.4, size.height);
    final pincel = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.30),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, pincel);
  }

  @override
  bool shouldRepaint(_BrilloPainter anterior) => anterior.activo != activo;
}
