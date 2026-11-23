import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/asignacion.dart';
import '../models/config_intercambio.dart';
import '../models/inscrito.dart';
import '../models/limites_intercambio.dart';
import '../repositories/intercambio_repository.dart';
import '../utilidades/sorteo.dart';

/// A quién le regalo: su nombre y lo que desea.
class MiDestinatario {
  const MiDestinatario({
    required this.uid,
    required this.nombre,
    required this.deseos,
  });

  final String uid;
  final String nombre;
  final List<String> deseos;
}

/// Una pareja del sorteo (quien da -> quien recibe), con nombres.
class Pareja {
  const Pareja({
    required this.dadorId,
    required this.dadorNombre,
    required this.receptorId,
    required this.receptorNombre,
  });

  final String dadorId;
  final String dadorNombre;
  final String receptorId;
  final String receptorNombre;
}

/// Estado del intercambio de regalos (patrón Observer).
///
/// `nombres` (uid -> nombre) es un mapa simple que entrega quien integra el
/// módulo (por ejemplo, desde `participantes`); si cambia, llama a
/// [actualizarNombres]. Un uid desconocido se muestra como "Alguien".
///
/// Las asignaciones ajenas solo se leen cuando el sorteo está revelado o la
/// persona es admin (así lo exigen las reglas); la propia se lee siempre.
class IntercambioViewModel extends ChangeNotifier {
  IntercambioViewModel(
    this._repository, {
    required this.uid,
    required this.esAdmin,
    required this.esParticipante,
    Map<String, String> nombres = const {},
    Random? random,
  }) : _nombres = Map.of(nombres),
       _random = random ?? Random.secure() {
    _subs = [
      _repository.config.listen((c) {
        _config = c;
        _cargaConfig = true;
        _sincronizarTodas();
        notifyListeners();
      }, onError: _alFallar),
      _repository.inscritos.listen((l) {
        _inscritos = l;
        _cargaInscritos = true;
        notifyListeners();
      }, onError: _alFallar),
      _repository.miAsignacion(uid).listen((a) {
        _mia = a;
        notifyListeners();
      }, onError: _alFallar),
    ];
  }

  final IntercambioRepository _repository;
  final String uid;
  final bool esAdmin;
  final bool esParticipante;
  final Random _random;
  late final List<StreamSubscription<Object?>> _subs;
  StreamSubscription<Object?>? _subTodas;

  Map<String, String> _nombres;
  ConfigIntercambio _config = const ConfigIntercambio();
  List<Inscrito> _inscritos = const [];
  Asignacion? _mia;
  List<Asignacion> _todas = const [];
  bool _cargaConfig = false;
  bool _cargaInscritos = false;
  bool _ocupado = false;
  String? _error;
  bool _liberado = false;

  void _alFallar(Object _) {
    _cargaConfig = true;
    _cargaInscritos = true;
    _error = 'No pudimos cargar el intercambio. Intenta de nuevo.';
    notifyListeners();
  }

  /// Escucha todas las asignaciones solo si se puede (revelado o admin).
  void _sincronizarTodas() {
    final debe = _config.revelado || esAdmin;
    if (debe && _subTodas == null) {
      _subTodas = _repository.asignaciones.listen((l) {
        _todas = l;
        notifyListeners();
      }, onError: _alFallar);
    }
  }

  void actualizarNombres(Map<String, String> nombres) {
    _nombres = Map.of(nombres);
    notifyListeners();
  }

  String nombreDe(String id) => _nombres[id] ?? 'Alguien';

  bool get cargando => !(_cargaConfig && _cargaInscritos) && _error == null;
  String? get error => _error;
  bool get ocupado => _ocupado;
  ConfigIntercambio get config => _config;

  Inscrito? get inscrito {
    for (final i in _inscritos) {
      if (i.uid == uid) return i;
    }
    return null;
  }

  List<String> get misDeseos => inscrito?.deseos ?? const [];
  int get totalInscritos => _inscritos.length;

