import 'dart:async';

import '../models/comida_opcion.dart';
import '../models/voto.dart';
import 'votacion_repository.dart';

/// Repositorio en memoria para pruebas y vistas sin nube. Cada stream emite
/// el estado actual al suscribirse.
class FakeVotacionRepository implements VotacionRepository {
  FakeVotacionRepository({
    List<ComidaOpcion> opciones = const [],
    List<Voto> votos = const [],
    bool cerrada = false,
  }) : _opciones = List.of(opciones),
       _votos = {for (final v in votos) v.uid: v},
       // ignore: prefer_initializing_formals
       _cerrada = cerrada,
       _siguienteId = opciones.length + 1;

  final List<ComidaOpcion> _opciones;
  final Map<String, Voto> _votos;
  bool _cerrada;
  int _siguienteId;

  final _cOpciones = StreamController<List<ComidaOpcion>>.broadcast();
  final _cVotos = StreamController<List<Voto>>.broadcast();
  final _cCerrada = StreamController<bool>.broadcast();

  /// Suscriptores activos (útil para probar `dispose`).
  int escuchas = 0;

  Stream<T> _flujo<T>(StreamController<T> c, T Function() actual) =>
      Stream<T>.multi((s) {
        escuchas++;
        s.add(actual());
        final sub = c.stream.listen(s.add, onError: s.addError);
        s.onCancel = () {
          escuchas--;
          return sub.cancel();
        };
      }, isBroadcast: true);

  @override
  Stream<List<ComidaOpcion>> get opciones =>
      _flujo(_cOpciones, () => List.unmodifiable(_opciones));

  @override
  Stream<List<Voto>> get votos =>
      _flujo(_cVotos, () => List.unmodifiable(_votos.values));

  @override
  Stream<bool> get cerrada => _flujo(_cCerrada, () => _cerrada);

  /// Simula un error en el stream de opciones.
  void emitirError(Object error) => _cOpciones.addError(error);

  @override
  Future<void> proponer({
    required String nombre,
    required String descripcion,
    required String uid,
  }) async {
    _opciones.add(
      ComidaOpcion(
        id: 'o-${_siguienteId++}',
        nombre: nombre,
        descripcion: descripcion,
        propuestaPor: uid,
        creada: DateTime.now(),
      ),
    );
    _cOpciones.add(List.unmodifiable(_opciones));
  }

  @override
  Future<void> eliminarOpcion(String id) async {
    // Como en Firestore, los votos huérfanos se quedan: los resultados los
    // ignoran.
    _opciones.removeWhere((o) => o.id == id);
    _cOpciones.add(List.unmodifiable(_opciones));
  }

  @override
  Future<void> votar(String uid, String opcionId) async {
    _votos[uid] = Voto(uid: uid, opcionId: opcionId);
    _cVotos.add(List.unmodifiable(_votos.values));
  }

  @override
  Future<void> quitarVoto(String uid) async {
    _votos.remove(uid);
    _cVotos.add(List.unmodifiable(_votos.values));
  }

  @override
  Future<void> fijarCerrada(bool cerrada) async {
    _cerrada = cerrada;
    _cCerrada.add(cerrada);
  }
}
