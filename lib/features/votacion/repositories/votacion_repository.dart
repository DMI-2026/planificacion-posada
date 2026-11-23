import '../models/comida_opcion.dart';
import '../models/voto.dart';

/// Acceso a los datos de la votación de la comida.
abstract class VotacionRepository {
  Stream<List<ComidaOpcion>> get opciones;
  Stream<List<Voto>> get votos;

  /// `true` si la votación está cerrada (`config/votacion`).
  Stream<bool> get cerrada;

  Future<void> proponer({
    required String nombre,
    required String descripcion,
    required String uid,
  });

  Future<void> eliminarOpcion(String id);

  /// Crea o reemplaza el voto de [uid].
  Future<void> votar(String uid, String opcionId);

  Future<void> quitarVoto(String uid);

  Future<void> fijarCerrada(bool cerrada);
}
