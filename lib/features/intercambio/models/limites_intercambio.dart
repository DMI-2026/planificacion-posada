/// Límites del intercambio. Si los cambias, actualiza también
/// `intercambio.rules` (mismos números).
class LimitesIntercambio {
  const LimitesIntercambio._();

  /// Deseos por persona (0..3).
  static const int maxDeseos = 3;

  /// Caracteres por deseo (1..80).
  static const int maxCaracteresDeseo = 80;

  /// Presupuesto máximo: $100,000.00 en centavos.
  static const int maxPresupuestoCentavos = 10000000;

  /// Inscritos mínimos para poder sortear.
  static const int minInscritos = 2;
}
