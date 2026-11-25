import 'dart:async';

import '../models/caja_rota.dart';
import '../models/cohete.dart';
import '../models/eliminacion.dart';
import '../models/jugador.dart';
import 'cohetazo_repository.dart';

/// Repositorio en memoria para pruebas y vistas sin nube.
///
/// Imita al servidor: [reloj] es la hora del servidor (los instantes
/// `colocado`, `rota` y `t` salen de él) y [desfase] es lo que reporta
/// `.info/serverTimeOffset`.
class FakeCohetazoRepository implements CohetazoRepository {
  FakeCohetazoRepository({int Function()? reloj, this.desfase = 0})
    : reloj = reloj ?? (() => DateTime.now().millisecondsSinceEpoch);

  /// Hora del servidor (ms).
  final int Function() reloj;

  /// Lo que reporta `.info/serverTimeOffset`.
  final int desfase;

  final Map<String, Jugador> _jugadores = {};
  final Map<String, Cohete> _cohetes = {};
  final Map<String, CajaRota> _cajas = {};
  final Map<String, String> _mejoras = {};
  final List<Eliminacion> _eliminaciones = [];
  final Map<String, String> _avatares = {};
  int _siguienteId = 1;

  final _cJugadores = StreamController<List<Jugador>>.broadcast();
  final _cCohetes = StreamController<List<Cohete>>.broadcast();
  final _cCajas = StreamController<List<CajaRota>>.broadcast();
  final _cMejoras = StreamController<Set<String>>.broadcast();
  final _cEliminaciones = StreamController<List<Eliminacion>>.broadcast();
  final _cAvatares = StreamController<Map<String, String>>.broadcast();

  /// Registro de llamadas para las pruebas.
  final List<Jugador> escriturasJugador = [];
  final List<(int, int, String)> cajasRotasEscritas = [];
  final List<String> idsLimpiados = [];
  final List<String> salidas = [];
  int entradas = 0;

  /// Si no es null, la siguiente operación de escritura lanza este error.
  Object? fallarEscritura;

  void _revisarFallo() {
    final f = fallarEscritura;
    if (f != null) {
      fallarEscritura = null;
      throw f;
    }
  }

  Stream<T> _flujo<T>(StreamController<T> c, T Function() actual) =>
      Stream<T>.multi((s) {
        s.add(actual());
        final sub = c.stream.listen(s.add, onError: s.addError);
        s.onCancel = sub.cancel;
      }, isBroadcast: true);

  List<Jugador> _listaJ() => List.unmodifiable(_jugadores.values);
  List<Cohete> _listaC() => List.unmodifiable(_cohetes.values);
  List<CajaRota> _listaCajas() => List.unmodifiable(_cajas.values);

  @override
  Stream<List<Jugador>> get jugadores => _flujo(_cJugadores, _listaJ);

  @override
  Stream<List<Cohete>> get cohetes => _flujo(_cCohetes, _listaC);

  @override
  Stream<List<CajaRota>> get cajas => _flujo(_cCajas, _listaCajas);

  @override
  Stream<Set<String>> get mejoras =>
      _flujo(_cMejoras, () => Set.unmodifiable(_mejoras.keys));

  @override
  Stream<List<Eliminacion>> get eliminaciones =>
      _flujo(_cEliminaciones, () => List.unmodifiable(_eliminaciones));

  @override
  Stream<Map<String, String>> get avatares =>
      _flujo(_cAvatares, () => Map.unmodifiable(_avatares));

  @override
  Stream<int> get desfaseServidor => Stream.value(desfase);

  /// Datos actuales (para afirmar en las pruebas).
  Map<String, Jugador> get jugadoresActuales => Map.unmodifiable(_jugadores);
  Map<String, Cohete> get cohetesActuales => Map.unmodifiable(_cohetes);
  Map<String, CajaRota> get cajasActuales => Map.unmodifiable(_cajas);
  Map<String, String> get mejorasActuales => Map.unmodifiable(_mejoras);
  List<Eliminacion> get eliminacionesActuales =>
      List.unmodifiable(_eliminaciones);
  Map<String, String> get avataresActuales => Map.unmodifiable(_avatares);

