import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

import '../geometria/arbol_geometria.dart';
import '../models/adorno.dart';
import '../repositories/arbol_repository.dart';

/// Estado del árbol virtual (patrón Observer).
///
/// - [uid]: id de la persona con sesión (también es el prefijo de sus ids).
/// - [esParticipante]: tiene documento `participantes/{uid}`; solo ellos
///   cuelgan adornos (lo exigen también las reglas).
/// - [esAdmin]: puede quitar cualquier adorno.
/// - [nombres]: nombre por uid de autor, que la pantalla toma de la lista de
///   participantes; se actualiza con [actualizarNombres]. Si falta un uid,
///   [nombreAutor] devuelve un texto genérico.
class ArbolViewModel extends ChangeNotifier {
  ArbolViewModel(
    this._repository, {
    required this.uid,
    required this.esAdmin,
    required this.esParticipante,
    Map<String, String> nombres = const {},
    this.intervaloMovimiento = LimitesArbol.intervaloMovimiento,
  }) {
    _nombres = nombres;
    _suscripcion = _repository.adornos.listen(
      (lista) {
        _base = lista;
        _cargando = false;
        _error = null;
        _limpiarLocalesHuerfanos();
        notifyListeners();
      },
      onError: (Object _) {
        _cargando = false;
        _error = 'No pudimos cargar el árbol. Intenta de nuevo.';
        notifyListeners();
      },
    );
  }

  final ArbolRepository _repository;
  final String uid;
  final bool esAdmin;
  final bool esParticipante;

  /// Tiempo mínimo entre dos escrituras de posición mientras se arrastra.
  final Duration intervaloMovimiento;

  late final StreamSubscription<List<Adorno>> _suscripcion;
  Map<String, String> _nombres = const {};

  List<Adorno> _base = const [];
  final Map<String, Offset> _locales = {};
  final Map<String, Timer> _ventanas = {};
  final Map<String, Offset> _pendientes = {};
  bool _cargando = true;
  bool _liberado = false;
  String? _error;

  bool get cargando => _cargando;
  String? get error => _error;

  /// Adornos con la posición local de los que se están arrastrando aquí.
  List<Adorno> get adornos => [
    for (final a in _base)
      if (_locales[a.id] case final p?) a.copyWith(x: p.dx, y: p.dy) else a,
  ];

  List<Adorno> get misAdornos => [
    for (final a in _base)
      if (a.autorId == uid) a,
  ];

  int get cantidadMios => misAdornos.length;

  /// Cuántos adornos más puede colgar esta persona (0 si no es participante).
  int get slotsLibres =>
      esParticipante ? LimitesArbol.maxAdornos - cantidadMios : 0;

  bool get puedeCrear => slotsLibres > 0;
  bool get vacio => !_cargando && _error == null && _base.isEmpty;

  bool esMio(Adorno a) => a.autorId == uid;
  bool puedeMover(Adorno a) => esMio(a);
  bool puedeEditar(Adorno a) => esMio(a);
  bool puedeEliminar(Adorno a) => esMio(a) || esAdmin;

  void actualizarNombres(Map<String, String> nombres) {
    _nombres = nombres;
    notifyListeners();
  }

  /// Nombre de quien colgó el adorno.
  String nombreAutor(String autorId) =>
      _nombres[autorId] ?? (autorId == uid ? 'Tú' : 'Alguien de la clase');

  void limpiarError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  // --- crear ---------------------------------------------------------------

  /// Cuelga una esfera en el primer slot libre. `false` y [error] si no es
  /// válida o no se pudo.
  Future<bool> crearEsfera({
    required String color,
    required PatronEsfera patron,
    String mensaje = '',
  }) {
    return _crear(
      mensaje: mensaje,
      colores: [color],
      construir: (id, m, p) => Adorno(
        id: id,
        tipo: TipoAdorno.esfera,
        autorId: uid,
        color: color,
        patron: patron,
        mensaje: m,
        x: p.dx,
        y: p.dy,
      ),
    );
  }

  /// Cuelga un regalo (caja de [color] con listón [colorMono]).
  Future<bool> crearRegalo({
    required String color,
    required String colorMono,
    String mensaje = '',
  }) {
    return _crear(
      mensaje: mensaje,
      colores: [color, colorMono],
      construir: (id, m, p) => Adorno(
        id: id,
        tipo: TipoAdorno.regalo,
        autorId: uid,
        color: color,
        colorMono: colorMono,
        mensaje: m,
        x: p.dx,
        y: p.dy,
      ),
    );
  }

  Future<bool> _crear({
    required String mensaje,
    required List<String> colores,
    required Adorno Function(String id, String mensaje, Offset pos) construir,
  }) async {
    if (!esParticipante) {
      return _fallo(
        'Solo quienes están en la lista de la posada pueden colgar adornos.',
      );
    }
    final slot = _primerSlotLibre();
    if (slot == null) {
      return _fallo(
        'Ya colgaste tus ${LimitesArbol.maxAdornos} adornos. '
        'Quita uno para colgar otro.',
      );
    }
    final errorDatos = _validar(colores, mensaje);
    if (errorDatos != null) return _fallo(errorDatos);
    final adorno = construir(
      Adorno.idDe(uid, slot),
      mensaje.trim(),
      _posicionLibre(),
    );
    return _ejecutar(() => _repository.crear(adorno), 'colgar el adorno');
  }

