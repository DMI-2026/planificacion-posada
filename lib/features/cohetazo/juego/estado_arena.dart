import '../models/caja_rota.dart';
import '../models/cohete.dart';
import '../models/direccion.dart';
import '../models/jugador.dart';
import 'explosion.dart';
import 'mapa_arena.dart';
import 'reglas_cohetazo.dart';

export 'explosion.dart';
export 'marcador.dart';

/// Instantánea de la arena y reglas puras sobre ella. Todos los métodos
/// reciben `ahora` (hora del servidor en ms) y son deterministas: los mismos
/// datos dan el mismo resultado en todos los clientes.
class EstadoArena {
  EstadoArena({
    Map<String, Jugador> jugadores = const {},
    Map<String, Cohete> cohetes = const {},
    Iterable<CajaRota> cajasRotas = const [],
    Set<String> mejorasReclamadas = const {},
  }) : jugadores = Map.unmodifiable(jugadores),
       cohetes = Map.unmodifiable({for (final c in cohetes.values) c.id: c}),
       cajasRotas = {for (final c in cajasRotas) (c.x, c.y): c},
       mejorasReclamadas = Set.unmodifiable(mejorasReclamadas);

  /// Por uid.
  final Map<String, Jugador> jugadores;

  /// Por id.
  final Map<String, Cohete> cohetes;

  /// Registros de `/cohetazo/cajas`, por celda.
  final Map<Celda, CajaRota> cajasRotas;

  /// Claves `x_y_rota` ya reclamadas en `/cohetazo/mejoras`.
  final Set<String> mejorasReclamadas;

  late final List<Explosion> _todas = _resolver();

  // ---------------------------------------------------------------- Cajas

  /// Instante de la última rotura conocida de la caja (registro o explosión
  /// calculada ya ocurrida), o null si nunca se rompió.
  int? _rotaEfectiva(int x, int y, int ahora) {
    var rota = cajasRotas[(x, y)]?.rota;
    for (final e in _todas) {
      if (e.inicio > ahora) break;
      if (e.cajasRotas.contains((x, y)) && (rota == null || e.inicio > rota)) {
        rota = e.inicio;
      }
    }
    return rota;
  }

  /// Si hay una caja de regalo en la celda: caja inicial no rota, o que ya
  /// rebrotó (30 s tras `rota`, esperando mientras un jugador vivo o un
  /// cohete ocupe la celda).
  bool cajaPresente(int x, int y, int ahora) {
    if (!MapaArena.hayCajaInicial(x, y)) return false;
    final rota = _rotaEfectiva(x, y, ahora);
    if (rota == null) return true;
    if (ahora < rota + ReglasCohetazo.rebroteCajaMs) return false;
    return !_ocupada(x, y, ahora);
  }

  bool _ocupada(int x, int y, int ahora) {
    for (final j in jugadores.values) {
      if (j.vivo && j.x == x && j.y == y) return true;
    }
    return cohetesActivos(ahora).any((c) => c.x == x && c.y == y);
  }

  /// Mejoras en el suelo: cajas rotas que suelten una, sin reclamar y cuya
  /// caja aún no ha rebrotado.
  List<MejoraSuelta> mejorasSueltas(int ahora) {
    final lista = <MejoraSuelta>[];
    for (final c in cajasRotas.values) {
      if (c.rota > ahora) continue;
      final tipo = MapaArena.mejoraEn(c.x, c.y, c.rota);
      if (tipo == null) continue;
      final clave = c.claveDeMejora;
      if (mejorasReclamadas.contains(clave)) continue;
      if (cajaPresente(c.x, c.y, ahora)) continue;
      lista.add(
        MejoraSuelta(x: c.x, y: c.y, rota: c.rota, tipo: tipo, clave: clave),
      );
    }
    return lista;
  }

  // ------------------------------------------------------------ Explosiones

  /// Cohetes que aún no han explotado en [ahora].
  List<Cohete> cohetesActivos(int ahora) {
    final explotados = {
      for (final e in _todas)
        if (e.inicio <= ahora) e.idCohete,
    };
    return [
      for (final c in cohetes.values)
        if (!explotados.contains(c.id)) c,
    ];
  }

  /// Explosiones ya ocurridas en [ahora] (incluidas las ya apagadas), en
  /// orden cronológico.
  List<Explosion> explosiones(int ahora) => [
    for (final e in _todas)
      if (e.inicio <= ahora) e,
  ];

  /// Celdas en llamas en [ahora], con el responsable de cada una.
  List<FuegoCelda> celdasEnFuego(int ahora) => [
    for (final e in _todas)
      if (e.inicio <= ahora && ahora < e.fin) ...e.fuego,
  ];

