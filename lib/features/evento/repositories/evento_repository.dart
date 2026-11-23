import '../models/evento.dart';

/// Acceso al evento de la posada.
///
/// Las pantallas dependen de esta interfaz, no de Firestore: en pruebas se
/// sustituye por [FakeEventoRepository] (patrón Repository).
abstract class EventoRepository {
  /// Emite el evento actual; `null` mientras no se haya guardado ninguno.
  Stream<Evento?> get evento;

  Future<void> guardar(Evento evento);
}
