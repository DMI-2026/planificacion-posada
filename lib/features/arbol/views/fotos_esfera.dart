import 'dart:convert';
import 'dart:ui' as ui;

/// Fotos de esferas ya decodificadas, por su texto base64.
///
/// Se decodifica una sola vez por foto (no en cada cuadro) y se comparte entre
/// todos los dibujos de la misma foto. Una foto que no se puede decodificar
/// queda registrada como fallida (`null`) para no intentarlo otra vez: la
/// esfera se dibuja entonces sin foto.
abstract final class FotosEsfera {
  static const int _maximo = 64;

  static final Map<String, ui.Image?> _listas = {};
  static final Map<String, Future<ui.Image?>> _pendientes = {};

  /// Imagen ya decodificada, o `null` si falta o falló (ver [intentada]).
  static ui.Image? lista(String foto) => _listas[foto];

  /// Si la foto ya se intentó decodificar (con o sin éxito).
  static bool intentada(String foto) => _listas.containsKey(foto);

  /// Decodifica la foto (una vez) y devuelve la imagen, o `null` si es
  /// inválida. Nunca lanza.
  static Future<ui.Image?> cargar(String foto) {
    if (_listas.containsKey(foto)) return Future.value(_listas[foto]);
    return _pendientes[foto] ??= _decodificar(foto).then((imagen) {
      _pendientes.remove(foto);
      if (_listas.length >= _maximo) _listas.remove(_listas.keys.first);
      _listas[foto] = imagen;
      return imagen;
    });
  }

  static Future<ui.Image?> _decodificar(String foto) async {
    try {
      final codec = await ui.instantiateImageCodec(base64Decode(foto));
      final cuadro = await codec.getNextFrame();
      codec.dispose();
      return cuadro.image;
    } catch (_) {
      return null;
    }
  }

  /// Olvida todo (para pruebas).
  static void vaciar() {
    _listas.clear();
    _pendientes.clear();
  }
}
