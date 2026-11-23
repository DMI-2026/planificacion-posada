import '../models/participante.dart';

/// Acceso a los participantes de la posada (patrón Repository).
///
/// Los participantes son las cuentas registradas: el id del documento es el
/// uid de la persona. No hay invitados sin cuenta.
abstract class ParticipanteRepository {
  Stream<List<Participante>> get participantes;

  /// Crea `participantes/{uid}` con asistencia [Asistencia.talVez] solo si no
  /// existe; nunca sobrescribe un documento existente.
  Future<void> asegurar(String uid, String nombre);

  Future<void> cambiarAsistencia(String id, Asistencia asistencia);

  /// Quita el documento. Si esa persona vuelve a iniciar sesión, reaparece.
  Future<void> eliminar(String id);
}
