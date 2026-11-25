import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../juego/estado_arena.dart';
import '../juego/mapa_arena.dart';
import '../juego/motor_movimiento.dart';
import '../juego/reglas_cohetazo.dart';
import '../models/caja_rota.dart';
import '../models/cohete.dart';
import '../models/direccion.dart';
import '../models/eliminacion.dart';
import '../models/jugador.dart';
import '../repositories/cohetazo_repository.dart';

enum FaseCohetazo { conectando, jugando, error }

/// Fila del marcador.
class EntradaMarcador {
  const EntradaMarcador({
    required this.uid,
    required this.nombre,
    required this.puntos,
    required this.esYo,
  });

  final String uid;
  final String nombre;
  final int puntos;
  final bool esYo;
}

class _Repintar extends ChangeNotifier {
  void repintar() => notifyListeners();
}

/// Bucle local del juego: mueve al jugador propio, coloca cohetes, calcula el
/// estado de la arena con la hora del servidor y decide la muerte, la
/// reaparición y las mejoras del jugador local (cliente autoritativo).
///
/// La vista llama a [paso] en cada cuadro del `Ticker`. [reloj] devuelve la
/// hora local en ms (inyectable en pruebas); la hora del servidor es
/// `reloj() + desfase`.
class CohetazoViewModel extends ChangeNotifier {
  CohetazoViewModel(
    this._repo, {
    required this.uid,
    required String nombre,
    required this.avatar,
    int Function()? reloj,
  }) : nombre = _normalizarNombre(nombre),
       _reloj = reloj ?? (() => DateTime.now().millisecondsSinceEpoch);

  /// Cohete aceptado si ya hay otro en la misma celda hace menos de esto.
  static const int _antirrebote = 300;
  static const int _periodoLimpiezaMs = 2000;
  static const int _ventanaCajasMs = 5000;
  static const double _velocidadRemotoExtra = 1.5;

  final CohetazoRepository _repo;
  final String uid;
  final String nombre;
  final String avatar;
  final int Function() _reloj;

  static String _normalizarNombre(String n) {
    var t = n.trim();
    if (t.isEmpty) t = 'Jugador';
    return t.length > ReglasCohetazo.nombreMaxLongitud
        ? t.substring(0, ReglasCohetazo.nombreMaxLongitud)
        : t;
  }

  FaseCohetazo _fase = FaseCohetazo.conectando;
  String? _error;
  String? _aviso;

  late Jugador _yo = Jugador(uid: uid, nombre: nombre, x: 1, y: 1);
  MotorMovimiento _motor = MotorMovimiento(x: 1, y: 1);
  Direccion? _sostenida;
  int _reapariciones = 0;
  int _desfase = 0;

  Map<String, Jugador> _remotos = {};
  List<Cohete> _cohetes = const [];
  List<CajaRota> _cajas = const [];
  Set<String> _mejoras = const {};
  List<Eliminacion> _eliminaciones = const [];
  Map<String, String> _avatares = const {};

  EstadoArena? _estado;
  final Map<String, int> _invulRemoto = {};
  final Map<String, (double, double)> _visuales = {};
  final Set<String> _reclamando = {};
  final Set<String> _explosionesEscritas = {};
  final Set<String> _limpiados = {};
  int _ultimaLimpieza = 0;
  ({int x, int y, int t})? _ultimoCohete;
  (int, int, Direccion, bool, int, int, int, int)? _firma;
  bool _reentrando = false;
  bool _salido = false;
  bool _disposed = false;
  final List<StreamSubscription<Object?>> _subs = [];
  final _Repintar _cuadro = _Repintar();

  // ------------------------------------------------------------- Lectura

  FaseCohetazo get fase => _fase;
  String? get error => _error;

  /// Aviso no fatal (p. ej. una escritura falló); null si no hay.
  String? get aviso => _aviso;

  /// Jugador local (posición lógica, mejoras, vida).
  Jugador get yo => _yo;

  /// Hora del servidor estimada (ms).
  int get ahora => _reloj() + _desfase;

  bool get invulnerable => _yo.vivo && ahora < _yo.invulnerableHasta;

  /// Posición visual del jugador local (interpolada por el motor).
  (double, double) get posicionLocal =>
      _fase == FaseCohetazo.jugando ? (_motor.xVisual, _motor.yVisual) : (1, 1);

  /// Se notifica en cada cuadro; la vista de la arena se repinta con esto.
  Listenable get repintar => _cuadro;

