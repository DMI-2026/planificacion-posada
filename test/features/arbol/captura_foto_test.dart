import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:planificacion_posada/features/arbol/models/adorno.dart';
import 'package:planificacion_posada/features/arbol/services/captura_foto.dart';

/// Imagen de [ancho]x[alto] con tres franjas verticales: rojo, verde y azul
/// (el tercio central es verde).
Uint8List _franjas(int ancho, int alto, {bool png = true}) {
  final im = img.Image(width: ancho, height: alto);
  for (final p in im) {
    final tercio = (p.x * 3) ~/ ancho;
    p.setRgb(
      tercio == 0 ? 255 : 0,
      tercio == 1 ? 255 : 0,
      tercio == 2 ? 255 : 0,
    );
  }
  return png ? img.encodePng(im) : img.encodeJpg(im);
}

void main() {
  group('procesarFoto', () {
    test('devuelve un JPEG de 160x160 dentro del límite', () {
      final b64 = procesarFoto(_franjas(640, 480));
      expect(b64.length, lessThanOrEqualTo(LimitesArbol.maxFotoBase64));
      final bytes = base64Decode(b64);
      // Firma de JPEG.
      expect(bytes.sublist(0, 3), [0xFF, 0xD8, 0xFF]);
      final im = img.decodeJpg(bytes)!;
      expect(im.width, LimitesArbol.ladoFoto);
      expect(im.height, LimitesArbol.ladoFoto);
      expect(LimitesArbol.ladoFoto, 160);
    });

    test('recorta al centro una imagen horizontal', () {
      // 600x200: el cuadrado central (x 200..400) es todo verde.
      final im = img.decodeJpg(base64Decode(procesarFoto(_franjas(600, 200))))!;
      for (final (x, y) in [(5, 5), (80, 80), (154, 5), (5, 154), (154, 154)]) {
        final p = im.getPixel(x, y);
        expect(p.g, greaterThan(200), reason: 'verde en ($x,$y)');
        expect(p.r, lessThan(60), reason: 'sin rojo en ($x,$y)');
        expect(p.b, lessThan(60), reason: 'sin azul en ($x,$y)');
      }
    });

    test('recorta al centro una imagen vertical', () {
      // 200x600 con franjas horizontales: rojo, verde, azul (centro = verde).
      final origen = img.Image(width: 200, height: 600);
      for (final p in origen) {
        final tercio = (p.y * 3) ~/ 600;
        p.setRgb(
          tercio == 0 ? 255 : 0,
          tercio == 1 ? 255 : 0,
          tercio == 2 ? 255 : 0,
        );
      }
      final im = img.decodeJpg(
        base64Decode(procesarFoto(img.encodePng(origen))),
      )!;
      final p = im.getPixel(80, 80);
      expect(p.g, greaterThan(200));
      expect(p.r, lessThan(60));
      expect(p.b, lessThan(60));
    });

    test('una foto con mucho ruido sigue cabiendo en el límite', () {
      final azar = math.Random(7);
      final im = img.Image(width: 640, height: 480);
      for (final p in im) {
        p.setRgb(azar.nextInt(256), azar.nextInt(256), azar.nextInt(256));
      }
      final b64 = procesarFoto(img.encodeJpg(im, quality: 95));
      expect(b64.length, lessThanOrEqualTo(LimitesArbol.maxFotoBase64));
      expect(img.decodeJpg(base64Decode(b64))!.width, 160);
    });

    test('acepta una imagen ya cuadrada y pequeña', () {
      final im = img.decodeJpg(
        base64Decode(procesarFoto(_franjas(90, 90, png: false))),
      )!;
      expect((im.width, im.height), (160, 160));
    });

    test('lado y límite opcionales: miniatura de 96 px dentro de 20000', () {
      final azar = math.Random(3);
      final im = img.Image(width: 640, height: 480);
      for (final p in im) {
        p.setRgb(azar.nextInt(256), azar.nextInt(256), azar.nextInt(256));
      }
      final b64 = procesarFoto(
        img.encodeJpg(im, quality: 95),
        lado: 96,
        maxBase64: 20000,
      );
      expect(b64.length, lessThanOrEqualTo(20000));
      final salida = img.decodeJpg(base64Decode(b64))!;
      expect((salida.width, salida.height), (96, 96));
    });

    test('un límite imposible lanza CapturaFotoException', () {
      expect(
        () => procesarFoto(_franjas(200, 200), maxBase64: 10),
        throwsA(isA<CapturaFotoException>()),
      );
    });

    test('bytes que no son una imagen lanzan CapturaFotoException', () {
      expect(
        () => procesarFoto(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(
          isA<CapturaFotoException>().having(
            (e) => e.mensaje,
            'mensaje',
            'No pudimos leer la foto. Intenta tomarla de nuevo.',
          ),
        ),
      );
    });
  });
}
