import '../models/actividad.dart';

/// Acceso al itinerario de la posada (patrón Repository).
abstract class ItinerarioRepository {
  Stream<List<Actividad>> get actividades;

  /// Crea la actividad (el `id` de [actividad] se ignora).
  Future<void> agregar(Actividad actividad);

  /// Reemplaza los datos de la actividad con ese `id`.
  Future<void> editar(Actividad actividad);

  Future<void> eliminar(String id);
}
