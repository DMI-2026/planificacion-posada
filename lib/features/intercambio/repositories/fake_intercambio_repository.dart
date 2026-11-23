import 'dart:async';

import '../models/asignacion.dart';
import '../models/config_intercambio.dart';
import '../models/inscrito.dart';
import 'intercambio_repository.dart';

/// Repositorio en memoria para pruebas y vistas sin nube.
class FakeIntercambioRepository implements IntercambioRepository {
  FakeIntercambioRepository({
    ConfigIntercambio config = const ConfigIntercambio(),
    List<Inscrito> inscritos = const [],
    List<Asignacion> asignaciones = const [],
  }) : _config = config.copyWith(),
       _inscritos = {for (final i in inscritos) i.uid: i},
       _asignaciones = {for (final a in asignaciones) a.uid: a};

  ConfigIntercambio _config;
  final Map<String, Inscrito> _inscritos;
  final Map<String, Asignacion> _asignaciones;

  final _cConfig = StreamController<ConfigIntercambio>.broadcast();
  final _cInscritos = StreamController<List<Inscrito>>.broadcast();
  final _cAsignaciones = StreamController<List<Asignacion>>.broadcast();

  /// Si no es nulo, toda escritura lanza este error (para probar fallos).
  Object? fallarCon;

  /// Suscriptores activos (útil para probar `dispose`).
  int escuchas = 0;

  /// Suscripciones abiertas a `asignaciones` (la lista completa).
  int escuchasTodas = 0;

  /// Estado actual (para aserciones).
  ConfigIntercambio get configActual => _config;
  List<Inscrito> get inscritosActuales => List.unmodifiable(_inscritos.values);
  List<Asignacion> get asignacionesActuales =>
      List.unmodifiable(_asignaciones.values);

  Stream<T> _flujo<T>(
    StreamController<T> c,
    T Function() actual, {
    void Function(int)? alCambiar,
  }) => Stream<T>.multi((s) {
    escuchas++;
    alCambiar?.call(1);
    s.add(actual());
    final sub = c.stream.listen(s.add, onError: s.addError);
    s.onCancel = () {
      escuchas--;
      alCambiar?.call(-1);
      return sub.cancel();
    };
  }, isBroadcast: true);

  @override
  Stream<ConfigIntercambio> get config => _flujo(_cConfig, () => _config);

  @override
  Stream<List<Inscrito>> get inscritos =>
      _flujo(_cInscritos, () => List.unmodifiable(_inscritos.values));

  @override
  Stream<Asignacion?> miAsignacion(String uid) =>
      Stream<Asignacion?>.multi((s) {
        escuchas++;
        s.add(_asignaciones[uid]);
        final sub = _cAsignaciones.stream.listen(
          (_) => s.add(_asignaciones[uid]),
          onError: s.addError,
        );
        s.onCancel = () {
          escuchas--;
          return sub.cancel();
        };
      }, isBroadcast: true);

  @override
  Stream<List<Asignacion>> get asignaciones => _flujo(
    _cAsignaciones,
    () => List.unmodifiable(_asignaciones.values),
    alCambiar: (d) => escuchasTodas += d,
  );

  void _comprobar() {
    final e = fallarCon;
    if (e != null) throw e;
  }

  void _emitir() {
    _cConfig.add(_config);
    _cInscritos.add(List.unmodifiable(_inscritos.values));
    _cAsignaciones.add(List.unmodifiable(_asignaciones.values));
  }

  @override
  Future<void> guardarInscrito(Inscrito inscrito) async {
    _comprobar();
    _inscritos[inscrito.uid] = inscrito;
    _emitir();
  }

  @override
  Future<void> eliminarInscrito(String uid) async {
    _comprobar();
    _inscritos.remove(uid);
    _emitir();
  }

  @override
  Future<void> guardarConfig(ConfigIntercambio config) async {
    _comprobar();
    _config = config;
    _emitir();
  }

  @override
  Future<void> publicarSorteo(
    List<Asignacion> asignaciones,
    ConfigIntercambio config,
  ) async {
    _comprobar();
    _asignaciones
      ..clear()
      ..addEntries(asignaciones.map((a) => MapEntry(a.uid, a)));
    _config = config;
    _emitir();
  }
}
