import '../models/participante.dart';

/// Acceso a los participantes de la posada (patrón Repository).
abstract class ParticipanteRepository {
  Stream<List<Participante>> get participantes;

  /// Agrega un participante con asistencia [Asistencia.talVez].
  Future<void> agregar(String nombre);

  Future<void> cambiarAsistencia(String id, Asistencia asistencia);

  Future<void> eliminar(String id);
}
