import 'dart:async';

import '../models/aportacion.dart';
import 'aportacion_repository.dart';

/// Repositorio en memoria para pruebas y para las vistas sin nube.
class FakeAportacionRepository implements AportacionRepository {
  FakeAportacionRepository({
    List<Aportacion> inicial = const [],
    int? metaInicial,
  }) : _lista = List.of(inicial),
       _meta = metaInicial,
       _siguienteId = inicial.length + 1;

  final List<Aportacion> _lista;
  int? _meta;
  int _siguienteId;
  final _controlador = StreamController<List<Aportacion>>.broadcast();
  final _controladorMeta = StreamController<int?>.broadcast();

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

  @override
  Stream<int?> get meta => Stream<int?>.multi((c) {
    escuchas++;
    c.add(_meta);
    final sub = _controladorMeta.stream.listen(c.add, onError: c.addError);
    c.onCancel = () {
      escuchas--;
      return sub.cancel();
    };
  }, isBroadcast: true);

  void _emitir() => _controlador.add(List.unmodifiable(_lista));

  /// Simula un error del stream.
  void emitirError(Object error) => _controlador.addError(error);

  /// Simula un error del stream de la meta.
  void emitirErrorMeta(Object error) => _controladorMeta.addError(error);

  /// Cuántas veces se llamó a un método que escribe (útil para comprobar que
  /// una entrada rechazada no llega al repositorio).
  int escrituras = 0;

  @override
  Future<void> agregar(String articulo, int cantidad) async {
    escrituras++;
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
  Future<void> agregarEconomica(String responsableId, int montoCentavos) async {
    escrituras++;
    _lista.add(
      Aportacion.economica(
        id: 'a-${_siguienteId++}',
        responsableId: responsableId,
        montoCentavos: montoCentavos,
      ),
    );
    _emitir();
  }

  @override
  Future<void> asignar(String id, String? responsableId) async {
    escrituras++;
    final i = _lista.indexWhere((a) => a.id == id);
    if (i == -1) return;
    _lista[i] = responsableId == null
        ? _lista[i].copyWith(sinResponsable: true)
        : _lista[i].copyWith(responsableId: responsableId);
    _emitir();
  }

  @override
  Future<void> marcarLista(String id, bool lista) async {
    escrituras++;
    final i = _lista.indexWhere((a) => a.id == id);
    if (i == -1) return;
    _lista[i] = _lista[i].copyWith(lista: lista);
    _emitir();
  }

  @override
  Future<void> editarMonto(String id, int montoCentavos) async {
    escrituras++;
    final i = _lista.indexWhere((a) => a.id == id);
    if (i == -1) return;
    _lista[i] = _lista[i].copyWith(montoCentavos: montoCentavos);
    _emitir();
  }

  @override
  Future<void> marcarRecibido(String id, bool recibido) async {
    escrituras++;
    final i = _lista.indexWhere((a) => a.id == id);
    if (i == -1) return;
    _lista[i] = _lista[i].copyWith(recibido: recibido);
    _emitir();
  }

  @override
  Future<void> guardarMeta(int? centavos) async {
    escrituras++;
    _meta = centavos;
    _controladorMeta.add(_meta);
  }

  @override
  Future<void> eliminar(String id) async {
    escrituras++;
    _lista.removeWhere((a) => a.id == id);
    _emitir();
  }
}