  /// Nombres de los inscritos, ordenados.
  List<String> get nombresInscritos =>
      [for (final i in _inscritos) nombreDe(i.uid)]..sort();

  bool get puedeInscribirse =>
      esParticipante &&
      _config.inscripcionAbierta &&
      !_config.sorteado &&
      inscrito == null;

  bool get puedeEditarDeseos =>
      esParticipante &&
      _config.inscripcionAbierta &&
      !_config.sorteado &&
      inscrito != null;

  /// Mi destinatario, solo si ya hubo sorteo y tengo asignación.
  MiDestinatario? get miDestinatario {
    final a = _mia;
    if (a == null || !_config.sorteado) return null;
    final deseos = [
      for (final i in _inscritos)
        if (i.uid == a.destinatarioId) ...i.deseos,
    ];
    return MiDestinatario(
      uid: a.destinatarioId,
      nombre: nombreDe(a.destinatarioId),
      deseos: deseos,
    );
  }

  /// Todas las parejas: con el sorteo revelado, o siempre para el admin.
  List<Pareja> get parejas {
    if (!(_config.revelado || esAdmin)) return const [];
    final lista = [
      for (final a in _todas)
        Pareja(
          dadorId: a.uid,
          dadorNombre: nombreDe(a.uid),
          receptorId: a.destinatarioId,
          receptorNombre: nombreDe(a.destinatarioId),
        ),
    ]..sort((x, y) => x.dadorNombre.compareTo(y.dadorNombre));
    return lista;
  }

  void limpiarError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  // ---- participantes

  String? _validarDeseos(List<String> deseos) {
    if (deseos.length > LimitesIntercambio.maxDeseos) {
      return 'Máximo ${LimitesIntercambio.maxDeseos} deseos.';
    }
    for (final d in deseos) {
      if (d.trim().isEmpty) return 'Un deseo no puede estar vacío.';
      if (d.trim().length > LimitesIntercambio.maxCaracteresDeseo) {
        return 'Cada deseo admite máximo '
            '${LimitesIntercambio.maxCaracteresDeseo} caracteres.';
      }
    }
    return null;
  }

  static const _cerrada = 'La inscripción al intercambio está cerrada.';

  Future<bool> inscribirse(List<String> deseos) async {
    if (!esParticipante) {
      return _rechazar(
        'Solo quienes están en la lista de la posada pueden inscribirse.',
      );
    }
    if (!_config.inscripcionAbierta || _config.sorteado) {
      return _rechazar(_cerrada);
    }
    final v = _validarDeseos(deseos);
    if (v != null) return _rechazar(v);
    return _ejecutar(
      () => _repository.guardarInscrito(
        Inscrito(uid: uid, deseos: [for (final d in deseos) d.trim()]),
      ),
    );
  }

  Future<bool> actualizarDeseos(List<String> deseos) async {
    if (inscrito == null) {
      return _rechazar('Primero inscríbete al intercambio.');
    }
    if (!_config.inscripcionAbierta || _config.sorteado) {
      return _rechazar(_cerrada);
    }
    final v = _validarDeseos(deseos);
    if (v != null) return _rechazar(v);
    return _ejecutar(
      () => _repository.guardarInscrito(
        Inscrito(uid: uid, deseos: [for (final d in deseos) d.trim()]),
      ),
    );
  }

  Future<bool> salir() async {
    if (inscrito == null) {
      return _rechazar('Primero inscríbete al intercambio.');
    }
    if (!_config.inscripcionAbierta || _config.sorteado) {
      return _rechazar(_cerrada);
    }
    return _ejecutar(() => _repository.eliminarInscrito(uid));
  }

  // ---- admin

  static const _soloAdmin = 'Solo el organizador puede hacer esto.';

