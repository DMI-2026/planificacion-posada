import '../models/aportacion.dart';

/// Acceso a las aportaciones de la posada (patrón Repository).
abstract class AportacionRepository {
  Stream<List<Aportacion>> get aportaciones;

  Future<void> agregar(String articulo, int cantidad);

  /// Asigna un responsable; `null` lo quita.
  Future<void> asignar(String id, String? responsableId);

  Future<void> marcarLista(String id, bool lista);

  Future<void> eliminar(String id);
}
