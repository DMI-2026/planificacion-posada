import 'package:audioplayers/audioplayers.dart';

/// Música de fondo del árbol. Abstracción para poder inyectar un falso en
/// las pruebas; la implementación real usa `audioplayers`.
abstract class MusicaArbol {
  /// Empieza (o reanuda) la melodía en loop. Devuelve `false` si no pudo
  /// sonar (sin dispositivo de audio, autoplay bloqueado por el navegador).
  Future<bool> iniciar();

  /// Pausa la melodía.
  Future<void> pausar();

  /// Detiene y libera el reproductor. No se usa después.
  Future<void> liberar();
}

/// «Jingle Bells» (`assets/audio/jingle_bells.wav`) en loop con `audioplayers`.
/// Nunca lanza: cualquier fallo se traduce en `false`.
class MusicaArbolAudio implements MusicaArbol {
  static const double volumen = 0.4;

  AudioPlayer? _jugador;
  bool _cargada = false;

  @override
  Future<bool> iniciar() async {
    try {
      final jugador = _jugador ??= AudioPlayer();
      if (_cargada) {
        await jugador.resume();
      } else {
        await jugador.setReleaseMode(ReleaseMode.loop);
        await jugador.setVolume(volumen);
        await jugador.play(AssetSource('audio/jingle_bells.wav'));
        _cargada = true;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> pausar() async {
    try {
      await _jugador?.pause();
    } catch (_) {}
  }

  @override
  Future<void> liberar() async {
    final jugador = _jugador;
    _jugador = null;
    try {
      await jugador?.stop();
      await jugador?.dispose();
    } catch (_) {}
  }
}