  /// Resuelve todos los cohetes, con reacciones en cadena.
  ///
  /// Un cohete alcanzado por fuego explota en `max(inicio del fuego,
  /// colocado)` si eso ocurre mientras el fuego sigue activo. Una caja
  /// detiene el fuego salvo que ya esté rota: por una explosión anterior de
  /// esta resolución, o por un registro de `cajas` anterior a la explosión en
  /// más de `toleranciaRotaMs` (los registros recientes se ignoran: pueden ser
  /// la escritura de la propia explosión que se está recalculando).
  List<Explosion> _resolver() {
    final efectivo = <String, int>{
      for (final c in cohetes.values)
        c.id: c.colocado + ReglasCohetazo.explosionMs,
    };
    final pendientes = cohetes.keys.toSet();
    final rotasSim = <Celda, int>{};
    final resultado = <Explosion>[];

    bool hayCaja(int x, int y, int t) {
      if (!MapaArena.hayCajaInicial(x, y)) return false;
      final sim = rotasSim[(x, y)];
      if (sim != null && sim < t) return false;
      final db = cajasRotas[(x, y)]?.rota;
      if (db != null &&
          db < t - ReglasCohetazo.toleranciaRotaMs &&
          t < db + ReglasCohetazo.rebroteCajaMs) {
        return false;
      }
      return true;
    }

    while (pendientes.isNotEmpty) {
      String? id;
      for (final k in pendientes) {
        if (id == null ||
            efectivo[k]! < efectivo[id]! ||
            (efectivo[k] == efectivo[id] && k.compareTo(id) < 0)) {
          id = k;
        }
      }
      pendientes.remove(id);
      final c = cohetes[id]!;
      final t = efectivo[id]!;

      final celdas = <Celda>[(c.x, c.y)];
      final rotas = <Celda>[];
      for (final d in Direccion.values) {
        for (var i = 1; i <= c.alcance; i++) {
          final cx = c.x + d.dx * i;
          final cy = c.y + d.dy * i;
          if (MapaArena.esMuro(cx, cy)) break;
          celdas.add((cx, cy));
          if (hayCaja(cx, cy, t)) {
            rotas.add((cx, cy));
            break;
          }
        }
      }
      for (final r in rotas) {
        rotasSim[r] = t;
      }
      final fin = t + ReglasCohetazo.fuegoMs;
      resultado.add(
        Explosion(
          idCohete: c.id,
          uid: c.uid,
          x: c.x,
          y: c.y,
          inicio: t,
          fin: fin,
          celdas: celdas,
          cajasRotas: rotas,
        ),
      );

      final enFuego = celdas.toSet();
      for (final otro in pendientes) {
        final o = cohetes[otro]!;
        if (!enFuego.contains((o.x, o.y))) continue;
        final disparo = o.colocado > t ? o.colocado : t;
        if (disparo < fin && disparo < efectivo[otro]!) {
          efectivo[otro] = disparo;
        }
      }
    }
    return resultado;
  }

  // ------------------------------------------------------------ Movimiento

  /// Si [j] puede entrar a (x, y) en [ahora]: sin muros, cajas ni cohetes,
  /// salvo el cohete de la celda donde ya está de pie.
  bool puedeMoverA(Jugador j, int x, int y, int ahora) {
    if (MapaArena.esMuro(x, y)) return false;
    if (cajaPresente(x, y, ahora)) return false;
    if (x == j.x && y == j.y) return true;
    return !cohetesActivos(ahora).any((c) => c.x == x && c.y == y);
  }

  /// Si [j] puede colocar un cohete en su celda: tiene cohetes disponibles y
  /// no hay otro cohete allí.
  bool puedeColocarCohete(Jugador j, int ahora) {
    if (!j.vivo) return false;
    final activos = cohetesActivos(ahora);
    if (activos.any((c) => c.x == j.x && c.y == j.y)) return false;
    return activos.where((c) => c.uid == j.uid).length < j.cohetes;
  }

  // ----------------------------------------------------------------- Muerte

  /// Uid del dueño del fuego que alcanza a [j] en [ahora], o null si no muere
  /// (fuera del fuego, muerto o invulnerable).
  String? autorMuerte(Jugador j, int ahora) {
    if (!j.vivo || ahora < j.invulnerableHasta) return null;
    for (final f in celdasEnFuego(ahora)) {
      if (f.x == j.x && f.y == j.y) return f.uid;
    }
    return null;
  }

  bool muereEn(Jugador j, int ahora) => autorMuerte(j, ahora) != null;
}
