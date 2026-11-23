import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../auth/viewmodels/sesion_view_model.dart';
import '../models/participante.dart';
import '../repositories/participante_repository.dart';

/// Estado de la pantalla de participantes (patrón Observer).
class ParticipantesViewModel extends ChangeNotifier {
  ParticipantesViewModel(this._repository, {required this.sesion}) {
    _suscripcion = _repository.participantes.listen(
      (lista) {
        _participantes = lista;
        _cargando = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object _) {
        _cargando = false;
        _error = 'No pudimos cargar los participantes. Intenta de nuevo.';
        notifyListeners();
      },
    );
  }

  final ParticipanteRepository _repository;
  final SesionViewModel sesion;
  late final StreamSubscription<List<Participante>> _suscripcion;

  List<Participante> _participantes = const [];
  bool _cargando = true;
  String? _error;

  List<Participante> get participantes => _participantes;
  bool get cargando => _cargando;
  String? get error => _error;
  bool get vacio => !_cargando && _error == null && _participantes.isEmpty;

  /// Cuántos participantes respondieron [asistencia].
  int conteo(Asistencia asistencia) =>
      _participantes.where((p) => p.asistencia == asistencia).length;

  Map<Asistencia, int> get conteos => {
    for (final a in Asistencia.values) a: conteo(a),
  };

  /// `true` si la fila es la de la persona con sesión.
  bool esYo(String id) => id == sesion.uid;

  /// Cada quien cambia su propia asistencia; el admin la de cualquiera.
  bool puedeCambiarAsistencia(String id) => sesion.esAdmin || esYo(id);

  /// Solo el admin quita participantes de la lista.
  bool get puedeEliminar => sesion.esAdmin;

  Future<bool> cambiarAsistencia(String id, Asistencia asistencia) {
    if (!puedeCambiarAsistencia(id)) {
      return _rechazar('Solo puedes cambiar tu propia asistencia.');
    }
    return _ejecutar(
      () => _repository.cambiarAsistencia(id, asistencia),
      'cambiar la asistencia',
    );
  }

  Future<bool> eliminar(String id) {
    if (!puedeEliminar) {
      return _rechazar('Solo el organizador puede quitar participantes.');
    }
    return _ejecutar(() => _repository.eliminar(id), 'eliminar');
  }

  Future<bool> _rechazar(String mensaje) async {
    _error = mensaje;
    notifyListeners();
    return false;
  }

  Future<bool> _ejecutar(
    Future<void> Function() accion,
    String queHacer,
  ) async {
    try {
      await accion();
    } catch (_) {
      _error = 'No pudimos $queHacer al participante. Intenta de nuevo.';
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