  String? _validar(List<String> colores, String mensaje) {
    for (final c in colores) {
      if (!PaletaArbol.esValido(c)) return 'Elige un color de la paleta.';
    }
    if (mensaje.trim().length > LimitesArbol.maxMensaje) {
      return 'El mensaje no puede pasar de ${LimitesArbol.maxMensaje} '
          'caracteres.';
    }
    return null;
  }

  int? _primerSlotLibre() {
    final usados = {for (final a in misAdornos) a.slot};
    for (var s = 0; s < LimitesArbol.maxAdornos; s++) {
      if (!usados.contains(s)) return s;
    }
    return null;
  }

  /// Un punto libre cerca de la parte alta del árbol: de una rejilla de
  /// candidatos dentro de la silueta elige el más lejos de los demás adornos.
  Offset _posicionLibre() {
    Offset mejor = const Offset(0.5, 0.2);
    var mejorDist = -1.0;
    for (var y = 0.16; y <= 0.46; y += 0.05) {
      for (var x = 0.3; x <= 0.7; x += 0.04) {
        final c = ajustarAlArbol(x, y);
        var minDist = double.infinity;
        for (final a in _base) {
          final d = (Offset(a.x, a.y) - c).distance;
          if (d < minDist) minDist = d;
        }
        // Prefiere lo alto: pequeño castigo por bajar.
        final puntaje = math.min(minDist, 0.3) - (c.dy - 0.16) * 0.1;
        if (puntaje > mejorDist) {
          mejorDist = puntaje;
          mejor = c;
        }
      }
    }
    return mejor;
  }

  // --- mover ---------------------------------------------------------------

  /// Mueve un adorno propio: la posición local cambia al instante (se ajusta a
  /// la silueta) y se escribe en la nube a lo más cada [intervaloMovimiento].
  /// Llama a [terminarMovimiento] al soltar.
  void mover(String id, double x, double y) {
    final a = _buscar(id);
    if (a == null || !puedeMover(a)) return;
    final p = ajustarAlArbol(x, y);
    _locales[id] = p;
    notifyListeners();
    if (_ventanas.containsKey(id)) {
      _pendientes[id] = p;
      return;
    }
    unawaited(_escribirPosicion(id, p));
    _ventanas[id] = Timer(intervaloMovimiento, () => _cerrarVentana(id));
  }

  void _cerrarVentana(String id) {
    _ventanas.remove(id);
    final p = _pendientes.remove(id);
    if (p == null || _liberado) return;
    unawaited(_escribirPosicion(id, p));
    _ventanas[id] = Timer(intervaloMovimiento, () => _cerrarVentana(id));
  }

  /// Escritura final al soltar el adorno: siempre guarda la posición actual.
  Future<void> terminarMovimiento(String id) async {
    _ventanas.remove(id)?.cancel();
    _pendientes.remove(id);
    final p = _locales[id];
    if (p == null) return;
    await _escribirPosicion(id, p);
    _locales.remove(id);
    if (!_liberado) notifyListeners();
  }

  Future<void> _escribirPosicion(String id, Offset p) async {
    try {
      await _repository.mover(id, p.dx, p.dy);
    } catch (_) {
      _locales.remove(id);
      _error = 'No pudimos mover el adorno. Intenta de nuevo.';
      if (!_liberado) notifyListeners();
    }
  }

  // --- editar y eliminar -----------------------------------------------------

  /// Cambia color, patrón (esfera) o listón (regalo) y mensaje de un adorno
  /// propio. Lo que no se indica se conserva.
  Future<bool> editar(
    String id, {
    String? color,
    PatronEsfera? patron,
    String? colorMono,
    String? mensaje,
  }) async {
    final a = _buscar(id);
    if (a == null) return _fallo('Ese adorno ya no está en el árbol.');
    if (!puedeEditar(a)) {
      return _fallo('Solo puedes editar tus propios adornos.');
    }
    final nuevo = a.copyWith(
      color: color,
      patron: patron,
      colorMono: colorMono,
      mensaje: mensaje?.trim(),
    );
    final errorDatos = _validar([
      nuevo.color,
      if (nuevo.colorMono != null) nuevo.colorMono!,
    ], nuevo.mensaje);
    if (errorDatos != null) return _fallo(errorDatos);
    return _ejecutar(() => _repository.editar(nuevo), 'guardar el adorno');
  }

  /// Quita un adorno: el autor el suyo, el admin cualquiera.
  Future<bool> eliminar(String id) async {
    final a = _buscar(id);
    if (a == null) return _fallo('Ese adorno ya no está en el árbol.');
    if (!puedeEliminar(a)) {
      return _fallo('Solo puedes quitar tus propios adornos.');
    }
    _ventanas.remove(id)?.cancel();
    _pendientes.remove(id);
    _locales.remove(id);
    return _ejecutar(() => _repository.eliminar(id), 'quitar el adorno');
  }

  // --- internos ------------------------------------------------------------

  Adorno? _buscar(String id) {
    for (final a in _base) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Si el adorno arrastrado desaparece (lo borró otra persona), se descarta
  /// su posición local.
  void _limpiarLocalesHuerfanos() {
    final ids = {for (final a in _base) a.id};
    for (final id in _locales.keys.toList()) {
      if (!ids.contains(id)) {
        _locales.remove(id);
        _ventanas.remove(id)?.cancel();
        _pendientes.remove(id);
      }
    }
  }

  bool _fallo(String mensaje) {
    _error = mensaje;
    notifyListeners();
    return false;
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
    for (final t in _ventanas.values) {
      t.cancel();
    }
    _ventanas.clear();
    _pendientes.clear();
    _suscripcion.cancel();
    super.dispose();
  }
}
