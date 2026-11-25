import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../juego/estado_arena.dart';
import '../juego/mapa_arena.dart';
import '../juego/reglas_cohetazo.dart';
import '../models/cohete.dart';
import '../models/jugador.dart';
import '../models/tipo_mejora.dart';
import '../services/avatar_iniciales.dart';
import '../viewmodels/cohetazo_view_model.dart';

/// Dibuja la arena con `Canvas` (sin motor de juego): suelo nevado, muros de
/// hielo y ladrillo, cajas de regalo, mejoras, cohetes con chispa, fuego,
/// jugadores con su foto y nieve cayendo. Se repinta con `vm.repintar`.
class PintorArena extends CustomPainter {
  PintorArena({required this.vm, required this.imagen})
    : super(repaint: vm.repintar);

  final CohetazoViewModel vm;

  /// Avatar ya decodificado del jugador, o null (se dibujan sus iniciales).
  final ui.Image? Function(String uid) imagen;

  static const int _columnas = ReglasCohetazo.columnas;
  static const int _filas = ReglasCohetazo.filas;

  static ui.Picture? _estatica;
  static double _estaticaCelda = 0;

  static final Map<String, TextPainter> _textos = {};

  @override
  void paint(Canvas canvas, Size size) {
    final celda = math.min(size.width / _columnas, size.height / _filas);
    if (celda <= 0) return;
    canvas.save();
    canvas.translate(
      (size.width - celda * _columnas) / 2,
      (size.height - celda * _filas) / 2,
    );
    final ahora = vm.ahora;
    final estado = vm.estado;

    canvas.drawPicture(_capaEstatica(celda));
    _cajas(canvas, celda, estado, ahora);
    _mejoras(canvas, celda, estado, ahora);
    _cohetes(canvas, celda, estado, ahora);
    _fuego(canvas, celda, estado, ahora);
    _jugadores(canvas, celda, ahora);
    _nieve(canvas, celda, ahora);
    canvas.restore();
  }

  @override
  bool shouldRepaint(PintorArena old) => old.vm != vm;

  // ------------------------------------------------------------ Capa fija

