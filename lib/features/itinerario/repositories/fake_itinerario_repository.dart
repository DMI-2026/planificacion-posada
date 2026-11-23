import 'dart:async';

import '../models/actividad.dart';
import 'itinerario_repository.dart';

/// Repositorio en memoria para pruebas y vistas sin nube.
class FakeItinerarioRepository implements ItinerarioRepository {
  FakeItinerarioRepository({List<Actividad> inicial = const []})
    : _lista = List.of(inicial),
      _siguienteId = inicial.length + 1;

  final List<Actividad> _lista;
  int _siguienteId;
  final _controlador = StreamController<List<Actividad>>.broadcast();

  /// Suscriptores activos (útil para probar `dispose`).
  int escuchas = 0;

  @override
  Stream<List<Actividad>> get actividades => Stream<List<Actividad>>.multi((c) {
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
  Future<void> agregar(Actividad actividad) async {
    _lista.add(Actividad.fromMap('i-${_siguienteId++}', actividad.toMap()));
    _emitir();
  }

  @override
  Future<void> editar(Actividad actividad) async {
    final i = _lista.indexWhere((a) => a.id == actividad.id);
    if (i == -1) return;
    _lista[i] = actividad;
    _emitir();
  }

  @override
  Future<void> eliminar(String id) async {
    _lista.removeWhere((a) => a.id == id);
    _emitir();
  }
}
