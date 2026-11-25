import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;

import '../models/adorno.dart';

/// La cámara no se pudo usar; [mensaje] está listo para mostrarse.
class CapturaFotoException implements Exception {
  const CapturaFotoException(this.mensaje);

  final String mensaje;

  @override
  String toString() => 'CapturaFotoException: $mensaje';
}

/// Convierte la imagen [bytes] (JPEG, PNG...) en la miniatura de la esfera:
/// recorta al centro un cuadrado, la reduce a
/// [LimitesArbol.ladoFoto]x[LimitesArbol.ladoFoto], la codifica como JPEG y la
/// devuelve en base64 (siempre dentro de [LimitesArbol.maxFotoBase64]).
///
/// [lado] y [maxBase64] cambian el tamaño de la miniatura y el límite del
/// texto (por defecto los de las esferas); el avatar del Cohetazo usa 96 px y
/// 20000 caracteres.
///
/// Lanza [CapturaFotoException] si los bytes no son una imagen o no cabe en el
/// límite.
String procesarFoto(
  Uint8List bytes, {
  int lado = LimitesArbol.ladoFoto,
  int maxBase64 = LimitesArbol.maxFotoBase64,
}) {
  final origen = img.decodeImage(bytes);
  if (origen == null) {
    throw const CapturaFotoException(
      'No pudimos leer la foto. Intenta tomarla de nuevo.',
    );
  }
  final corte = origen.width < origen.height ? origen.width : origen.height;
  final cuadrada = img.copyCrop(
    origen,
    x: (origen.width - corte) ~/ 2,
    y: (origen.height - corte) ~/ 2,
    width: corte,
    height: corte,
  );
  final miniatura = img.copyResize(
    cuadrada,
    width: lado,
    height: lado,
    interpolation: img.Interpolation.average,
  );
  for (final calidad in const [70, 55, 40, 25]) {
    final texto = base64Encode(img.encodeJpg(miniatura, quality: calidad));
    if (texto.length <= maxBase64) return texto;
  }
  throw const CapturaFotoException(
    'La foto es demasiado grande. Intenta tomarla de nuevo.',
  );
}

/// Acceso a la cámara para tomar la foto de una esfera. Se separa para poder
/// sustituirlo en las pruebas.
abstract class CapturaFoto {
  /// Abre la cámara. Lanza [CapturaFotoException] si no hay cámara o falta el
  /// permiso.
  Future<void> iniciar();

  /// Vista en vivo de la cámara (válida tras [iniciar]).
  Widget vista(BuildContext context);

  /// Toma una foto y devuelve sus bytes (JPEG o PNG).
  Future<Uint8List> tomar();

  /// Libera la cámara.
  Future<void> liberar();
}

/// Implementación con el paquete `camera` (web y Android).
///
/// En web `getUserMedia` solo funciona con https o en `localhost`.
class CapturaFotoCamara implements CapturaFoto {
  CameraController? _controlador;

  @override
  Future<void> iniciar() async {
    try {
      final camaras = await availableCameras();
      if (camaras.isEmpty) {
        throw const CapturaFotoException(
          'No encontramos una cámara en este dispositivo.',
        );
      }
      final descripcion = camaras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => camaras.first,
      );
      final controlador = CameraController(
        descripcion,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      _controlador = controlador;
      await controlador.initialize();
    } on CameraException catch (e) {
      await liberar();
      throw CapturaFotoException(_mensajeDe(e));
    }
  }

  static String _mensajeDe(CameraException e) {
    final c = e.code.toLowerCase();
    if (c.contains('denied') ||
        c.contains('permission') ||
        c.contains('notallowed') ||
        c.contains('security')) {
      return 'No tenemos permiso para usar la cámara. Actívalo en tu '
          'navegador o en los ajustes y vuelve a intentarlo.';
    }
    if (c.contains('notfound') || c.contains('nocamera')) {
      return 'No encontramos una cámara en este dispositivo.';
    }
    return 'No pudimos abrir la cámara. Revisa que no la use otra aplicación.';
  }

  /// Vista en vivo recortada al centro en un cuadrado, igual que la miniatura.
  @override
  Widget vista(BuildContext context) {
    final controlador = _controlador!;
    return LayoutBuilder(
      builder: (context, c) {
        final lado = c.biggest.shortestSide;
        return ClipRect(
          child: OverflowBox(
            minWidth: 0,
            minHeight: 0,
            maxWidth: lado * 2,
            maxHeight: lado * 2,
            child: CameraPreview(controlador),
          ),
        );
      },
    );
  }

  @override
  Future<Uint8List> tomar() async {
    final c = _controlador;
    if (c == null || !c.value.isInitialized) {
      throw const CapturaFotoException('La cámara no está lista.');
    }
    try {
      final archivo = await c.takePicture();
      return await archivo.readAsBytes();
    } on CameraException catch (e) {
      throw CapturaFotoException(_mensajeDe(e));
    }
  }

  @override
  Future<void> liberar() async {
    final c = _controlador;
    _controlador = null;
    await c?.dispose();
  }
}
