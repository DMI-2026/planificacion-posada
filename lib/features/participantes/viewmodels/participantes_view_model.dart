import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/validacion/limites.dart';
import '../models/participante.dart';
import '../repositories/participante_repository.dart';

/// Estado de la pantalla de participantes (patrón Observer).
class ParticipantesViewModel extends ChangeNotifier {
  ParticipantesViewModel(this._repository) {
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

  /// Devuelve `false` y deja [error] si el nombre está vacío.
  Future<bool> agregar(String nombre) async {
    final limpio = nombre.trim();
    if (limpio.isEmpty) {
      _error = 'El nombre del participante no puede estar vacío.';
      notifyListeners();
      return false;
    }
    if (limpio.length > Limites.nombreParticipante) {
      _error =
          'El nombre no puede pasar de ${Limites.nombreParticipante} caracteres.';
      notifyListeners();
      return false;
    }
    return _ejecutar(() => _repository.agregar(limpio), 'agregar');
  }

  Future<bool> cambiarAsistencia(String id, Asistencia asistencia) => _ejecutar(
    () => _repository.cambiarAsistencia(id, asistencia),
    'cambiar la asistencia',
  );

  Future<bool> eliminar(String id) =>
      _ejecutar(() => _repository.eliminar(id), 'eliminar');

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
