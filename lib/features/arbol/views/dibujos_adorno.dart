import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/adorno.dart';

/// Convierte `#RRGGBB` en [Color] (gris si el texto no es válido).
Color colorDeHex(String hex) {
  final limpio = hex.startsWith('#') ? hex.substring(1) : hex;
  final v = int.tryParse(limpio, radix: 16);
  if (limpio.length != 6 || v == null) return const Color(0xFF9AA0C8);
  return Color(0xFF000000 | v);
}

/// Nombre en español de cada color de la paleta (para lectores de pantalla).
const Map<String, String> nombresColores = {
  '#D62839': 'rojo',
  '#FFC857': 'oro',
  '#2EE6C8': 'turquesa',
  '#FF4FD8': 'magenta',
  '#4F7CFF': 'azul',
  '#2FBF71': 'verde',
  '#F4F0FF': 'perla',
  '#8E5BFF': 'violeta',
  '#FF8A3D': 'naranja',
  '#C9CEE8': 'plata',
};

String nombrePatron(PatronEsfera p) => switch (p) {
  PatronEsfera.liso => 'Liso',
  PatronEsfera.rayas => 'Rayas',
  PatronEsfera.puntos => 'Puntos',
  PatronEsfera.estrellas => 'Estrellas',
};

Color _aclarar(Color c, double cuanto) {
  final h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness + cuanto).clamp(0.0, 1.0)).toColor();
}

Color _oscurecer(Color c, double cuanto) => _aclarar(c, -cuanto);

/// Trazo que contrasta con [base] (para el dibujo sobre la esfera).
Color _contraste(Color base) => base.computeLuminance() > 0.45
    ? _oscurecer(base, 0.28)
    : Colors.white.withValues(alpha: 0.7);

/// Camino de una estrella de 5 puntas centrada en [c].
Path caminoEstrella(Offset c, double radio, {double giro = -math.pi / 2}) {
  final p = Path();
  for (var i = 0; i < 10; i++) {
    final r = i.isEven ? radio : radio * 0.45;
    final a = giro + i * math.pi / 5;
    final o = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
    i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
  }
  return p..close();
}

/// Esfera: gradiente radial, dibujo del [patron], casquete dorado y brillo.
class DibujoEsfera extends StatelessWidget {
  const DibujoEsfera({
    super.key,
    required this.color,
    required this.patron,
    this.tamano = 40,
  });

  final String color;
  final PatronEsfera patron;
  final double tamano;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(tamano),
    painter: _EsferaPainter(colorDeHex(color), patron),
  );
}

class _EsferaPainter extends CustomPainter {
  _EsferaPainter(this.color, this.patron);

  final Color color;
  final PatronEsfera patron;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s / 2, s * 0.58);
    final r = s * 0.40;
    final bola = Rect.fromCircle(center: c, radius: r);

    // Sombra suave bajo la bola.
    canvas.drawCircle(
      c.translate(0, r * 0.12),
      r * 1.02,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.05),
    );

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          radius: 0.95,
          colors: [_aclarar(color, 0.22), color, _oscurecer(color, 0.28)],
          stops: const [0, 0.55, 1],
        ).createShader(bola),
    );

    canvas.save();
    canvas.clipPath(Path()..addOval(bola));
    _patron(canvas, c, r, s);
    canvas.restore();

    // Casquete y argolla dorados.
    final oro = const Color(0xFFFFD36E);
    final cap = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(c.dx, c.dy - r * 0.98),
        width: r * 0.62,
        height: r * 0.30,
      ),
      Radius.circular(r * 0.07),
    );
    canvas.drawRRect(
      cap,
      Paint()
        ..shader = LinearGradient(colors: [oro, const Color(0xFFB98524)])
            .createShader(cap.outerRect),
    );
    canvas.drawCircle(
      Offset(c.dx, cap.top - r * 0.10),
      r * 0.16,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, s * 0.03)
        ..color = oro,
    );

    // Brillo especular.
    canvas.save();
    canvas.translate(c.dx - r * 0.38, c.dy - r * 0.42);
    canvas.rotate(-0.7);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 0.55, height: r * 0.28),
      Paint()..color = Colors.white.withValues(alpha: 0.75),
    );
    canvas.restore();
    canvas.drawCircle(
      Offset(c.dx + r * 0.38, c.dy + r * 0.42),
      r * 0.07,
      Paint()..color = Colors.white.withValues(alpha: 0.3),
    );
  }

  void _patron(Canvas canvas, Offset c, double r, double s) {
    final trazo = _contraste(color);
    final p = Paint()..color = trazo;
    switch (patron) {
      case PatronEsfera.liso:
        break;
      case PatronEsfera.rayas:
        p
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.17;
        for (var i = -4; i <= 4; i++) {
          final o = i * r * 0.42;
          canvas.drawLine(
            Offset(c.dx + o - r, c.dy + r),
            Offset(c.dx + o + r, c.dy - r),
            p,
          );
        }
      case PatronEsfera.puntos:
        for (var fila = -2; fila <= 2; fila++) {
          for (var col = -2; col <= 2; col++) {
            final dx = (col + (fila.isOdd ? 0.5 : 0)) * r * 0.5;
            final dy = fila * r * 0.46;
            canvas.drawCircle(Offset(c.dx + dx, c.dy + dy), r * 0.085, p);
          }
        }
      case PatronEsfera.estrellas:
        const sitios = [
          Offset(-0.35, -0.2),
          Offset(0.4, -0.35),
          Offset(0.05, 0.15),
          Offset(-0.45, 0.45),
          Offset(0.45, 0.35),
        ];
        for (final o in sitios) {
          canvas.drawPath(
            caminoEstrella(Offset(c.dx + o.dx * r, c.dy + o.dy * r), r * 0.2),
            p,
          );
        }
    }
  }

  @override
  bool shouldRepaint(_EsferaPainter old) =>
      old.color != color || old.patron != patron;
}

