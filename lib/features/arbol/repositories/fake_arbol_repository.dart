import 'dart:async';

import '../models/adorno.dart';
import 'arbol_repository.dart';

/// Repositorio en memoria para pruebas y vistas sin nube.
class FakeArbolRepository implements ArbolRepository {
  FakeArbolRepository({List<Adorno> inicial = const []})
    : _lista = List.of(inicial);

  final List<Adorno> _lista;
  final _controlador = StreamController<List<Adorno>>.broadcast();

  /// Suscriptores activos (útil para probar `dispose`).
  int escuchas = 0;

  /// Registro de escrituras de posición, en orden: (id, x, y).
  final List<(String, double, double)> movimientos = [];

  /// Si no es null, la siguiente escritura falla con este error.
  Object? fallarEscritura;

  @override
  Stream<List<Adorno>> get adornos => Stream<List<Adorno>>.multi((c) {
    escuchas++;
    c.add(List.unmodifiable(_lista));
    final sub = _controlador.stream.listen(c.add, onError: c.addError);
    c.onCancel = () {
      escuchas--;
      return sub.cancel();
    };
  }, isBroadcast: true);

  void _emitir() => _controlador.add(List.unmodifiable(_lista));

  void _revisarFallo() {
    final f = fallarEscritura;
    if (f != null) {
      fallarEscritura = null;
      throw f;
    }
  }

  /// Simula un error del stream.
  void emitirError(Object error) => _controlador.addError(error);

  /// Simula un cambio hecho por otra persona (agrega o reemplaza por id).
  void simularRemoto(Adorno adorno) {
    final i = _lista.indexWhere((a) => a.id == adorno.id);
    if (i < 0) {
      _lista.add(adorno);
    } else {
      _lista[i] = adorno;
    }
    _emitir();
  }

  @override
  Future<void> crear(Adorno adorno) async {
    _revisarFallo();
    final i = _lista.indexWhere((a) => a.id == adorno.id);
    if (i < 0) {
      _lista.add(adorno);
    } else {
      _lista[i] = adorno;
    }
    _emitir();
  }

  @override
  Future<void> mover(String id, double x, double y) async {
    _revisarFallo();
    movimientos.add((id, x, y));
    final i = _lista.indexWhere((a) => a.id == id);
    if (i < 0) return;
    _lista[i] = _lista[i].copyWith(x: x, y: y);
    _emitir();
  }

  @override
  Future<void> editar(Adorno adorno) async {
    _revisarFallo();
    final i = _lista.indexWhere((a) => a.id == adorno.id);
    if (i < 0) return;
    _lista[i] = _lista[i].copyWith(
      color: adorno.color,
      patron: adorno.patron,
      colorMono: adorno.colorMono,
      mensaje: adorno.mensaje,
    );
    _emitir();
  }

  @override
  Future<void> eliminar(String id) async {
    _revisarFallo();
    _lista.removeWhere((a) => a.id == id);
    _emitir();
  }
}
