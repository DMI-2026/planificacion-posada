import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'movimiento.dart';

/// Fondo de pantalla completa «noche mágica»: cielo en degradado, estrellas
/// titilantes, auroras lentas y nieve con paralaje.
///
/// Usa UN solo `AnimationController`; la animación es solo de pintura
/// (`CustomPainter(repaint: controller)`), así que el árbol de widgets no se
/// reconstruye por cuadro. Con movimiento reducido (o `estatico: true`) pinta
/// un único cuadro fijo y detiene el controlador.
class FondoNocheMagica extends StatefulWidget {
  const FondoNocheMagica({
    super.key,
    this.child,
    this.estatico = false,
    this.semilla = 2412,
    this.estrellas,
    this.copos,
  });

  /// Contenido que se dibuja encima del fondo.
  final Widget? child;

  /// Fuerza el modo estático (útil en pruebas o para ahorrar batería).
  final bool estatico;

  /// Semilla del generador: mismo valor, mismo cielo.
  final int semilla;

  /// Número de estrellas (por defecto 250 en web y 180 en móvil; máx. 250).
  final int? estrellas;

  /// Número de copos de nieve (por defecto 100 en web y 80 en móvil; máx. 120).
  final int? copos;

  static const Color cieloArriba = Color(0xFF050818);
  static const Color cieloMedio = Color(0xFF0E1440);
  static const Color cieloAbajo = Color(0xFF241552);

  @override
  State<FondoNocheMagica> createState() => _FondoNocheMagicaState();
}