  /// Jugadores remotos (sin el local).
  Iterable<Jugador> get remotos => _remotos.values.map(_conInvulnerabilidad);

  Map<String, String> get avatares => _avatares;

  /// Jugadores en la arena, incluido el local.
  int get enLinea => _remotos.length + (_fase == FaseCohetazo.jugando ? 1 : 0);

  /// Posición visual (celdas, decimales) de un jugador remoto.
  (double, double) posicionVisual(String id) {
    final v = _visuales[id];
    if (v != null) return v;
    final j = _remotos[id];
    return j == null ? (0, 0) : (j.x.toDouble(), j.y.toDouble());
  }

  /// Estado de la arena con los datos actuales (se recalcula solo si cambió).
  EstadoArena get estado => _estado ??= EstadoArena(
    jugadores: {for (final j in remotos) j.uid: j, uid: _yo},
    cohetes: {for (final c in _cohetes) c.id: c},
    cajasRotas: _cajas,
    mejorasReclamadas: _mejoras,
  );

  Map<String, int> get _puntos => marcador(_eliminaciones);

  int get puntaje => _puntos[uid] ?? 0;

  /// Marcador de los jugadores en línea, de mayor a menor; el propio siempre
  /// aparece.
  List<EntradaMarcador> get tablero {
    final puntos = _puntos;
    final lista =
        [
          for (final j in _remotos.values)
            EntradaMarcador(
              uid: j.uid,
              nombre: j.nombre,
              puntos: puntos[j.uid] ?? 0,
              esYo: false,
            ),
          EntradaMarcador(
            uid: uid,
            nombre: nombre,
            puntos: puntos[uid] ?? 0,
            esYo: true,
          ),
        ]..sort((a, b) {
          final c = b.puntos.compareTo(a.puntos);
          return c != 0 ? c : a.nombre.compareTo(b.nombre);
        });
    return lista;
  }

  // --------------------------------------------------------------- Inicio

  Future<void> iniciar() async {
    if (_salido || _disposed) return;
    _fase = FaseCohetazo.conectando;
    _error = null;
    _avisarCambio();
    try {
      _desfase = await _repo.desfaseServidor.first.timeout(
        const Duration(seconds: 3),
        onTimeout: () => 0,
      );
      final (px, py) = MapaArena.puntoAparicion(uid, _reapariciones);
      _yo = Jugador(
        uid: uid,
        nombre: nombre,
        x: px,
        y: py,
      ).reaparecer(ahora, (px, py));
      _motor = MotorMovimiento(x: px, y: py);
      await _repo.entrar(_yo, avatar);
    } catch (_) {
      _fase = FaseCohetazo.error;
      _error =
          'No pudimos entrar a la arena. Revisa tu conexión e inténtalo de '
          'nuevo.';
      _avisarCambio();
      return;
    }
    if (_salido || _disposed) return;
    _firma = _firmaActual;
    _suscribir();
    _fase = FaseCohetazo.jugando;
    _estado = null;
    _avisarCambio();
  }

  void _suscribir() {
    void alError(Object e) {
      _aviso = 'Perdimos la conexión con la arena. Reintentando…';
      _avisarCambio();
    }

    _subs
      ..add(_repo.desfaseServidor.listen((d) => _desfase = d, onError: alError))
      ..add(_repo.jugadores.listen(_alJugadores, onError: alError))
      ..add(
        _repo.cohetes.listen((l) {
          _cohetes = l;
          _cambioEstado();
        }, onError: alError),
      )
      ..add(
        _repo.cajas.listen((l) {
          _cajas = l;
          _cambioEstado();
        }, onError: alError),
      )
      ..add(
        _repo.mejoras.listen((s) {
          _mejoras = s;
          _cambioEstado();
        }, onError: alError),
      )
      ..add(
        _repo.eliminaciones.listen((l) {
          _eliminaciones = l;
          _avisarCambio();
        }, onError: alError),
      )
      ..add(
        _repo.avatares.listen((m) {
          _avatares = m;
          _avisarCambio();
        }, onError: alError),
      );
  }

