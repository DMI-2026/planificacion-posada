import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/validacion/limites.dart';
import '../../participantes/models/participante.dart';
import '../models/aportacion.dart';
import '../repositories/aportacion_repository.dart';

/// Estado de la pantalla de aportaciones (patrón Observer).
class AportacionesViewModel extends ChangeNotifier {
  AportacionesViewModel(this._repository) {
    _suscripcion = _repository.aportaciones.listen(
      (lista) {
        _aportaciones = lista;
        _cargando = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object _) {
        _cargando = false;
        _error = 'No pudimos cargar las aportaciones. Intenta de nuevo.';
        notifyListeners();
      },
    );
  }

  final AportacionRepository _repository;
  late final StreamSubscription<List<Aportacion>> _suscripcion;

  List<Aportacion> _aportaciones = const [];
  bool _cargando = true;
  String? _error;

  List<Aportacion> get aportaciones => _aportaciones;
  bool get cargando => _cargando;
  String? get error => _error;
  bool get vacio => !_cargando && _error == null && _aportaciones.isEmpty;
  int get listas => _aportaciones.where((a) => a.lista).length;
  int get pendientes => _aportaciones.length - listas;

  /// Devuelve `false` y deja [error] si el artículo o la cantidad no son válidos.
  Future<bool> agregar(String articulo, int cantidad) async {
    final limpio = articulo.trim();
    if (limpio.isEmpty) {
      _error = 'El artículo no puede estar vacío.';
      notifyListeners();
      return false;
    }
    if (limpio.length > Limites.articulo) {
      _error = 'El artículo no puede pasar de ${Limites.articulo} caracteres.';
      notifyListeners();
      return false;
    }
    if (cantidad > Limites.cantidadMaxima) {
      _error = 'La cantidad no puede pasar de ${Limites.cantidadMaxima}.';
      notifyListeners();
      return false;
    }
    if (cantidad < 1) {
      _error = 'La cantidad debe ser al menos 1.';
      notifyListeners();
      return false;
    }
    return _ejecutar(() => _repository.agregar(limpio, cantidad), 'agregar');
  }

  Future<bool> asignar(String id, String? responsableId) =>
      _ejecutar(() => _repository.asignar(id, responsableId), 'asignar');

  Future<bool> marcarLista(String id, bool lista) =>
      _ejecutar(() => _repository.marcarLista(id, lista), 'actualizar');

  Future<bool> eliminar(String id) =>
      _ejecutar(() => _repository.eliminar(id), 'eliminar');

  /// Nombre del responsable, o `Sin asignar` si no hay o ya no existe.
  String nombreResponsable(
    Aportacion aportacion,
    List<Participante> participantes,
  ) {
    for (final p in participantes) {
      if (p.id == aportacion.responsableId) return p.nombre;
    }
    return 'Sin asignar';
  }

  Future<bool> _ejecutar(
    Future<void> Function() accion,
    String queHacer,
  ) async {
    try {
      await accion();
    } catch (_) {
      _error = 'No pudimos $queHacer la aportación. Intenta de nuevo.';
      notifyListeners();
      return false;
    }
    _error = null;
    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    _suscripcion.cancel();
    super.dispose();
  }
}
