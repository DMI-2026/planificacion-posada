import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'movimiento.dart';

/// Lanza una ráfaga de confeti sobre toda la pantalla (en el `Overlay` raíz)
/// y se retira sola al terminar. No bloquea toques. No hace nada con
/// movimiento reducido.
void lanzarConfeti(
  BuildContext context, {
  int cantidad = 90,
  Duration duracion = const Duration(milliseconds: 2600),
  Alignment origen = const Alignment(0, 0.7),
}) {
  if (movimientoReducido(context)) return;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late final OverlayEntry entrada;
  entrada = OverlayEntry(
    builder: (_) => Confeti(
      cantidad: cantidad,
      duracion: duracion,
      origen: origen,
      onTerminar: () {
        entrada.remove();
        entrada.dispose();
      },
    ),
  );
  overlay.insert(entrada);
}

/// Ráfaga de confeti dibujada con `CustomPainter` (sin paquetes).
/// Normalmente se usa mediante [lanzarConfeti].
class Confeti extends StatefulWidget {
  const Confeti({
    super.key,
    this.cantidad = 90,
    this.duracion = const Duration(milliseconds: 2600),
    this.origen = const Alignment(0, 0.7),
    this.semilla,
    this.onTerminar,
  });

  /// Partículas (se limita a 200).
  final int cantidad;
  final Duration duracion;

  /// Punto de salida de la ráfaga dentro de la pantalla.
  final Alignment origen;
  final int? semilla;

  /// Se llama una vez al acabar (o de inmediato con movimiento reducido).
  final VoidCallback? onTerminar;

  @override
  State<Confeti> createState() => _ConfetiState();
}

class _ConfetiState extends State<Confeti> with SingleTickerProviderStateMixin {
  static const _colores = [
    Color(0xFFFF4D5E),
    Color(0xFFFFC857),
    Color(0xFF2EE6C8),
    Color(0xFFFF4FD8),
    Color(0xFF7C8CFF),
    Color(0xFFFFFFFF),
  ];

  late final AnimationController _controlador;
  late final List<_Pieza> _piezas;
  bool _iniciado = false;

  @override
  void initState() {
    super.initState();
    final azar = math.Random(widget.semilla);
    _piezas = List.generate(
      math.min(widget.cantidad, 200),
      (_) => _Pieza.azar(azar, _colores),
    );
    _controlador = AnimationController(vsync: this, duration: widget.duracion)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onTerminar?.call();
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iniciado) return;
    _iniciado = true;
    if (movimientoReducido(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onTerminar?.call();
      });
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
    if (movimientoReducido(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _ConfetiPainter(
              progreso: _controlador,
              segundos: widget.duracion.inMilliseconds / 1000,
              origen: widget.origen,
              piezas: _piezas,
            ),
          ),
        ),
      ),
    );
  }
}

class _Pieza {
  _Pieza(
    this.angulo,
    this.velocidad,
    this.giro,
    this.fase,
    this.ancho,
    this.alto,
    this.redonda,
    this.color,
  );

  factory _Pieza.azar(math.Random r, List<Color> colores) => _Pieza(
    -math.pi * (0.08 + 0.84 * r.nextDouble()),
    380 + r.nextDouble() * 620,
    (r.nextDouble() - 0.5) * 16,
    r.nextDouble() * math.pi * 2,
    5 + r.nextDouble() * 6,
    8 + r.nextDouble() * 8,
    r.nextDouble() < 0.25,
    colores[r.nextInt(colores.length)],
  );

  final double angulo, velocidad, giro, fase, ancho, alto;
  final bool redonda;
  final Color color;
}

class _ConfetiPainter extends CustomPainter {
  _ConfetiPainter({
    required this.progreso,
    required this.segundos,
    required this.origen,
    required this.piezas,
  }) : super(repaint: progreso);

  final Animation<double> progreso;
  final double segundos;
  final Alignment origen;
  final List<_Pieza> piezas;
  final Paint _pincel = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final p = progreso.value;
    final t = p * segundos;
    final o = origen.alongSize(size);
    final opacidad = p < 0.7 ? 1.0 : 1 - (p - 0.7) / 0.3;
    for (final c in piezas) {
      const arrastre = 2.2;
      final avance = (1 - math.exp(-arrastre * t)) / arrastre;
      final x = o.dx + math.cos(c.angulo) * c.velocidad * avance;
      final y =
          o.dy + math.sin(c.angulo) * c.velocidad * avance + 0.5 * 900 * t * t;
      final giroX = math.cos(t * 7 + c.fase).abs();
      _pincel.color = c.color.withValues(alpha: opacidad.clamp(0, 1));
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(c.giro * t + c.fase);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: c.ancho,
        height: c.alto * (0.25 + 0.75 * giroX),
      );
      if (c.redonda) {
        canvas.drawOval(rect, _pincel);
      } else {
        canvas.drawRect(rect, _pincel);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfetiPainter anterior) =>
      anterior.piezas != piezas ||
      anterior.origen != origen ||
      anterior.segundos != segundos;
}
