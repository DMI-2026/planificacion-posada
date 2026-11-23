/// Límites de captura de los datos.
///
/// IMPORTANTE: deben coincidir con las validaciones de `firestore.rules`.
/// Si cambias uno aquí, cámbialo también allá (y en la prueba de reglas).
abstract final class Limites {
  static const int nombreEvento = 100;
  static const int lugarEvento = 200;
  static const int notasEvento = 1000;
  static const int nombreParticipante = 100;
  static const int articulo = 100;
  static const int cantidadMaxima = 999;
}
