import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../geometria/arbol_geometria.dart';
import 'dibujos_adorno.dart';

/// Dibuja el árbol: pisos con degradado, guirnaldas con focos que titilan,
/// estrella con resplandor, tronco, nieve en la base y copos que caen.
///
/// [reloj] va de 0 a 1 cada pocos segundos y se repite; todo lo animado usa
/// múltiplos enteros de su valor para que el ciclo cierre sin saltos. Solo
/// repinta (sin reconstruir widgets). Con [animado] en `false` dibuja un solo
/// cuadro estático.
class PintorArbol extends CustomPainter {
  PintorArbol({required this.reloj, required this.animado})
    : super(repaint: reloj);

  final Animation<double> reloj;
  final bool animado;

  static const List<Color> _focos = [
    Color(0xFFFF4D5E),
    Color(0xFFFFC857),
    Color(0xFF2EE6C8),
    Color(0xFFFF4FD8),
    Color(0xFF7C8CFF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final v = reloj.value;

    _halo(canvas, size);
    _tronco(canvas, size);
    for (final piso in pisosArbol.reversed) {
      _piso(canvas, size, piso);
    }
    for (final piso in pisosArbol) {
      _guirnalda(canvas, size, piso, 0.42, v);
      _guirnalda(canvas, size, piso, 0.82, v);
    }
    _estrella(canvas, size, v);
    _nieve(canvas, size);
    _copos(canvas, size, v);
  }

  void _halo(Canvas canvas, Size size) {
    final r = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.55),
      width: size.width * 1.1,
      height: size.height * 1.05,
    );
    canvas.drawOval(
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF2EE6C8).withValues(alpha: 0.16),
            const Color(0xFFFF4FD8).withValues(alpha: 0.05),
            Colors.transparent,
          ],
          stops: const [0, 0.55, 1],
        ).createShader(r),
    );
  }

  void _tronco(Canvas canvas, Size size) {
    final r = Rect.fromLTRB(
      size.width * 0.44,
      size.height * 0.86,
      size.width * 0.56,
      size.height * 0.97,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(size.width * 0.012)),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF3E2418), Color(0xFF7A4A2B), Color(0xFF3E2418)],
        ).createShader(r),
    );
  }

  Path _caminoPiso(PisoArbol p, Size s) {
    final w = s.width, h = s.height;
    final xl0 = (0.5 - p.anchoArriba) * w, xr0 = (0.5 + p.anchoArriba) * w;
    final xlB = (0.5 - p.anchoAbajo) * w, xrB = (0.5 + p.anchoAbajo) * w;
    final yT = p.arriba * h, yB = p.abajo * h;
    final path = Path()
      ..moveTo(xl0, yT)
      ..lineTo(xr0, yT)
      ..lineTo(xrB, yB);
    const n = 6;
    for (var i = 0; i < n; i++) {
      final xa = xrB - (xrB - xlB) * i / n;
      final xb = xrB - (xrB - xlB) * (i + 1) / n;
      path.quadraticBezierTo((xa + xb) / 2, yB + h * 0.028, xb, yB);
    }
    return path..close();
  }

  void _piso(Canvas canvas, Size size, PisoArbol p) {
    final path = _caminoPiso(p, size);
    final caja = path.getBounds();
    canvas.drawPath(
      path.shift(Offset(0, size.height * 0.008)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.012),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF20A878), Color(0xFF0C5A4C), Color(0xFF083D3A)],
          stops: [0, 0.7, 1],
        ).createShader(caja),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.13),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.3),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(caja),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF7DF7CC).withValues(alpha: 0.35),
    );
  }

  Offset _bezier(Offset a, Offset c, Offset b, double t) {
    final u = 1 - t;
    return Offset(
      u * u * a.dx + 2 * u * t * c.dx + t * t * b.dx,
      u * u * a.dy + 2 * u * t * c.dy + t * t * b.dy,
    );
  }

  void _guirnalda(Canvas canvas, Size s, PisoArbol p, double frac, double v) {
    final y = p.arriba + (p.abajo - p.arriba) * frac;
    final ancho = p.anchoEn(y) * 0.93;
    final a = Offset((0.5 - ancho) * s.width, y * s.height);
    final b = Offset((0.5 + ancho) * s.width, y * s.height);
    final c = Offset(s.width * 0.5, (y + 0.075) * s.height);
    final cable = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(c.dx, c.dy, b.dx, b.dy);
    canvas.drawPath(
      cable,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = const Color(0xFFFFE9A8).withValues(alpha: 0.55),
    );
    final n = math.max(4, (ancho * 20).round());
    for (var i = 0; i <= n; i++) {
      final t = i / n;
      final o = _bezier(a, c, b, t);
      final color = _focos[(i + (frac * 10).round()) % _focos.length];
      final brillo = animado
          ? 0.55 + 0.45 * math.sin(2 * math.pi * (v * 3 + i * 0.37 + frac))
          : 0.85;
      canvas.drawCircle(
        o.translate(0, 3),
        s.width * 0.026,
        Paint()..color = color.withValues(alpha: 0.28 * brillo),
      );
      canvas.drawCircle(
        o.translate(0, 3),
        s.width * 0.0105,
        Paint()
          ..color = Color.lerp(
            color,
            Colors.white,
            0.35 * brillo,
          )!.withValues(alpha: 0.55 + 0.45 * brillo),
      );
    }
  }

  void _estrella(Canvas canvas, Size s, double v) {
    final c = Offset(s.width * 0.5, s.height * 0.042);
    final radio = s.width * 0.058;
    final pulso = animado ? 0.5 + 0.5 * math.sin(2 * math.pi * v * 2) : 0.7;
    canvas.drawCircle(
      c,
      radio * (1.7 + 0.3 * pulso),
      Paint()
        ..color = const Color(0xFFFFC857).withValues(alpha: 0.28 + 0.2 * pulso)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radio * 0.9),
    );
    final cam = caminoEstrella(c, radio);
    canvas.drawPath(
      cam,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFF6D0), Color(0xFFFFC857), Color(0xFFE79A1B)],
          stops: [0, 0.5, 1],
        ).createShader(Rect.fromCircle(center: c, radius: radio)),
    );
    // Destello en cruz que respira.
    final largo = radio * (1.5 + 0.7 * pulso);
    final destello = Paint()
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.35 + 0.4 * pulso);
    canvas.drawLine(c.translate(-largo, 0), c.translate(largo, 0), destello);
    canvas.drawLine(c.translate(0, -largo), c.translate(0, largo), destello);
  }

  void _nieve(Canvas canvas, Size s) {
    final r = Rect.fromLTWH(0, s.height * 0.93, s.width, s.height * 0.07);
    final path = Path()..moveTo(0, s.height);
    const n = 9;
    path.lineTo(0, s.height * 0.965);
    for (var i = 0; i < n; i++) {
      final x0 = s.width * i / n, x1 = s.width * (i + 1) / n;
      path.quadraticBezierTo(
        (x0 + x1) / 2,
        s.height * (i.isEven ? 0.925 : 0.945),
        x1,
        s.height * 0.965,
      );
    }
    path
      ..lineTo(s.width, s.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFC9D7FF)],
        ).createShader(r),
    );
    for (var i = 0; i < 14; i++) {
      final x = ((i * 0.61803) % 1) * s.width;
      final y = s.height * (0.955 + 0.04 * ((i * 0.37) % 1));
      canvas.drawCircle(
        Offset(x, y),
        1.1,
        Paint()..color = const Color(0xFF8FA6E8).withValues(alpha: 0.5),
      );
    }
  }

  void _copos(Canvas canvas, Size s, double v) {
    final p = Paint();
    for (var i = 0; i < 26; i++) {
      final velocidad = 1 + (i % 3); // vueltas enteras por ciclo
      final t = animado ? v * velocidad : 0.35;
      final y = ((t + i * 0.137) % 1.0) * s.height;
      final x =
          (((i * 0.61803) % 1.0) * 1.1 - 0.05) * s.width +
          (animado
              ? math.sin(2 * math.pi * (v * 2 + i * 0.21)) * s.width * 0.012
              : 0);
      p.color = Colors.white.withValues(alpha: 0.35 + 0.4 * ((i * 0.29) % 1));
      canvas.drawCircle(Offset(x, y), 0.9 + (i % 4) * 0.45, p);
    }
  }

  @override
  bool shouldRepaint(PintorArbol old) =>
      old.animado != animado || old.reloj != reloj;
}
