import '../juego/mapa_arena.dart';
import '../juego/reglas_cohetazo.dart';
import 'direccion.dart';
import 'tipo_mejora.dart';
import 'utiles.dart';

/// Jugador en la arena (`/cohetazo/jugadores/{uid}`).
class Jugador {
  const Jugador({
    required this.uid,
    required this.nombre,
    required this.x,
    required this.y,
    this.dir = Direccion.abajo,
    this.vivo = true,
    this.reaparece = 0,
    this.alcance = ReglasCohetazo.alcanceBase,
    this.cohetes = ReglasCohetazo.cohetesBase,
    this.velocidad = ReglasCohetazo.velocidadBase,
    this.t,
    this.invulnerableHasta = 0,
  });

  factory Jugador.fromMap(String uid, Map<Object?, Object?> m) => Jugador(
    uid: uid,
    nombre: leerTexto(m['nombre']),
    x: leerEntero(m['x']),
    y: leerEntero(m['y']),
    dir: Direccion.desdeClave(m['dir']),
    vivo: m['vivo'] != false,
    reaparece: leerEntero(m['reaparece']),
    alcance: leerEntero(m['alcance'], ReglasCohetazo.alcanceBase),
    cohetes: leerEntero(m['cohetes'], ReglasCohetazo.cohetesBase),
    velocidad: leerEntero(m['velocidad'], ReglasCohetazo.velocidadBase),
    t: m['t'] is num ? (m['t'] as num).toInt() : null,
  );

  final String uid;
  final String nombre;
  final int x;
  final int y;
  final Direccion dir;
  final bool vivo;

  /// Momento (ms, servidor) en que reaparece; 0 si está vivo.
  final int reaparece;
  final int alcance;
  final int cohetes;
  final int velocidad;

  /// Última escritura (timestamp del servidor), si se conoce.
  final int? t;

  /// Solo local, no se guarda: instante hasta el que no puede morir.
  final int invulnerableHasta;

  (int, int) get celda => (x, y);

  /// Mapa para RTDB. [marcaTiempo] reemplaza `t` (p. ej. `ServerValue.timestamp`).
  Map<String, Object?> toMap({Object? marcaTiempo}) => {
    'nombre': nombre,
    'x': x,
    'y': y,
    'dir': dir.clave,
    'vivo': vivo,
    'reaparece': reaparece,
    'alcance': alcance,
    'cohetes': cohetes,
    'velocidad': velocidad,
    't': marcaTiempo ?? t ?? 0,
  };

  Jugador copyWith({
    String? nombre,
    int? x,
    int? y,
    Direccion? dir,
    bool? vivo,
    int? reaparece,
    int? alcance,
    int? cohetes,
    int? velocidad,
    int? t,
    int? invulnerableHasta,
  }) => Jugador(
    uid: uid,
    nombre: nombre ?? this.nombre,
    x: x ?? this.x,
    y: y ?? this.y,
    dir: dir ?? this.dir,
    vivo: vivo ?? this.vivo,
    reaparece: reaparece ?? this.reaparece,
    alcance: alcance ?? this.alcance,
    cohetes: cohetes ?? this.cohetes,
    velocidad: velocidad ?? this.velocidad,
    t: t ?? this.t,
    invulnerableHasta: invulnerableHasta ?? this.invulnerableHasta,
  );

  /// Aplica una mejora respetando los topes.
  Jugador conMejora(TipoMejora tipo) => switch (tipo) {
    TipoMejora.alcance => copyWith(
      alcance: alcance < tipo.maximo ? alcance + 1 : tipo.maximo,
    ),
    TipoMejora.cohetes => copyWith(
      cohetes: cohetes < tipo.maximo ? cohetes + 1 : tipo.maximo,
    ),
    TipoMejora.velocidad => copyWith(
      velocidad: velocidad < tipo.maximo ? velocidad + 1 : tipo.maximo,
    ),
  };

  /// Muerte: se pierden las mejoras y reaparece a los 3000 ms.
  Jugador alMorir(int ahora) => copyWith(
    vivo: false,
    reaparece: ahora + ReglasCohetazo.reaparicionMs,
    alcance: ReglasCohetazo.alcanceBase,
    cohetes: ReglasCohetazo.cohetesBase,
    velocidad: ReglasCohetazo.velocidadBase,
  );

  /// Reaparición en [punto] con 1500 ms de invulnerabilidad.
  Jugador reaparecer(int ahora, (int, int) punto) => copyWith(
    vivo: true,
    reaparece: 0,
    x: punto.$1,
    y: punto.$2,
    invulnerableHasta: ahora + ReglasCohetazo.invulnerabilidadMs,
  );

  /// Primer punto de aparición para este jugador (reaparición número [n]).
  (int, int) puntoDeAparicion(int n, {Set<(int, int)> ocupadas = const {}}) =>
      MapaArena.puntoAparicion(uid, n, ocupadas: ocupadas);
}
