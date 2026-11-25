import '../models/caja_rota.dart';
import '../models/cohete.dart';
import '../models/eliminacion.dart';
import '../models/jugador.dart';

/// Acceso a la arena compartida (`/cohetazo` en Realtime Database).
///
/// Todos los instantes (`colocado`, `rota`, `t`...) los pone el servidor; los
/// clientes corrigen su reloj con [desfaseServidor].
abstract class CohetazoRepository {
  /// Jugadores presentes en la arena.
  Stream<List<Jugador>> get jugadores;

  /// Cohetes colocados que aún no se han limpiado.
  Stream<List<Cohete>> get cohetes;

  /// Registros de cajas destruidas.
  Stream<List<CajaRota>> get cajas;

  /// Claves `x_y_rota` de las mejoras ya reclamadas.
  Stream<Set<String>> get mejoras;

  /// Registro de eliminaciones (el marcador se deriva de él).
  Stream<List<Eliminacion>> get eliminaciones;

  /// Avatares base64 JPEG por uid.
  Stream<Map<String, String>> get avatares;

  /// Diferencia en ms entre la hora del servidor y la local
  /// (`.info/serverTimeOffset`): hora del servidor = local + desfase.
  Stream<int> get desfaseServidor;

  /// Entra a la arena: guarda el avatar y el jugador, y deja programado que el
  /// nodo del jugador se elimine al desconectarse.
  Future<void> entrar(Jugador jugador, String avatar);

  /// Escribe el estado del jugador (posición, dirección, vida, mejoras).
  Future<void> actualizarJugador(Jugador jugador);

  /// Coloca un cohete (la hora `colocado` la pone el servidor). Devuelve su id.
  Future<String> colocarCohete(Cohete cohete);

  /// Registra que [uid] destruyó la caja de (x, y) (hora del servidor).
  Future<void> romperCaja(int x, int y, String uid);

  /// Reclama la mejora [clave] (`x_y_rota`) para [uid] en una transacción.
  /// Devuelve `true` si ganó este cliente.
  Future<bool> reclamarMejora(String clave, String uid);

  /// Registra que [victima] fue eliminada por [autor].
  Future<void> registrarEliminacion({
    required String victima,
    required String autor,
  });

  /// Borra cohetes por id (los de más de 10 s, que el servidor permite a
  /// cualquiera).
  Future<void> limpiarCohetesViejos(Iterable<String> ids);

  /// Sale de la arena: borra el nodo del jugador y cancela el onDisconnect.
  Future<void> salir(String uid);
}
