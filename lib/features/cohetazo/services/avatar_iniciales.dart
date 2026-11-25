import 'dart:convert';

import 'package:image/image.dart' as img;

import '../juego/mapa_arena.dart';
import '../juego/reglas_cohetazo.dart';

/// Colores de los anillos y de los avatares de iniciales (ARGB).
const List<int> coloresJugador = [
  0xFFFF4FD8,
  0xFF2EE6C8,
  0xFFFFC857,
  0xFFFF7A59,
  0xFF7CF29A,
  0xFF8AB4FF,
  0xFFC792FF,
  0xFFFF9EC7,
];

/// Color estable de un jugador a partir de su uid.
int colorDeJugador(String uid) =>
    coloresJugador[MapaArena.hashTexto(uid, const []) % coloresJugador.length];

/// Iniciales (hasta dos letras) de un nombre.
String inicialesDe(String nombre) {
  final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final letras = [
    for (final p in partes.take(2)) String.fromCharCode(p.runes.first),
  ];
  return letras.isEmpty ? '?' : letras.join().toUpperCase();
}

/// Avatar alternativo cuando no hay cámara: iniciales sobre un fondo de color,
/// como JPEG base64 del mismo tamaño que la foto (96 px, ≤ 20000 caracteres).
String generarAvatarIniciales(String nombre, String uid) {
  const lado = ReglasCohetazo.avatarLado;
  final color = colorDeJugador(uid);
  final imagen = img.Image(width: lado, height: lado);
  img.fill(
    imagen,
    color: img.ColorRgb8(
      (color >> 16) & 0xFF,
      (color >> 8) & 0xFF,
      color & 0xFF,
    ),
  );
  final texto = inicialesDe(nombre);
  // arial48 solo trae caracteres latinos básicos; el resto se muestra como «?».
  final seguro = texto.runes.every((r) => r >= 32 && r < 127) ? texto : '?';
  img.drawString(
    imagen,
    seguro,
    font: img.arial48,
    color: img.ColorRgb8(255, 255, 255),
  );
  return base64Encode(img.encodeJpg(imagen, quality: 80));
}
