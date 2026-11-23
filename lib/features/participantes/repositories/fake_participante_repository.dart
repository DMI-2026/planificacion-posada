import 'dart:async';

import '../models/participante.dart';
import 'participante_repository.dart';

/// Repositorio en memoria para pruebas y para las vistas sin nube.
class FakeParticipanteRepository implements ParticipanteRepository {
  FakeParticipanteRepository({List<Participante> inicial = const []})
    : _lista = List.of(inicial);

  final List<Participante> _lista;
  final _controlador = StreamController<List<Participante>>.broadcast();

  /// Número de suscriptores activos (útil para probar `dispose`).
  int escuchas = 0;

  @override
  Stream<List<Participante>> get participantes =>
      Stream<List<Participante>>.multi((c) {
        escuchas++;
        c.add(List.unmodifiable(_lista));
        final sub = _controlador.stream.listen(c.add, onError: c.addError);
        c.onCancel = () {
          escuchas--;
          return sub.cancel();
        };
      }, isBroadcast: true);

  void _emitir() => _controlador.add(List.unmodifiable(_lista));

  /// Simula un error del stream.
  void emitirError(Object error) => _controlador.addError(error);

  @override
  Future<void> asegurar(String uid, String nombre) async {
    if (_lista.any((p) => p.id == uid)) return;
    _lista.add(Participante(id: uid, nombre: nombre));
    _emitir();
  }

  @override
  Future<void> cambiarAsistencia(String id, Asistencia asistencia) async {
    final i = _lista.indexWhere((p) => p.id == id);
    if (i == -1) return;
    _lista[i] = _lista[i].copyWith(asistencia: asistencia);
    _emitir();
  }

  @override
  Future<void> eliminar(String id) async {
    _lista.removeWhere((p) => p.id == id);
    _emitir();
  }
}
