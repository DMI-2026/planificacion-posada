import '../models/adorno.dart';

/// Acceso a los adornos del árbol (colección `arbol_adornos`).
abstract class ArbolRepository {
  /// Todos los adornos; emite el estado actual al escuchar y luego cada cambio.
  Stream<List<Adorno>> get adornos;

  /// Crea el adorno con el id [Adorno.id] (`{uid}_{slot}`).
  Future<void> crear(Adorno adorno);

  /// Cambia solo la posición.
  Future<void> mover(String id, double x, double y);

  /// Cambia color, patrón (y foto)/listón y mensaje (no tipo, autor ni posición).
  Future<void> editar(Adorno adorno);

  Future<void> eliminar(String id);
}