  void _alJugadores(List<Jugador> lista) {
    final nuevos = <String, Jugador>{};
    var yoPresente = false;
    for (final j in lista) {
      if (j.uid == uid) {
        yoPresente = true;
        continue;
      }
      final previo = _remotos[j.uid];
      if (previo != null && !previo.vivo && j.vivo) {
        _invulRemoto[j.uid] = ahora + ReglasCohetazo.invulnerabilidadMs;
      }
      nuevos[j.uid] = j;
    }
    _remotos = nuevos;
    _visuales.removeWhere((id, _) => !nuevos.containsKey(id));
    _invulRemoto.removeWhere((id, _) => !nuevos.containsKey(id));
    _cambioEstado();
    // Si una caída de red disparó el onDisconnect, el nodo propio desaparece:
    // se vuelve a escribir.
    if (!yoPresente && !_reentrando && !_salido) {
      _reentrando = true;
      _repo
          .entrar(_yo, avatar)
          .catchError((Object _) {})
          .whenComplete(() => _reentrando = false);
    }
  }

  Jugador _conInvulnerabilidad(Jugador j) {
    final hasta = _invulRemoto[j.uid];
    return hasta == null ? j : j.copyWith(invulnerableHasta: hasta);
  }

  // ---------------------------------------------------------------- Entrada

  /// Dirección sostenida (null si no hay tecla).
  void sostener(Direccion? d) => _sostenida = d;