  Future<bool> abrirInscripcion() async {
    if (!esAdmin) return _rechazar(_soloAdmin);
    if (_config.sorteado) return _rechazar('El sorteo ya se realizó.');
    return _ejecutar(
      () =>
          _repository.guardarConfig(_config.copyWith(inscripcionAbierta: true)),
    );
  }

  Future<bool> cerrarInscripcion() async {
    if (!esAdmin) return _rechazar(_soloAdmin);
    return _ejecutar(
      () => _repository.guardarConfig(
        _config.copyWith(inscripcionAbierta: false),
      ),
    );
  }

  Future<bool> _publicar() {
    final ids = [for (final i in _inscritos) i.uid];
    final pares = sortearParejas(ids, _random);
    return _ejecutar(
      () => _repository.publicarSorteo([
        for (final e in pares.entries)
          Asignacion(uid: e.key, destinatarioId: e.value),
      ], _config.copyWith(sorteado: true, inscripcionAbierta: false)),
    );
  }

  /// Hace el sorteo (desarreglo de un solo ciclo) y lo guarda de una vez.
  Future<bool> sortear() async {
    if (!esAdmin) return _rechazar(_soloAdmin);
    if (_config.sorteado) return _rechazar('El sorteo ya se realizó.');
    if (_config.inscripcionAbierta) {
      return _rechazar('Cierra la inscripción antes de sortear.');
    }
    if (_inscritos.length < LimitesIntercambio.minInscritos) {
      return _rechazar('Se necesitan al menos 2 inscritos para sortear.');
    }
    return _publicar();
  }

  Future<bool> rehacerSorteo() async {
    if (!esAdmin) return _rechazar(_soloAdmin);
    if (!_config.sorteado) return _rechazar('Primero haz el sorteo.');
    if (_config.revelado) {
      return _rechazar('El sorteo ya fue revelado; no se puede rehacer.');
    }
    if (_inscritos.length < LimitesIntercambio.minInscritos) {
      return _rechazar('Se necesitan al menos 2 inscritos para sortear.');
    }
    return _publicar();
  }

  Future<bool> revelar() async {
    if (!esAdmin) return _rechazar(_soloAdmin);
    if (!_config.sorteado) return _rechazar('Primero haz el sorteo.');
    if (_config.revelado) return _rechazar('El sorteo ya fue revelado.');
    return _ejecutar(
      () => _repository.guardarConfig(_config.copyWith(revelado: true)),
    );
  }

  Future<bool> editarPresupuesto(int centavos) async {
    if (!esAdmin) return _rechazar(_soloAdmin);
    if (centavos < 0 || centavos > LimitesIntercambio.maxPresupuestoCentavos) {
      return _rechazar(
        'El presupuesto debe estar entre \$0.00 y \$100,000.00.',
      );
    }
    return _ejecutar(
      () => _repository.guardarConfig(
        _config.copyWith(presupuestoCentavos: centavos),
      ),
    );
  }

  /// `null` quita la fecha.
  Future<bool> editarFecha(DateTime? fecha) async {
    if (!esAdmin) return _rechazar(_soloAdmin);
    return _ejecutar(
      () => _repository.guardarConfig(
        fecha == null
            ? _config.copyWith(quitarFecha: true)
            : _config.copyWith(fecha: fecha),
      ),
    );
  }

  // ---- utilidades

  bool _rechazar(String mensaje) {
    _error = mensaje;
    notifyListeners();
    return false;
  }

  Future<bool> _ejecutar(Future<void> Function() accion) async {
    _ocupado = true;
    _error = null;
    notifyListeners();
    try {
      await accion();
      return true;
    } catch (_) {
      _error = 'No pudimos guardar los cambios. Intenta de nuevo.';
      return false;
    } finally {
      _ocupado = false;
      notifyListeners();
    }
  }

  @override
  void notifyListeners() {
    if (_liberado) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _liberado = true;
    for (final s in _subs) {
      s.cancel();
    }
    _subTodas?.cancel();
    super.dispose();
  }
}
