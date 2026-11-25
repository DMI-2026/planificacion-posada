import 'dart:async';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:firebase_database/firebase_database.dart';

import '../models/caja_rota.dart';
import '../models/cohete.dart';
import '../models/eliminacion.dart';
import '../models/jugador.dart';
import 'cohetazo_repository.dart';

/// Implementación sobre Firebase Realtime Database.
class RtdbCohetazoRepository implements CohetazoRepository {
  RtdbCohetazoRepository({FirebaseDatabase? database})
    : _db = database ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;

  DatabaseReference get _raiz => _db.ref('cohetazo');

  /// Nodos `onDisconnect` pendientes, por uid.
  final Map<String, OnDisconnect> _alDesconectar = {};

  static Map<Object?, Object?> _mapa(Object? valor) =>
      valor is Map ? Map<Object?, Object?>.from(valor) : const {};

  Stream<Map<Object?, Object?>> _hijos(String ruta) =>
      _raiz.child(ruta).onValue.map((e) => _mapa(e.snapshot.value));

  @override
  Stream<List<Jugador>> get jugadores => _hijos('jugadores').map(
    (m) => [
      for (final e in m.entries)
        if (e.value is Map)
          Jugador.fromMap(
            '${e.key}',
            Map<Object?, Object?>.from(e.value! as Map),
          ),
    ],
  );

  @override
  Stream<List<Cohete>> get cohetes => _hijos('cohetes').map(
    (m) => [
      for (final e in m.entries)
        if (e.value is Map)
          Cohete.fromMap(
            '${e.key}',
            Map<Object?, Object?>.from(e.value! as Map),
          ),
    ],
  );

  @override
  Stream<List<CajaRota>> get cajas => _hijos('cajas').map(
    (m) => [
      for (final e in m.entries)
        if (e.value is Map)
          CajaRota.fromMap(
            '${e.key}',
            Map<Object?, Object?>.from(e.value! as Map),
          ),
    ],
  );

  @override
  Stream<Set<String>> get mejoras =>
      _hijos('mejoras').map((m) => {for (final k in m.keys) '$k'});

  @override
  Stream<List<Eliminacion>> get eliminaciones => _hijos('eliminaciones').map(
    (m) => [
      for (final e in m.values)
        if (e is Map) Eliminacion.fromMap(Map<Object?, Object?>.from(e)),
    ],
  );

  @override
  Stream<Map<String, String>> get avatares => _hijos('avatares').map(
    (m) => {
      for (final e in m.entries)
        if (e.value is String) '${e.key}': e.value! as String,
    },
  );

  @override
  Stream<int> get desfaseServidor => _db
      .ref('.info/serverTimeOffset')
      .onValue
      .map(
        (e) => e.snapshot.value is num ? (e.snapshot.value! as num).toInt() : 0,
      );

  @override
  Future<void> entrar(Jugador jugador, String avatar) async {
    final uid = jugador.uid;
    final nodo = _raiz.child('jugadores/$uid');
    final alDesconectar = nodo.onDisconnect();
    // El onDisconnect se programa antes de escribir: si la conexión cae justo
    // después, el nodo no queda huérfano.
    await alDesconectar.remove();
    _alDesconectar[uid] = alDesconectar;
    await _raiz.child('avatares/$uid').set(avatar);
    await nodo.set(jugador.toMap(marcaTiempo: ServerValue.timestamp));
  }

  @override
  Future<void> actualizarJugador(Jugador jugador) => _raiz
      .child('jugadores/${jugador.uid}')
      .set(jugador.toMap(marcaTiempo: ServerValue.timestamp));

  @override
  Future<String> colocarCohete(Cohete cohete) async {
    final nodo = _raiz.child('cohetes').push();
    await nodo.set(cohete.toMap(marcaTiempo: ServerValue.timestamp));
    return nodo.key!;
  }

  @override
  Future<void> romperCaja(int x, int y, String uid) => _raiz
      .child('cajas/${CajaRota.claveCaja(x, y)}')
      .set(
        CajaRota(
          x: x,
          y: y,
          rota: 0,
          por: uid,
        ).toMap(marcaTiempo: ServerValue.timestamp),
      );

  @override
  Future<bool> reclamarMejora(String clave, String uid) async {
    final resultado = await _raiz.child('mejoras/$clave').runTransaction((
      actual,
    ) {
      if (actual != null) return Transaction.abort();
      return Transaction.success(uid);
    }, applyLocally: false);
    return resultado.committed && resultado.snapshot.value == uid;
  }

  @override
  Future<void> registrarEliminacion({
    required String victima,
    required String autor,
  }) => _raiz
      .child('eliminaciones')
      .push()
      .set(
        Eliminacion(
          victima: victima,
          autor: autor,
          t: 0,
        ).toMap(marcaTiempo: ServerValue.timestamp),
      );

  @override
  Future<void> limpiarCohetesViejos(Iterable<String> ids) async {
    for (final id in ids) {
      try {
        await _raiz.child('cohetes/$id').remove();
      } on FirebaseException {
        // Otro cliente ya lo borró o aún no cumple los 10 s: se reintenta.
      }
    }
  }

  @override
  Future<void> salir(String uid) async {
    final alDesconectar = _alDesconectar.remove(uid);
    await alDesconectar?.cancel();
    await _raiz.child('jugadores/$uid').remove();
  }
}
