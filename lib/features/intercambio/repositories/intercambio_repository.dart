import '../models/asignacion.dart';
import '../models/config_intercambio.dart';
import '../models/inscrito.dart';

/// Acceso a los datos del intercambio (Strategy: Firestore o memoria).
abstract class IntercambioRepository {
  /// Configuración; sin documento emite la configuración por defecto.
  Stream<ConfigIntercambio> get config;

  /// Todos los inscritos con sus deseos (no son secretos).
  Stream<List<Inscrito>> get inscritos;

  /// Asignación propia (`null` si no hay). Siempre legible por su dueño.
  Stream<Asignacion?> miAsignacion(String uid);

  /// Todas las asignaciones. Solo legibles con el sorteo revelado o siendo
  /// admin: suscríbete únicamente en esos casos.
  Stream<List<Asignacion>> get asignaciones;

  Future<void> guardarInscrito(Inscrito inscrito);
  Future<void> eliminarInscrito(String uid);

  /// Escribe el documento completo de configuración (solo admin).
  Future<void> guardarConfig(ConfigIntercambio config);

  /// Reemplaza todas las asignaciones y guarda la configuración en una sola
  /// operación atómica (solo admin).
  Future<void> publicarSorteo(
    List<Asignacion> asignaciones,
    ConfigIntercambio config,
  );
}
