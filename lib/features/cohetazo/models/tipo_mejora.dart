import '../juego/reglas_cohetazo.dart';

/// Mejoras que suelta una caja de regalo.
enum TipoMejora {
  /// +1 de alcance de explosión.
  alcance(ReglasCohetazo.alcanceMax),

  /// +1 cohete simultáneo.
  cohetes(ReglasCohetazo.cohetesMax),

  /// +1 nivel de velocidad.
  velocidad(ReglasCohetazo.velocidadMax);

  const TipoMejora(this.maximo);

  final int maximo;

  String get clave => name;
}