class _FondoNocheMagicaState extends State<FondoNocheMagica>
    with SingleTickerProviderStateMixin {
  static const int _segundosCiclo = 1800;
  late final AnimationController _controlador;
  late final List<_Estrella> _estrellas;
  late final List<_Copo> _copos;

  @override
  void initState() {
    super.initState();
    _controlador = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _segundosCiclo),
    );
    final azar = math.Random(widget.semilla);
    final nEstrellas = math.min(widget.estrellas ?? (kIsWeb ? 250 : 180), 250);
    final nCopos = math.min(widget.copos ?? (kIsWeb ? 100 : 80), 120);
    _estrellas = List.generate(nEstrellas, (_) => _Estrella.azar(azar));
    _copos = List.generate(nCopos, (_) => _Copo.azar(azar));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final quieto = widget.estatico || movimientoReducido(context);
    if (quieto) {
      _controlador.stop();
    } else if (!_controlador.isAnimating) {
      _controlador.repeat();
    }
  }

  @override
  void didUpdateWidget(FondoNocheMagica anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.estatico != widget.estatico) didChangeDependencies();
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quieto = widget.estatico || movimientoReducido(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        const RepaintBoundary(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  FondoNocheMagica.cieloArriba,
                  FondoNocheMagica.cieloMedio,
                  FondoNocheMagica.cieloAbajo,
                ],
                stops: [0, 0.55, 1],
              ),
            ),
          ),
        ),
        RepaintBoundary(
          child: CustomPaint(
            painter: _CieloPainter(
              reloj: _controlador,
              segundosCiclo: _segundosCiclo,
              estatico: quieto,
              estrellas: _estrellas,
              copos: _copos,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _Estrella {
  _Estrella(this.x, this.y, this.radio, this.fase, this.velocidad, this.color);

  factory _Estrella.azar(math.Random r) {
    final tono = r.nextDouble();
    return _Estrella(
      r.nextDouble(),
      math.pow(r.nextDouble(), 1.3).toDouble() * 0.9,
      0.5 + r.nextDouble() * r.nextDouble() * 1.8,
      r.nextDouble() * math.pi * 2,
      0.6 + r.nextDouble() * 2.2,
      tono < 0.7
          ? const Color(0xFFFFFFFF)
          : tono < 0.88
          ? const Color(0xFFFFE2A0)
          : const Color(0xFFB8C8FF),
    );
  }

  final double x, y, radio, fase, velocidad;
  final Color color;
}

class _Copo {
  _Copo(this.x, this.y, this.profundidad, this.fase, this.balanceo);

  factory _Copo.azar(math.Random r) => _Copo(
    r.nextDouble(),
    r.nextDouble(),
    const [0.4, 0.7, 1.0][r.nextInt(3)],
    r.nextDouble() * math.pi * 2,
    0.5 + r.nextDouble(),
  );

  final double x, y, profundidad, fase, balanceo;
}

class _CieloPainter extends CustomPainter {
  _CieloPainter({
    required this.reloj,
    required this.segundosCiclo,
    required this.estatico,
    required this.estrellas,
    required this.copos,
  }) : super(repaint: reloj);

  final AnimationController reloj;
  final int segundosCiclo;
  final bool estatico;
  final List<_Estrella> estrellas;
  final List<_Copo> copos;

  static const double _tEstatico = 14;
  static const _auroras = [
    (Color(0xFF2EE6C8), 0.20, 0.10, 0.9, 0.0),
    (Color(0xFFFF4FD8), 0.30, 0.09, 0.6, 2.1),
    (Color(0xFF6F7CFF), 0.38, 0.08, 0.45, 4.2),
  ];

  final Paint _pincel = Paint();
  Size? _tamanoCache;
  List<Shader>? _sombreadores;

  @override
  void paint(Canvas canvas, Size size) {
    final t = estatico ? _tEstatico : reloj.value * segundosCiclo;
    _pintarAuroras(canvas, size, t);
    _pintarEstrellas(canvas, size, t);
    _pintarNieve(canvas, size, t);
  }

  void _pintarAuroras(Canvas canvas, Size size, double t) {
    if (_tamanoCache != size) {
      _tamanoCache = size;
      _sombreadores = [
        for (final a in _auroras)
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              a.$1.withValues(alpha: 0),
              a.$1.withValues(alpha: 0.30),
              a.$1.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromLTWH(
              0,
              size.height * (a.$2 - 0.14),
              size.width,
              size.height * 0.5,
            ),
          ),
      ];
    }
    const paso = 28.0;
    for (var i = 0; i < _auroras.length; i++) {
      final a = _auroras[i];
      final base = size.height * a.$2;
      final amp = size.height * a.$3;
      final grosor = size.height * 0.26;
      final trazo = Path()..moveTo(0, base + grosor);
      final borde = <Offset>[];
      for (double x = 0; x <= size.width + paso; x += paso) {
        final y =
            base +
            math.sin(x / size.width * 4.2 + t * 0.12 * a.$4 + a.$5) * amp +
            math.sin(x / size.width * 9 - t * 0.2 * a.$4) * amp * 0.3;
        borde.add(Offset(x, y));
      }
      for (final p in borde) {
        trazo.lineTo(p.dx, p.dy);
      }
      trazo
        ..lineTo(size.width + paso, base + grosor)
        ..close();
      _pincel
        ..shader = _sombreadores![i]
        ..color = Colors.white;
      canvas.drawPath(trazo, _pincel);
    }
    _pincel.shader = null;
  }

  void _pintarEstrellas(Canvas canvas, Size size, double t) {
    for (final e in estrellas) {
      final brillo = 0.55 + 0.45 * math.sin(t * e.velocidad + e.fase);
      final c = Offset(e.x * size.width, e.y * size.height);
      if (e.radio > 1.7) {
        _pincel.color = e.color.withValues(alpha: 0.12 * brillo);
        canvas.drawCircle(c, e.radio * 3.2, _pincel);
      }
      _pincel.color = e.color.withValues(alpha: 0.35 + 0.65 * brillo);
      canvas.drawCircle(c, e.radio, _pincel);
    }
  }

  void _pintarNieve(Canvas canvas, Size size, double t) {
    final alto = size.height + 24;
    for (final c in copos) {
      final d = c.profundidad;
      final avance = (c.y + t * (0.012 + 0.03 * d)) % 1.0;
      final y = avance * alto - 12;
      final x =
          c.x * size.width +
          math.sin(t * 0.6 * c.balanceo + c.fase) * 14 * d +
          math.sin(t * 0.05) * 24 * d;
      _pincel.color = Colors.white.withValues(alpha: 0.35 + 0.5 * d);
      canvas.drawCircle(Offset(x, y), 0.9 + 2.2 * d, _pincel);
    }
  }

  @override
  bool shouldRepaint(_CieloPainter anterior) =>
      anterior.estatico != estatico ||
      anterior.estrellas != estrellas ||
      anterior.copos != copos;
}
