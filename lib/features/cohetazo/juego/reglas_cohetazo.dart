/// Constantes compartidas del Cohetazo navideño (ver contrato de la feature).
abstract final class ReglasCohetazo {
  /// Dimensiones de la cuadrícula (celdas).
  static const int columnas = 21;
  static const int filas = 17;

  /// Constante de semilla de la arena.
  static const int semillaArena = 2026;

  /// Porcentaje de celdas libres que empiezan con caja.
  static const int probabilidadCaja = 55;

  /// Porcentaje de cajas rotas que sueltan una mejora.
  static const int probabilidadMejora = 30;

  /// Tiempos en milisegundos (hora del servidor).
  static const int explosionMs = 2500;
  static const int fuegoMs = 600;
  static const int rebroteCajaMs = 30000;
  static const int reaparicionMs = 3000;
  static const int invulnerabilidadMs = 1500;

  /// Un cohete con más de este tiempo desde `colocado` se puede limpiar.
  static const int limpiezaCoheteMs = 10000;

  /// Margen para decidir si un registro de caja rota ya existía antes de una
  /// explosión (la escritura llega con latencia); ver `EstadoArena`.
  static const int toleranciaRotaMs = 2000;

  /// Valores base y topes de las mejoras.
  static const int alcanceBase = 2;
  static const int alcanceMax = 6;
  static const int cohetesBase = 1;
  static const int cohetesMax = 5;
  static const int velocidadBase = 0;
  static const int velocidadMax = 3;

  /// Velocidad base (celdas/s) y aumento por nivel.
  static const int celdasPorSegundoBase = 4;

  /// Velocidad de movimiento en celdas por segundo para un nivel.
  static int celdasPorSegundo(int velocidad) =>
      celdasPorSegundoBase + velocidad;

  /// Avatar: longitud máxima del base64 y lado de la miniatura (px).
  static const int avatarMaxLongitud = 20000;
  static const int avatarLado = 96;

  /// Longitud máxima del nombre.
  static const int nombreMaxLongitud = 40;
}