  @override
  Future<void> entrar(Jugador jugador, String avatar) async {
    _revisarFallo();
    entradas++;
    _avatares[jugador.uid] = avatar;
    _jugadores[jugador.uid] = jugador.copyWith(t: reloj());
    _cAvatares.add(Map.unmodifiable(_avatares));
    _cJugadores.add(_listaJ());
  }

  @override
  Future<void> actualizarJugador(Jugador jugador) async {
    _revisarFallo();
    escriturasJugador.add(jugador);
    _jugadores[jugador.uid] = jugador.copyWith(t: reloj());
    _cJugadores.add(_listaJ());
  }

  @override
  Future<String> colocarCohete(Cohete cohete) async {
    _revisarFallo();
    final id = 'c${_siguienteId++}';
    _cohetes[id] = Cohete(
      id: id,
      uid: cohete.uid,
      x: cohete.x,
      y: cohete.y,
      alcance: cohete.alcance,
      colocado: reloj(),
    );
    _cCohetes.add(_listaC());
    return id;
  }

  @override
  Future<void> romperCaja(int x, int y, String uid) async {
    _revisarFallo();
    cajasRotasEscritas.add((x, y, uid));
    _cajas[CajaRota.claveCaja(x, y)] = CajaRota(
      x: x,
      y: y,
      rota: reloj(),
      por: uid,
    );
    _cCajas.add(_listaCajas());
  }

  @override
  Future<bool> reclamarMejora(String clave, String uid) async {
    _revisarFallo();
    if (_mejoras.containsKey(clave)) return false;
    _mejoras[clave] = uid;
    _cMejoras.add(Set.unmodifiable(_mejoras.keys));
    return true;
  }

  @override
  Future<void> registrarEliminacion({
    required String victima,
    required String autor,
  }) async {
    _revisarFallo();
    _eliminaciones.add(Eliminacion(victima: victima, autor: autor, t: reloj()));
    _cEliminaciones.add(List.unmodifiable(_eliminaciones));
  }

  @override
  Future<void> limpiarCohetesViejos(Iterable<String> ids) async {
    _revisarFallo();
    for (final id in ids) {
      idsLimpiados.add(id);
      _cohetes.remove(id);
    }
    _cCohetes.add(_listaC());
  }

  @override
  Future<void> salir(String uid) async {
    salidas.add(uid);
    _jugadores.remove(uid);
    _cJugadores.add(_listaJ());
  }

  /// Simula un cambio hecho por otra persona.
  void simularJugador(Jugador j, {String? avatar}) {
    _jugadores[j.uid] = j;
    if (avatar != null) {
      _avatares[j.uid] = avatar;
      _cAvatares.add(Map.unmodifiable(_avatares));
    }
    _cJugadores.add(_listaJ());
  }

  void simularSalida(String uid) {
    _jugadores.remove(uid);
    _cJugadores.add(_listaJ());
  }

  void simularCohete(Cohete c) {
    _cohetes[c.id] = c;
    _cCohetes.add(_listaC());
  }

  void simularCaja(CajaRota c) {
    _cajas[c.clave] = c;
    _cCajas.add(_listaCajas());
  }

  void simularMejora(String clave, String uid) {
    _mejoras[clave] = uid;
    _cMejoras.add(Set.unmodifiable(_mejoras.keys));
  }

  void simularEliminacion(Eliminacion e) {
    _eliminaciones.add(e);
    _cEliminaciones.add(List.unmodifiable(_eliminaciones));
  }

  /// Simula un error de conexión en los flujos.
  void emitirError(Object error) {
    _cJugadores.addError(error);
  }
}