  /// Suelo y muros no cambian: se dibujan una vez por tamaño de celda.
  static ui.Picture _capaEstatica(double celda) {
    final previa = _estatica;
    if (previa != null && _estaticaCelda == celda) return previa;
    final grabadora = ui.PictureRecorder();
    final c = Canvas(grabadora);
    final ancho = celda * _columnas;
    final alto = celda * _filas;

    // Suelo nevado con cuadros suaves y destellos.
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, ancho, alto),
        Radius.circular(celda * 0.35),
      ),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF2F8FF), Color(0xFFD5E6F7)],
        ).createShader(Rect.fromLTWH(0, 0, ancho, alto)),
    );
    final claro = Paint()..color = const Color(0x22FFFFFF);
    final sombra = Paint()..color = const Color(0x1A5B86B8);
    for (var y = 0; y < _filas; y++) {
      for (var x = 0; x < _columnas; x++) {
        if (MapaArena.esMuro(x, y)) continue;
        final r = Rect.fromLTWH(x * celda, y * celda, celda, celda);
        c.drawRect(r, (x + y).isEven ? claro : sombra);
        final h = MapaArena.hash([x, y, 77]);
        if (h % 5 == 0) {
          c.drawCircle(
            Offset(
              r.left + celda * (0.2 + (h % 60) / 100),
              r.top + celda * (0.2 + ((h >> 8) % 60) / 100),
            ),
            celda * 0.04,
            Paint()..color = const Color(0x99FFFFFF),
          );
        }
      }
    }

    for (var y = 0; y < _filas; y++) {
      for (var x = 0; x < _columnas; x++) {
        if (!MapaArena.esMuro(x, y)) continue;
        final borde = x == 0 || y == 0 || x == _columnas - 1 || y == _filas - 1;
        _muro(c, Rect.fromLTWH(x * celda, y * celda, celda, celda), borde);
      }
    }
    final pic = grabadora.endRecording();
    _estatica?.dispose();
    _estatica = pic;
    _estaticaCelda = celda;
    return pic;
  }

  static void _muro(Canvas c, Rect r, bool borde) {
    final radio = Radius.circular(r.width * 0.16);
    final cuerpo = RRect.fromRectAndRadius(r.deflate(r.width * 0.03), radio);
    if (borde) {
      // Bloque de hielo.
      c.drawRRect(
        cuerpo,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF9FD3F5), Color(0xFF3F7FC0)],
          ).createShader(r),
      );
      c.drawLine(
        r.topLeft + Offset(r.width * 0.18, r.height * 0.22),
        r.topLeft + Offset(r.width * 0.5, r.height * 0.1),
        Paint()
          ..color = const Color(0xAAFFFFFF)
          ..strokeWidth = r.width * 0.07
          ..strokeCap = StrokeCap.round,
      );
      return;
    }
    // Pilar de ladrillo con nieve encima.
    c.drawRRect(
      cuerpo,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFC9504B), Color(0xFF8F2A33)],
        ).createShader(r),
    );
    final mortero = Paint()
      ..color = const Color(0x55FFE9D6)
      ..strokeWidth = r.width * 0.035;
    for (var i = 1; i < 4; i++) {
      final y = r.top + r.height * i / 4;
      c.drawLine(Offset(r.left + 2, y), Offset(r.right - 2, y), mortero);
      final desplaza = i.isEven ? 0.33 : 0.66;
      c.drawLine(
        Offset(r.left + r.width * desplaza, y - r.height / 4),
        Offset(r.left + r.width * desplaza, y),
        mortero,
      );
    }
    final nieve = Path()
      ..moveTo(r.left + r.width * 0.04, r.top + r.height * 0.3)
      ..quadraticBezierTo(
        r.left + r.width * 0.25,
        r.top - r.height * 0.02,
        r.left + r.width * 0.5,
        r.top + r.height * 0.12,
      )
      ..quadraticBezierTo(
        r.left + r.width * 0.75,
        r.top - r.height * 0.02,
        r.right - r.width * 0.04,
        r.top + r.height * 0.3,
      )
      ..lineTo(r.right - r.width * 0.04, r.top + r.height * 0.18)
      ..quadraticBezierTo(
        r.center.dx,
        r.top - r.height * 0.1,
        r.left + r.width * 0.04,
        r.top + r.height * 0.18,
      )
      ..close();
    c.drawPath(nieve, Paint()..color = const Color(0xFFF7FBFF));
  }

  // ---------------------------------------------------------------- Cajas

  static const List<(Color, Color)> _regalos = [
    (Color(0xFFD62839), Color(0xFFFFC857)),
    (Color(0xFF1F9D6B), Color(0xFFFF4D5E)),
    (Color(0xFF3D6FE0), Color(0xFFE8EEFF)),
    (Color(0xFF8E4FD6), Color(0xFFFFC857)),
  ];

  void _cajas(Canvas c, double celda, EstadoArena estado, int ahora) {
    for (var y = 1; y < _filas - 1; y++) {
      for (var x = 1; x < _columnas - 1; x++) {
        if (!MapaArena.hayCajaInicial(x, y)) continue;
        if (!estado.cajaPresente(x, y, ahora)) continue;
        final (papel, cinta) =
            _regalos[MapaArena.hash([x, y, 5]) % _regalos.length];
        _regalo(
          c,
          Rect.fromLTWH(x * celda, y * celda, celda, celda),
          papel,
          cinta,
        );
      }
    }
  }

  static void _regalo(Canvas c, Rect r, Color papel, Color cinta) {
    final cuerpo = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        r.left + r.width * 0.1,
        r.top + r.height * 0.22,
        r.width * 0.8,
        r.height * 0.7,
      ),
      Radius.circular(r.width * 0.1),
    );
    c.drawRRect(
      cuerpo.shift(Offset(0, r.height * 0.03)),
      Paint()..color = const Color(0x33203060),
    );
    c.drawRRect(
      cuerpo,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(papel, Colors.white, 0.25)!, papel],
        ).createShader(cuerpo.outerRect),
    );
    final cinta1 = Paint()..color = cinta;
    c.drawRect(
      Rect.fromLTWH(
        r.center.dx - r.width * 0.07,
        cuerpo.top,
        r.width * 0.14,
        cuerpo.height,
      ),
      cinta1,
    );
    c.drawRect(
      Rect.fromLTWH(
        cuerpo.left,
        cuerpo.center.dy - r.height * 0.06,
        cuerpo.width,
        r.height * 0.12,
      ),
      cinta1,
    );
    // Moño.
    for (final lado in [-1.0, 1.0]) {
      final centro = Offset(
        r.center.dx + lado * r.width * 0.15,
        cuerpo.top - r.height * 0.02,
      );
      c.drawOval(
        Rect.fromCenter(
          center: centro,
          width: r.width * 0.26,
          height: r.height * 0.2,
        ),
        cinta1,
      );
      c.drawOval(
        Rect.fromCenter(
          center: centro,
          width: r.width * 0.14,
          height: r.height * 0.1,
        ),
        Paint()..color = const Color(0x55FFFFFF),
      );
    }
    c.drawCircle(
      Offset(r.center.dx, cuerpo.top - r.height * 0.02),
      r.width * 0.06,
      cinta1,
    );
  }

  // --------------------------------------------------------------- Mejoras

  static IconData _icono(TipoMejora t) => switch (t) {
    TipoMejora.alcance => Icons.local_fire_department,
    TipoMejora.cohetes => Icons.rocket_launch,
    TipoMejora.velocidad => Icons.bolt,
  };

  static Color _colorMejora(TipoMejora t) => switch (t) {
    TipoMejora.alcance => const Color(0xFFFF7A59),
    TipoMejora.cohetes => const Color(0xFF8AB4FF),
    TipoMejora.velocidad => const Color(0xFFFFC857),
  };

  void _mejoras(Canvas c, double celda, EstadoArena estado, int ahora) {
    for (final m in estado.mejorasSueltas(ahora)) {
      final flota = math.sin(ahora / 260 + m.x * 1.7 + m.y) * celda * 0.05;
      final centro = Offset((m.x + 0.5) * celda, (m.y + 0.5) * celda + flota);
      final color = _colorMejora(m.tipo);
      c.drawCircle(
        centro,
        celda * 0.62,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: centro, radius: celda * 0.62)),
      );
      c.drawCircle(
        centro,
        celda * 0.34,
        Paint()..color = const Color(0xFF141C4A),
      );
      c.drawCircle(
        centro,
        celda * 0.34,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = celda * 0.05
          ..color = color,
      );
      final icono = _icono(m.tipo);
      final tp = _texto(
        String.fromCharCode(icono.codePoint),
        celda * 0.42,
        color,
        familia: icono.fontFamily,
        paquete: icono.fontPackage,
      );
      tp.paint(c, centro - Offset(tp.width / 2, tp.height / 2));
    }
  }

  // --------------------------------------------------------------- Cohetes

  void _cohetes(Canvas c, double celda, EstadoArena estado, int ahora) {
    for (final k in estado.cohetesActivos(ahora)) {
      _cohete(c, celda, k, ahora);
    }
  }

  void _cohete(Canvas c, double celda, Cohete k, int ahora) {
    final p = ((ahora - k.colocado) / ReglasCohetazo.explosionMs).clamp(
      0.0,
      1.0,
    );
    final pulso = 1 + 0.07 * math.sin(ahora * (0.008 + 0.03 * p));
    final centro = Offset((k.x + 0.5) * celda, (k.y + 0.58) * celda);
    c.drawOval(
      Rect.fromCenter(
        center: centro + Offset(0, celda * 0.3),
        width: celda * 0.5,
        height: celda * 0.14,
      ),
      Paint()..color = const Color(0x40203060),
    );
    c.save();
    c.translate(centro.dx, centro.dy);
    c.scale(pulso);
    final u = celda;
    // Aletas.
    final aleta = Paint()..color = const Color(0xFFD62839);
    for (final lado in [-1.0, 1.0]) {
      c.drawPath(
        Path()
          ..moveTo(lado * u * 0.14, u * 0.06)
          ..lineTo(lado * u * 0.3, u * 0.3)
          ..lineTo(lado * u * 0.12, u * 0.24)
          ..close(),
        aleta,
      );
    }
    // Cuerpo.
    final cuerpo = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, u * 0.02),
        width: u * 0.3,
        height: u * 0.5,
      ),
      Radius.circular(u * 0.14),
    );
    c.drawRRect(
      cuerpo,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFC9D8F0)],
        ).createShader(cuerpo.outerRect),
    );
    // Nariz.
    c.drawPath(
      Path()
        ..moveTo(-u * 0.15, -u * 0.16)
        ..quadraticBezierTo(0, -u * 0.5, u * 0.15, -u * 0.16)
        ..close(),
      aleta,
    );
    // Ventana.
    c.drawCircle(
      Offset(0, -u * 0.02),
      u * 0.07,
      Paint()..color = const Color(0xFF3D6FE0),
    );
    c.drawCircle(
      Offset(-u * 0.02, -u * 0.04),
      u * 0.025,
      Paint()..color = const Color(0xAAFFFFFF),
    );
    // Mecha con chispa.
    final mecha = Path()
      ..moveTo(0, -u * 0.34)
      ..quadraticBezierTo(u * 0.1, -u * 0.46, u * 0.04, -u * 0.58);
    c.drawPath(
      mecha,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 0.035
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF5A4636),
    );
    _chispa(c, Offset(u * 0.04, -u * 0.58), u, ahora);
    c.restore();
  }

  static void _chispa(Canvas c, Offset centro, double u, int ahora) {
    final tiembla = 0.8 + 0.35 * math.sin(ahora * 0.045);
    c.drawCircle(
      centro,
      u * 0.2,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xAAFFB000), const Color(0x00FFB000)],
        ).createShader(Rect.fromCircle(center: centro, radius: u * 0.2)),
    );
    final estrella = Path();
    const puntas = 6;
    final giro = ahora * 0.01;
    for (var i = 0; i < puntas * 2; i++) {
      final radio = (i.isEven ? u * 0.11 : u * 0.04) * tiembla;
      final a = giro + math.pi * i / puntas;
      final punto = centro + Offset(math.cos(a), math.sin(a)) * radio;
      i == 0
          ? estrella.moveTo(punto.dx, punto.dy)
          : estrella.lineTo(punto.dx, punto.dy);
    }
    estrella.close();
    c.drawPath(estrella, Paint()..color = const Color(0xFFFFE066));
    c.drawCircle(centro, u * 0.03, Paint()..color = Colors.white);
  }

  // ----------------------------------------------------------------- Fuego

  void _fuego(Canvas c, double celda, EstadoArena estado, int ahora) {
    for (final e in estado.explosiones(ahora)) {
      if (ahora >= e.fin) continue;
      final vida = (ahora - e.inicio) / ReglasCohetazo.fuegoMs;
      final alfa = vida < 0.65 ? 1.0 : ((1 - vida) / 0.35).clamp(0.0, 1.0);
      final celdas = e.celdas.toSet();
      for (final (x, y) in celdas) {
        final r = Rect.fromLTWH(x * celda, y * celda, celda, celda);
        final centro = r.center;
        c.drawCircle(
          centro,
          celda * 0.95,
          Paint()
            ..shader =
                RadialGradient(
                  colors: [
                    const Color(0xAAFF8A00).withValues(alpha: 0.67 * alfa),
                    const Color(0x00FF8A00),
                  ],
                ).createShader(
                  Rect.fromCircle(center: centro, radius: celda * 0.95),
                ),
        );
        final esCentro = x == e.x && y == e.y;
        final conecta = [
          celdas.contains((x - 1, y)),
          celdas.contains((x + 1, y)),
          celdas.contains((x, y - 1)),
          celdas.contains((x, y + 1)),
        ];
        _brazo(c, r, conecta, esCentro, alfa);
      }
    }
  }

  /// Cruz de fuego: núcleo naranja con un corazón blanco-amarillo; los brazos
  /// se prolongan hacia las celdas vecinas en llamas.
  static void _brazo(
    Canvas c,
    Rect r,
    List<bool> conecta,
    bool centro,
    double alfa,
  ) {
    final naranja = Paint()
      ..color = const Color(0xFFFF7A00).withValues(alpha: alfa);
    final amarillo = Paint()
      ..color = const Color(0xFFFFD23F).withValues(alpha: alfa);
    final blanco = Paint()..color = Colors.white.withValues(alpha: alfa);
    final m = r.center;
    final w = r.width;
    final grosor = centro ? 0.62 : 0.5;
    void barra(
      Paint p,
      double g, {
      required bool izq,
      required bool der,
      required bool arr,
      required bool aba,
    }) {
      final h = w * g;
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: m, width: h, height: h),
          Radius.circular(h * 0.45),
        ),
        p,
      );
      final rectas = [
        if (izq) Rect.fromLTRB(r.left, m.dy - h / 2, m.dx, m.dy + h / 2),
        if (der) Rect.fromLTRB(m.dx, m.dy - h / 2, r.right, m.dy + h / 2),
        if (arr) Rect.fromLTRB(m.dx - h / 2, r.top, m.dx + h / 2, m.dy),
        if (aba) Rect.fromLTRB(m.dx - h / 2, m.dy, m.dx + h / 2, r.bottom),
      ];
      for (final rect in rectas) {
        c.drawRect(rect, p);
      }
    }

    barra(
      naranja,
      grosor,
      izq: conecta[0],
      der: conecta[1],
      arr: conecta[2],
      aba: conecta[3],
    );
    barra(
      amarillo,
      grosor * 0.62,
      izq: conecta[0],
      der: conecta[1],
      arr: conecta[2],
      aba: conecta[3],
    );
    barra(
      blanco,
      grosor * 0.28,
      izq: conecta[0],
      der: conecta[1],
      arr: conecta[2],
      aba: conecta[3],
    );
  }

  // ------------------------------------------------------------- Jugadores

  void _jugadores(Canvas c, double celda, int ahora) {
    final lista = <(Jugador, double, double, bool)>[
      for (final j in vm.remotos)
        (j, vm.posicionVisual(j.uid).$1, vm.posicionVisual(j.uid).$2, false),
    ];
    final (lx, ly) = vm.posicionLocal;
    lista.add((vm.yo, lx, ly, true));
    lista.sort((a, b) => a.$3.compareTo(b.$3));
    for (final (j, vx, vy, yo) in lista) {
      _jugador(c, celda, j, vx, vy, yo, ahora);
    }
  }

  void _jugador(
    Canvas c,
    double celda,
    Jugador j,
    double vx,
    double vy,
    bool yo,
    int ahora,
  ) {
    final color = Color(colorDeJugador(j.uid));
    final fantasma = !j.vivo;
    final flota = fantasma ? math.sin(ahora / 280) * celda * 0.06 : 0.0;
    final centro = Offset((vx + 0.5) * celda, (vy + 0.5) * celda + flota);
    final radio = celda * 0.4;
    final parpadeo =
        j.vivo && ahora < j.invulnerableHasta && (ahora ~/ 110).isOdd;
    final opacidad = fantasma ? 0.42 : (parpadeo ? 0.3 : 1.0);

    if (!fantasma) {
      c.drawOval(
        Rect.fromCenter(
          center: centro + Offset(0, radio * 0.95),
          width: radio * 1.7,
          height: radio * 0.5,
        ),
        Paint()..color = const Color(0x44203060),
      );
    }
    final caja = Rect.fromCircle(center: centro, radius: radio * 1.2);
    c.saveLayer(
      caja.inflate(celda * 0.2),
      Paint()
        ..color = Color.fromRGBO(255, 255, 255, opacidad)
        ..colorFilter = fantasma
            ? const ColorFilter.matrix([
                0.33,
                0.33,
                0.33,
                0,
                40,
                0.33,
                0.33,
                0.33,
                0,
                40,
                0.33,
                0.33,
                0.33,
                0,
                50,
                0,
                0,
                0,
                1,
                0,
              ])
            : null,
    );
    // Anillo de color (más ancho y dorado si es el propio).
    c.drawCircle(
      centro,
      radio * 1.12,
      Paint()..color = yo ? Colors.white : color,
    );
    c.drawCircle(centro, radio * 1.02, Paint()..color = color);
    final foto = Rect.fromCircle(center: centro, radius: radio * 0.86);
    final imagenJ = imagen(j.uid);
    if (imagenJ != null) {
      c.save();
      c.clipPath(Path()..addOval(foto));
      paintImage(
        canvas: c,
        rect: foto,
        image: imagenJ,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      );
      c.restore();
    } else {
      c.drawCircle(
        centro,
        radio * 0.86,
        Paint()..color = color.withValues(alpha: 0.85),
      );
      final tp = _texto(
        inicialesDe(j.nombre),
        radio * 0.9,
        const Color(0xFF141C4A),
        negrita: true,
      );
      tp.paint(c, centro - Offset(tp.width / 2, tp.height / 2));
    }
    // Brillo del cristal.
    c.drawArc(
      Rect.fromCircle(center: centro, radius: radio * 0.78),
      math.pi * 1.1,
      math.pi * 0.45,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radio * 0.1
        ..strokeCap = StrokeCap.round
        ..color = const Color(0x66FFFFFF),
    );
    c.restore();

    if (fantasma) {
      final tp = _texto('fuera', celda * 0.26, const Color(0xFFBDBEE6));
      tp.paint(c, centro + Offset(-tp.width / 2, radio * 1.05));
    }
    _etiqueta(c, celda, centro, radio, j.nombre, yo, color);
  }

  void _etiqueta(
    Canvas c,
    double celda,
    Offset centro,
    double radio,
    String nombre,
    bool yo,
    Color color,
  ) {
    final texto = nombre.length > 12 ? '${nombre.substring(0, 11)}…' : nombre;
    final tp = _texto(
      texto,
      math.max(8.0, celda * 0.28),
      yo ? const Color(0xFFFFC857) : Colors.white,
      negrita: true,
    );
    final pos =
        centro - Offset(tp.width / 2, radio * 1.12 + tp.height + celda * 0.02);
    final fondo = RRect.fromRectAndRadius(
      Rect.fromLTWH(pos.dx - 4, pos.dy - 1, tp.width + 8, tp.height + 2),
      Radius.circular(tp.height / 2),
    );
    c.drawRRect(fondo, Paint()..color = const Color(0xB3070B1F));
    tp.paint(c, pos);
  }

  // ------------------------------------------------------------------ Nieve

  void _nieve(Canvas c, double celda, int ahora) {
    final ancho = celda * _columnas;
    final alto = celda * _filas;
    final copo = Paint()..color = const Color(0xB3FFFFFF);
    for (var i = 0; i < 26; i++) {
      final h = MapaArena.hash([i, 9]);
      final periodo = 6000 + (h % 4000);
      final fase = ((ahora + (h >> 4) % periodo) % periodo) / periodo;
      final x =
          ((h % 1000) / 1000 * ancho +
              math.sin(fase * 6.28 + i) * celda * 0.4) %
          ancho;
      c.drawCircle(
        Offset(x, fase * alto),
        celda * (0.03 + (h % 3) * 0.012),
        copo,
      );
    }
  }

  // ------------------------------------------------------------------ Texto

  static TextPainter _texto(
    String texto,
    double tamano,
    Color color, {
    bool negrita = false,
    String? familia,
    String? paquete,
  }) {
    final clave =
        '$texto|${tamano.toStringAsFixed(1)}|${color.toARGB32()}|$negrita|$familia';
    var tp = _textos[clave];
    if (tp == null) {
      if (_textos.length > 400) _textos.clear();
      tp = TextPainter(
        text: TextSpan(
          text: texto,
          style: TextStyle(
            fontSize: tamano,
            color: color,
            fontWeight: negrita ? FontWeight.w800 : FontWeight.w500,
            fontFamily: familia,
            package: paquete,
            height: 1.1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      _textos[clave] = tp;
    }
    return tp;
  }
}