  /// Coloca un cohete en la celda actual si las reglas lo permiten.
  Future<void> colocarCohete() async {
    if (_fase != FaseCohetazo.jugando || !_yo.vivo || _salido) return;
    final ahoraS = ahora;
    if (!estado.puedeColocarCohete(_yo, ahoraS)) return;
    final u = _ultimoCohete;
    if (u != null &&
        u.x == _yo.x &&
        u.y == _yo.y &&
        _reloj() - u.t < _antirrebote) {
      return;
    }
    _ultimoCohete = (x: _yo.x, y: _yo.y, t: _reloj());
    await _seguro(
      _repo.colocarCohete(
        Cohete(
          id: '',
          uid: uid,
          x: _yo.x,
          y: _yo.y,
          alcance: _yo.alcance,
          colocado: ahoraS,
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ Bucle

  /// Avanza un cuadro de [dtSeg] segundos.
  void paso(double dtSeg) {
    if (_fase != FaseCohetazo.jugando || _salido || _disposed) return;
    final ahoraS = ahora;
    _actualizarVisuales(dtSeg);
    if (!_yo.vivo) {
      if (ahoraS >= _yo.reaparece) _reaparecer(ahoraS);
    } else {
      _mover(dtSeg, ahoraS);
      final autor = estado.autorMuerte(_yo, ahoraS);
      if (autor != null) {
        _morir(autor, ahoraS);
      } else {
        _revisarMejoras(ahoraS);
      }
    }
    _escribirCajas(ahoraS);
    _limpiar(ahoraS);
    _escribirSiCambio();
    _cuadro.repintar();
  }

  void _mover(double dtSeg, int ahoraS) {
    final est = estado;
    _motor.avanzar(
      sostenida: _sostenida,
      velocidad: _yo.velocidad,
      dtSeg: dtSeg,
      puedeMoverA: (x, y) =>
          est.puedeMoverA(_yo.copyWith(x: _motor.x, y: _motor.y), x, y, ahoraS),
    );
    if (_motor.x != _yo.x || _motor.y != _yo.y || _motor.dir != _yo.dir) {
      final cambioCelda = _motor.x != _yo.x || _motor.y != _yo.y;
      _yo = _yo.copyWith(x: _motor.x, y: _motor.y, dir: _motor.dir);
      if (cambioCelda) _estado = null;
    }
  }

  void _morir(String autor, int ahoraS) {
    _yo = _yo.alMorir(ahoraS);
    _motor.teletransportar(_yo.x, _yo.y);
    _estado = null;
    _seguro(_repo.registrarEliminacion(victima: uid, autor: autor));
    _avisarCambio();
  }

  void _reaparecer(int ahoraS) {
    _reapariciones++;
    final ocupadas = {
      for (final j in _remotos.values)
        if (j.vivo) j.celda,
    };
    final punto = _yo.puntoDeAparicion(_reapariciones, ocupadas: ocupadas);
    _yo = _yo.reaparecer(ahoraS, punto);
    _motor.teletransportar(punto.$1, punto.$2);
    _estado = null;
    _avisarCambio();
  }

  void _revisarMejoras(int ahoraS) {
    if (!estado.cajasRotas.containsKey(_yo.celda)) return;
    for (final m in estado.mejorasSueltas(ahoraS)) {
      if (m.x != _yo.x || m.y != _yo.y) continue;
      if (!_reclamando.add(m.clave)) continue;
      _repo
          .reclamarMejora(m.clave, uid)
          .then((ok) {
            if (_salido || _disposed) return;
            if (ok && _yo.vivo) {
              _yo = _yo.conMejora(m.tipo);
              _estado = null;
              _escribirSiCambio();
              _avisarCambio();
            }
          })
          .catchError((Object _) {
            // Se podrá intentar de nuevo en el siguiente cuadro.
            _reclamando.remove(m.clave);
            _avisarFallo();
          });
    }
  }

  /// Escribe las cajas que destruyeron los cohetes propios al explotar.
  void _escribirCajas(int ahoraS) {
    final est = estado;
    for (final e in est.explosiones(ahoraS)) {
      if (e.uid != uid || !_explosionesEscritas.add(e.idCohete)) continue;
      if (ahoraS - e.inicio > _ventanaCajasMs) continue;
      for (final (x, y) in e.cajasRotas) {
        final registro = est.cajasRotas[(x, y)];
        if (registro != null &&
            registro.rota >= e.inicio - ReglasCohetazo.toleranciaRotaMs) {
          continue;
        }
        _seguro(_repo.romperCaja(x, y, uid));
      }
    }
  }

  void _limpiar(int ahoraS) {
    if (ahoraS - _ultimaLimpieza < _periodoLimpiezaMs) return;
    _ultimaLimpieza = ahoraS;
    final viejos = [
      for (final c in _cohetes)
        if (ahoraS - c.colocado > ReglasCohetazo.limpiezaCoheteMs + 1000 &&
            !_limpiados.contains(c.id))
          c.id,
    ];
    if (viejos.isEmpty) return;
    _limpiados.addAll(viejos);
    _seguro(_repo.limpiarCohetesViejos(viejos));
  }

  (int, int, Direccion, bool, int, int, int, int) get _firmaActual => (
    _yo.x,
    _yo.y,
    _yo.dir,
    _yo.vivo,
    _yo.alcance,
    _yo.cohetes,
    _yo.velocidad,
    _yo.reaparece,
  );

  /// Escribe el jugador solo si cambió la celda, la dirección, la vida o las
  /// mejoras (no una vez por cuadro).
  void _escribirSiCambio() {
    final f = _firmaActual;
    if (f == _firma) return;
    _firma = f;
    _seguro(_repo.actualizarJugador(_yo));
  }

  void _actualizarVisuales(double dtSeg) {
    for (final j in _remotos.values) {
      final (tx, ty) = (j.x.toDouble(), j.y.toDouble());
      final actual = _visuales[j.uid];
      if (actual == null) {
        _visuales[j.uid] = (tx, ty);
        continue;
      }
      final (vx, vy) = actual;
      final dx = tx - vx;
      final dy = ty - vy;
      final largo = math.sqrt(dx * dx + dy * dy);
      if (largo < 1e-6) continue;
      final paso =
          (ReglasCohetazo.celdasPorSegundo(j.velocidad) +
              _velocidadRemotoExtra) *
          dtSeg;
      _visuales[j.uid] = largo <= paso || largo > 3
          ? (tx, ty)
          : (vx + dx / largo * paso, vy + dy / largo * paso);
    }
  }

  // --------------------------------------------------------------- Utilidad

  Future<void> _seguro<T>(Future<T> f) async {
    try {
      await f;
    } catch (_) {
      _avisarFallo();
    }
  }

  void _avisarFallo() {
    _aviso = 'No se pudo guardar un cambio. Revisa tu conexión.';
    _avisarCambio();
  }

  void limpiarAviso() {
    if (_aviso == null) return;
    _aviso = null;
    _avisarCambio();
  }

  void _cambioEstado() {
    _estado = null;
    _avisarCambio();
  }

  void _avisarCambio() {
    if (!_disposed) notifyListeners();
  }

  /// Sale de la arena: borra el nodo del jugador.
  Future<void> salir() async {
    if (_salido) return;
    _salido = true;
    _cancelar();
    try {
      await _repo.salir(uid);
    } catch (_) {
      // El onDisconnect lo limpiará al cerrar la conexión.
    }
  }

  void _cancelar() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }

  @override
  void dispose() {
    if (!_salido && _fase == FaseCohetazo.jugando) {
      _salido = true;
      unawaited(_repo.salir(uid).catchError((Object _) {}));
    }
    _salido = true;
    _disposed = true;
    _cancelar();
    _cuadro.dispose();
    super.dispose();
  }
}
