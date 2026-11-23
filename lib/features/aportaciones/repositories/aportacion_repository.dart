import '../models/aportacion.dart';

/// Acceso a las aportaciones de la posada (patrón Repository).
abstract class AportacionRepository {
  /// Todas las aportaciones (materiales y económicas).
  Stream<List<Aportacion>> get aportaciones;

  /// Meta de recaudación en centavos; `null` si no hay.
  Stream<int?> get meta;

  Future<void> agregar(String articulo, int cantidad);

  /// Registra una aportación económica (aún no recibida).
  Future<void> agregarEconomica(String responsableId, int montoCentavos);

  /// Asigna un responsable; `null` lo quita.
  Future<void> asignar(String id, String? responsableId);

  Future<void> marcarLista(String id, bool lista);

  Future<void> editarMonto(String id, int montoCentavos);

  Future<void> marcarRecibido(String id, bool recibido);

  /// Guarda la meta; `null` la quita.
  Future<void> guardarMeta(int? centavos);

  Future<void> eliminar(String id);
}
