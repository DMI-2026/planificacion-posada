import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:planificacion_posada/features/cohetazo/juego/reglas_cohetazo.dart';
import 'package:planificacion_posada/features/cohetazo/services/avatar_iniciales.dart';

void main() {
  test('inicialesDe toma hasta dos letras en mayúscula', () {
    expect(inicialesDe('ana maría pérez'), 'AM');
    expect(inicialesDe('  luis '), 'L');
    expect(inicialesDe(''), '?');
  });

  test('el color de un jugador es estable y está en la paleta', () {
    expect(colorDeJugador('u1'), colorDeJugador('u1'));
    expect(coloresJugador, contains(colorDeJugador('cualquiera')));
  });

  test('el avatar de iniciales es un JPEG de 96 px dentro del límite', () {
    final b64 = generarAvatarIniciales('Ana López', 'u1');
    expect(b64.length, lessThanOrEqualTo(ReglasCohetazo.avatarMaxLongitud));
    final bytes = base64Decode(b64);
    expect(bytes.sublist(0, 3), [0xFF, 0xD8, 0xFF]);
    final im = img.decodeJpg(bytes)!;
    expect((im.width, im.height), (96, 96));
  });

  test('un nombre con letras no latinas no rompe la generación', () {
    expect(generarAvatarIniciales('Ñandú', 'u2'), isNotEmpty);
    expect(generarAvatarIniciales('李雷', 'u3'), isNotEmpty);
  });
}
