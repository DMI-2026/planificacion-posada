import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/comida_opcion.dart';
import '../models/limites_votacion.dart';
import '../models/voto.dart';
import '../repositories/votacion_repository.dart';

/// Opción con su conteo de votos para mostrar resultados.
class OpcionResultado {
  const OpcionResultado({
    required this.opcion,
    required this.votos,
    required this.porcentaje,
  });

  final ComidaOpcion opcion;
  final int votos;

  /// Fracción 0..1 sobre el total de votos válidos.
  final double porcentaje;
}

/// Estado de la votación de la comida (patrón Observer).
class VotacionViewModel extends ChangeNotifier {
  VotacionViewModel(
    this._repository, {
    required this.uid,
    required this.esAdmin,
    required this.esParticipante,
  }) {
    _subs = [
      _repository.opciones.listen((l) {
        _opciones = l;
        _cargaOpciones = true;
        _error = null;
        notifyListeners();
      }, onError: _alFallar),
      _repository.votos.listen((l) {
        _votos = l;
        _cargaVotos = true;
        notifyListeners();
      }, onError: _alFallar),
      _repository.cerrada.listen((c) {
        _cerrada = c;
        notifyListeners();
      }, onError: _alFallar),
    ];
  }

  final VotacionRepository _repository;
  final String uid;
  final bool esAdmin;
  final bool esParticipante;
  late final List<StreamSubscription<Object?>> _subs;

  List<ComidaOpcion> _opciones = const [];
  List<Voto> _votos = const [];
  bool _cerrada = false;
  bool _cargaOpciones = false;
  bool _cargaVotos = false;
  String? _error;
  bool _liberado = false;
  bool _falloCarga = false;

  void _alFallar(Object _) {
    _cargaOpciones = true;
    _cargaVotos = true;
    _falloCarga = true;
    _error = 'No pudimos cargar la votación. Intenta de nuevo.';
    notifyListeners();
  }

  bool get cargando => !(_cargaOpciones && _cargaVotos);
  String? get error => _error;
  bool get cerrada => _cerrada;
  bool get vacio => !cargando && !_falloCarga && _opciones.isEmpty;

  /// Votos que apuntan a una opción existente (los huérfanos se ignoran).
  Map<String, int> get _conteo {
    final ids = {for (final o in _opciones) o.id};
    final c = <String, int>{};
    for (final v in _votos) {
      if (ids.contains(v.opcionId)) c[v.opcionId] = (c[v.opcionId] ?? 0) + 1;
    }
    return c;
  }

  int get totalVotos => _conteo.values.fold(0, (a, b) => a + b);

  /// Opciones con votos y porcentaje, de más a menos votadas (empates por
  /// orden de propuesta).
  List<OpcionResultado> get resultados {
    final c = _conteo;
    final total = totalVotos;
    final lista = [
      for (final o in _opciones)
        OpcionResultado(
          opcion: o,
          votos: c[o.id] ?? 0,
          porcentaje: total == 0 ? 0 : (c[o.id] ?? 0) / total,
        ),
    ];
    // sort de Dart no es estable: desempata por posición original.
    final pos = {for (var i = 0; i < _opciones.length; i++) _opciones[i].id: i};
    lista.sort((a, b) {
      final d = b.votos.compareTo(a.votos);
      return d != 0 ? d : pos[a.opcion.id]!.compareTo(pos[b.opcion.id]!);
    });
    return lista;
  }

  /// Id de la opción por la que votó esta persona (si todavía existe).
  String? get miVoto {
    for (final v in _votos) {
      if (v.uid == uid && _opciones.any((o) => o.id == v.opcionId)) {
        return v.opcionId;
      }
    }
    return null;
  }

  /// Con la votación cerrada: las opciones con más votos (todas si hay
  /// empate). Vacío si está abierta o nadie votó.
  List<ComidaOpcion> get ganadores {
    if (!_cerrada) return const [];
    final r = resultados;
    if (r.isEmpty || r.first.votos == 0) return const [];
    return [
      for (final x in r)
        if (x.votos == r.first.votos) x.opcion,
    ];
  }

  /// Con la votación cerrada solo el admin puede eliminar (moderación).
  bool puedeEliminar(ComidaOpcion o) =>
      esAdmin || (esParticipante && !_cerrada && o.propuestaPor == uid);

  bool _falla(String mensaje) {
    _error = mensaje;
    notifyListeners();
    return false;
  }

  Future<bool> proponer(String nombre, String descripcion) async {
    if (!esParticipante) {
      return _falla('Solo los participantes pueden proponer platillos.');
    }
    if (_cerrada) return _falla('La votación está cerrada.');
    final n = nombre.trim();
    final d = descripcion.trim();
    if (n.length < LimitesVotacion.nombreMin) {
      return _falla('El nombre del platillo no puede estar vacío.');
    }
    if (n.length > LimitesVotacion.nombreMax) {
      return _falla(
        'El nombre no puede pasar de ${LimitesVotacion.nombreMax} caracteres.',
      );
    }
    if (d.length > LimitesVotacion.descripcionMax) {
      return _falla(
        'La descripción no puede pasar de '
        '${LimitesVotacion.descripcionMax} caracteres.',
      );
    }
    return _ejecutar(
      () => _repository.proponer(nombre: n, descripcion: d, uid: uid),
      'proponer el platillo',
    );
  }

  Future<bool> votar(String opcionId) async {
    if (!esParticipante) {
      return _falla('Solo los participantes pueden votar.');
    }
    if (_cerrada) return _falla('La votación está cerrada.');
    if (!_opciones.any((o) => o.id == opcionId)) {
      return _falla('Ese platillo ya no existe.');
    }
    return _ejecutar(() => _repository.votar(uid, opcionId), 'votar');
  }

  Future<bool> quitarVoto() async {
    if (_cerrada) return _falla('La votación está cerrada.');
    return _ejecutar(() => _repository.quitarVoto(uid), 'quitar tu voto');
  }

  Future<bool> eliminarOpcion(String id) async {
    ComidaOpcion? o;
    for (final x in _opciones) {
      if (x.id == id) o = x;
    }
    if (o == null) return _falla('Ese platillo ya no existe.');
    if (!puedeEliminar(o)) {
      if (_cerrada && !esAdmin) return _falla('La votación está cerrada.');
      return _falla('Solo quien lo propuso o el admin puede eliminarlo.');
    }
    return _ejecutar(
      () => _repository.eliminarOpcion(id),
      'eliminar el platillo',
    );
  }

  Future<bool> cerrar() => _fijarCerrada(true);
  Future<bool> reabrir() => _fijarCerrada(false);

  Future<bool> _fijarCerrada(bool valor) async {
    if (!esAdmin) {
      return _falla('Solo el admin puede cerrar o reabrir la votación.');
    }
    return _ejecutar(
      () => _repository.fijarCerrada(valor),
      valor ? 'cerrar la votación' : 'reabrir la votación',
    );
  }

  void limpiarError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<bool> _ejecutar(Future<void> Function() accion, String que) async {
    try {
      await accion();
      if (_error != null) {
        _error = null;
        if (!_liberado) notifyListeners();
      }
      return true;
    } catch (_) {
      _error = 'No pudimos $que. Intenta de nuevo.';
      if (!_liberado) notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _liberado = true;
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