/// Regalo: caja con tapa, listón en cruz y moño.
class DibujoRegalo extends StatelessWidget {
  const DibujoRegalo({
    super.key,
    required this.color,
    required this.colorMono,
    this.tamano = 40,
  });

  final String color;
  final String colorMono;
  final double tamano;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(tamano),
    painter: _RegaloPainter(colorDeHex(color), colorDeHex(colorMono)),
  );
}

class _RegaloPainter extends CustomPainter {
  _RegaloPainter(this.caja, this.cinta);

  final Color caja;
  final Color cinta;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final radio = Radius.circular(s * 0.05);
    final cuerpo = RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.14, s * 0.42, s * 0.72, s * 0.50),
      radio,
    );
    final tapa = RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.08, s * 0.30, s * 0.84, s * 0.17),
      radio,
    );

    canvas.drawRRect(
      cuerpo.shift(Offset(0, s * 0.03)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.04),
    );
    canvas.drawRRect(
      cuerpo,
      Paint()
        ..shader = LinearGradient(
          colors: [_aclarar(caja, 0.12), caja, _oscurecer(caja, 0.22)],
        ).createShader(cuerpo.outerRect),
    );
    canvas.drawRRect(
      tapa,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_aclarar(caja, 0.2), _oscurecer(caja, 0.08)],
        ).createShader(tapa.outerRect),
    );

    // Listón en cruz.
    final lista = Paint()
      ..shader = LinearGradient(
        colors: [_oscurecer(cinta, 0.1), _aclarar(cinta, 0.12), cinta],
      ).createShader(Rect.fromLTWH(0, 0, s, s));
    canvas.drawRect(
      Rect.fromLTWH(s * 0.43, s * 0.30, s * 0.14, s * 0.62),
      lista,
    );
    canvas.drawRect(
      Rect.fromLTWH(s * 0.14, s * 0.60, s * 0.72, s * 0.11),
      lista,
    );

    // Moño: dos lazos y nudo.
    final lazo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.07
      ..strokeCap = StrokeCap.round
      ..color = _aclarar(cinta, 0.05);
    for (final lado in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(s * 0.5, s * 0.27);
      canvas.rotate(lado * 0.55);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(lado * s * 0.11, -s * 0.03),
          width: s * 0.22,
          height: s * 0.13,
        ),
        lazo,
      );
      canvas.restore();
    }
    canvas.drawCircle(
      Offset(s * 0.5, s * 0.285),
      s * 0.055,
      Paint()..color = _oscurecer(cinta, 0.08),
    );

    // Destello en la tapa.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.12, s * 0.33, s * 0.2, s * 0.03),
        Radius.circular(s * 0.015),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(_RegaloPainter old) =>
      old.caja != caja || old.cinta != cinta;
}

/// Dibuja el adorno según su tipo.
class DibujoAdorno extends StatelessWidget {
  const DibujoAdorno({super.key, required this.adorno, this.tamano = 40});

  final Adorno adorno;
  final double tamano;

  @override
  Widget build(BuildContext context) => adorno.tipo == TipoAdorno.esfera
      ? DibujoEsfera(
          color: adorno.color,
          patron: adorno.patron!,
          tamano: tamano,
        )
      : DibujoRegalo(
          color: adorno.color,
          colorMono: adorno.colorMono!,
          tamano: tamano,
        );
}
