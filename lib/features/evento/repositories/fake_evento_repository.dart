import 'dart:async';

import '../models/evento.dart';
import 'evento_repository.dart';

/// Repositorio en memoria para pruebas y para las vistas sin nube.
class FakeEventoRepository implements EventoRepository {
  FakeEventoRepository({Evento? inicial}) : _actual = inicial;

  Evento? _actual;
  final _controlador = StreamController<Evento?>.broadcast();

  /// Si es `true`, [guardar] lanza una excepción.
  bool falla = false;

  /// Número de suscriptores activos (útil para probar `dispose`).
  int escuchas = 0;

  @override
  Stream<Evento?> get evento => Stream<Evento?>.multi((c) {
    escuchas++;
    c.add(_actual);
    final sub = _controlador.stream.listen(c.add, onError: c.addError);
    c.onCancel = () {
      escuchas--;
      return sub.cancel();
    };
  }, isBroadcast: true);

  @override
  Future<void> guardar(Evento evento) async {
    if (falla) throw Exception('fallo simulado');
    _actual = evento;
    _controlador.add(_actual);
  }

  /// Simula un error del stream.
  void emitirError(Object error) => _controlador.addError(error);
}
