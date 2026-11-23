import 'dart:async';

import '../models/aportacion.dart';
import 'aportacion_repository.dart';

/// Repositorio en memoria para pruebas y para las vistas sin nube.
class FakeAportacionRepository implements AportacionRepository {
  FakeAportacionRepository({List<Aportacion> inicial = const []})
    : _lista = List.of(inicial),
      _siguienteId = inicial.length + 1;

  final List<Aportacion> _lista;
  int _siguienteId;
  final _controlador = StreamController<List<Aportacion>>.broadcast();

  /// Número de suscriptores activos (útil para probar `dispose`).
  int escuchas = 0;

  @override
  Stream<List<Aportacion>> get aportaciones =>
      Stream<List<Aportacion>>.multi((c) {
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
  Future<void> agregar(String articulo, int cantidad) async {
    _lista.add(
      Aportacion(
        id: 'a-${_siguienteId++}',
        articulo: articulo,
        cantidad: cantidad,
      ),
    );
    _emitir();
  }

  @override
  Future<void> asignar(String id, String? responsableId) async {
    final i = _lista.indexWhere((a) => a.id == id);
    if (i == -1) return;
    _lista[i] = responsableId == null
        ? _lista[i].copyWith(sinResponsable: true)
        : _lista[i].copyWith(responsableId: responsableId);
    _emitir();
  }

  @override
  Future<void> marcarLista(String id, bool lista) async {
    final i = _lista.indexWhere((a) => a.id == id);
    if (i == -1) return;
    _lista[i] = _lista[i].copyWith(lista: lista);
    _emitir();
  }

  @override
  Future<void> eliminar(String id) async {
    _lista.removeWhere((a) => a.id == id);
    _emitir();
  }
}
