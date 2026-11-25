import 'package:flutter_test/flutter_test.dart';
import 'package:planificacion_posada/features/cohetazo/juego/estado_arena.dart';
import 'package:planificacion_posada/features/cohetazo/juego/mapa_arena.dart';
import 'package:planificacion_posada/features/cohetazo/juego/motor_movimiento.dart';
import 'package:planificacion_posada/features/cohetazo/juego/reglas_cohetazo.dart';
import 'package:planificacion_posada/features/cohetazo/models/caja_rota.dart';
import 'package:planificacion_posada/features/cohetazo/models/cohete.dart';
import 'package:planificacion_posada/features/cohetazo/models/direccion.dart';
import 'package:planificacion_posada/features/cohetazo/models/eliminacion.dart';
import 'package:planificacion_posada/features/cohetazo/models/jugador.dart';
import 'package:planificacion_posada/features/cohetazo/models/tipo_mejora.dart';

Jugador jug(String uid, int x, int y, {int invulnerableHasta = 0}) => Jugador(
  uid: uid,
  nombre: uid,
  x: x,
  y: y,
  invulnerableHasta: invulnerableHasta,
);

Cohete coh(
  String id,
  String uid,
  int x,
  int y,
  int colocado, {
  int alcance = 2,
}) =>
    Cohete(id: id, uid: uid, x: x, y: y, alcance: alcance, colocado: colocado);

/// Todas las cajas iniciales rotas hace 10 s respecto a [ahora]: la arena queda
/// sin cajas durante 20 s más.
List<CajaRota> sinCajas(int ahora) => [
  for (var y = 0; y < ReglasCohetazo.filas; y++)
    for (var x = 0; x < ReglasCohetazo.columnas; x++)
      if (MapaArena.hayCajaInicial(x, y))
        CajaRota(x: x, y: y, rota: ahora - 10000, por: 'z'),
];

Set<(int, int)> celdas(Iterable<FuegoCelda> f) => {
  for (final c in f) (c.x, c.y),
};

void main() {
  group('MapaArena', () {
    test('muros: borde y celdas con x e y pares', () {
      expect(MapaArena.esMuro(0, 5), isTrue);
      expect(MapaArena.esMuro(20, 5), isTrue);
      expect(MapaArena.esMuro(5, 0), isTrue);
      expect(MapaArena.esMuro(5, 16), isTrue);
      expect(MapaArena.esMuro(2, 2), isTrue);
      expect(MapaArena.esMuro(18, 14), isTrue);
      expect(MapaArena.esMuro(2, 1), isFalse);
      expect(MapaArena.esMuro(1, 2), isFalse);
      expect(MapaArena.esMuro(1, 1), isFalse);
      expect(MapaArena.esMuro(-1, 3), isTrue, reason: 'fuera es muro');
      expect(MapaArena.esMuro(21, 3), isTrue);
    });

    test('cajas iniciales deterministas y sin cajas en muros', () {
      final a = [
        for (var y = 0; y < 17; y++)
          for (var x = 0; x < 21; x++) MapaArena.hayCajaInicial(x, y),
      ];
      final b = [
        for (var y = 0; y < 17; y++)
          for (var x = 0; x < 21; x++) MapaArena.hayCajaInicial(x, y),
      ];
      expect(a, b);
      for (var y = 0; y < 17; y++) {
        for (var x = 0; x < 21; x++) {
          if (MapaArena.esMuro(x, y)) {
            expect(MapaArena.hayCajaInicial(x, y), isFalse);
          }
        }
      }
      final n = a.where((c) => c).length;
      // 55 % de ~ 230 celdas libres, con margen.
      expect(n, inInclusiveRange(80, 170));
    });

    test('valores fijos del hash (detecta cambios del algoritmo)', () {
      expect(MapaArena.hash([1, 2, 3]), 2962531615);
      // Valores por encima de 32 bits (timestamps) también están fijados.
      expect(MapaArena.hash([4294967296 + 5, 0]), 904826353);
    });

    test('mapa de cajas fijado (huella)', () {
      final filas = [
        for (var y = 0; y < 17; y++)
          [
            for (var x = 0; x < 21; x++)
              MapaArena.esMuro(x, y)
                  ? '#'
                  : MapaArena.hayCajaInicial(x, y)
                  ? 'c'
                  : '.',
          ].join(),
      ];
      expect(
        filas.join('\n'),
        [
          '#####################',
          '#..c...c....c....c..#',
          '#.#c#.#.#.#c#c#.#.#.#',
          '#c...cc.ccc...c...c.#',
          '#c#.#c#.#.#c#.#c#c#.#',
          '#.c.ccc.cc..ccccc...#',
          '#.#c#c#c#c#c#c#.#c#.#',
          '#..c.c.c..cccc......#',
          '#.#c#.#c#c#.#.#.#.#.#',
          '#..cc.cccc.cccc.cc..#',
          '#.#.#.#c#.#.#.#c#c#.#',
          '#cc.ccc.c..cc.c..cc.#',
          '#.#c#c#.#.#.#.#.#c#.#',
          '#..cc.ccc..cc.ccccc.#',
          '#.#c#.#c#.#c#c#.#c#.#',
          '#..c...cc.cc.c......#',
          '#####################',
        ].join('\n'),
      );
    });

    test('12 puntos de aparición simétricos, libres y con vecinas libres', () {
      final p = MapaArena.puntosAparicion;
      expect(p.length, 12);
      expect(p.toSet().length, 12);
      for (final c in [(1, 1), (19, 1), (1, 15), (19, 15)]) {
        expect(p, contains(c));
      }
      final set = p.toSet();
      for (final (x, y) in p) {
        expect(set, contains((20 - x, y)));
        expect(set, contains((x, 16 - y)));
        expect(x.isOdd && y.isOdd, isTrue);
        for (final (dx, dy) in [(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)]) {
          final nx = x + dx, ny = y + dy;
          if (!MapaArena.esMuro(nx, ny)) {
            expect(
              MapaArena.hayCajaInicial(nx, ny),
              isFalse,
              reason: 'caja en ($nx,$ny)',
            );
          }
        }
      }
    });

    test('punto de aparición por hash de uid y reapariciones', () {
      final a = MapaArena.puntoAparicion('uid-ana', 0);
      expect(MapaArena.puntoAparicion('uid-ana', 0), a);
      expect(MapaArena.puntosAparicion, contains(a));
      final distintos = {
        for (var n = 0; n < 40; n++) MapaArena.puntoAparicion('uid-ana', n),
      };
      expect(distintos.length, greaterThan(3));
      final ocupadas = {a};
      final b = MapaArena.puntoAparicion('uid-ana', 0, ocupadas: ocupadas);
      expect(b, isNot(a));
      expect(MapaArena.puntosAparicion, contains(b));
    });

    test('mejoraEn: determinista, ~30 %, valores fijados', () {
      expect(
        MapaArena.mejoraEn(3, 3, 1700000000000),
        MapaArena.mejoraEn(3, 3, 1700000000000),
      );
      var con = 0;
      final tipos = <TipoMejora>{};
      for (var i = 0; i < 2000; i++) {
        final m = MapaArena.mejoraEn(3 + i % 10, 5, 1700000000000 + i * 7919);
        if (m != null) {
          con++;
          tipos.add(m);
        }
      }
      expect(con, inInclusiveRange(520, 680));
      expect(tipos, TipoMejora.values.toSet());
      expect(
        [
          for (var i = 0; i < 12; i++)
            MapaArena.mejoraEn(3, 3, 1700000000000 + i)?.name ?? '-',
        ].join(','),
        '-,-,-,-,alcance,-,-,alcance,velocidad,-,cohetes,alcance',
      );
    });
  });

  group('Jugador y mejoras', () {
    test('valores base y topes', () {
      var j = jug('a', 1, 1);
      expect((j.alcance, j.cohetes, j.velocidad), (2, 1, 0));
      for (var i = 0; i < 20; i++) {
        j = j
            .conMejora(TipoMejora.alcance)
            .conMejora(TipoMejora.cohetes)
            .conMejora(TipoMejora.velocidad);
      }
      expect((j.alcance, j.cohetes, j.velocidad), (6, 5, 3));
    });

    test('al morir se pierden las mejoras y reaparece a los 3000 ms', () {
      final j = jug('a', 4, 5).conMejora(TipoMejora.alcance).alMorir(10000);
      expect(j.vivo, isFalse);
      expect(j.reaparece, 13000);
      expect((j.alcance, j.cohetes, j.velocidad), (2, 1, 0));
      final r = j.reaparecer(13000, (1, 1));
      expect(r.vivo, isTrue);
      expect(r.reaparece, 0);
      expect((r.x, r.y), (1, 1));
      expect(r.invulnerableHasta, 14500);
    });

    test('fromMap/toMap siguen el esquema', () {
      final j = Jugador.fromMap('u1', {
        'nombre': 'Ana',
        'x': 3,
        'y': 5.0,
        'dir': 'izquierda',
        'vivo': true,
        'reaparece': 0,
        'alcance': 3,
        'cohetes': 2,
        'velocidad': 1,
        't': 99,
      });
      expect(j.dir, Direccion.izquierda);
      expect(j.y, 5);
      expect(j.toMap(), {
        'nombre': 'Ana',
        'x': 3,
        'y': 5,
        'dir': 'izquierda',
        'vivo': true,
        'reaparece': 0,
        'alcance': 3,
        'cohetes': 2,
        'velocidad': 1,
        't': 99,
      });
      expect(j.toMap(marcaTiempo: 'SRV')['t'], 'SRV');
    });

    test('cohete, caja rota y eliminación: fromMap/toMap', () {
      final c = Cohete.fromMap('k', {
        'uid': 'u',
        'x': 1,
        'y': 3,
        'alcance': 4,
        'colocado': 1000,
      });
      expect(c.toMap(), {
        'uid': 'u',
        'x': 1,
        'y': 3,
        'alcance': 4,
        'colocado': 1000,
      });
      final b = CajaRota.fromMap('5_7', {'rota': 55, 'por': 'u'});
      expect((b.x, b.y, b.rota), (5, 7, 55));
      expect(b.clave, '5_7');
      expect(b.toMap(), {'rota': 55, 'por': 'u'});
      expect(CajaRota.claveMejora(5, 7, 55), '5_7_55');
      final e = Eliminacion.fromMap({'victima': 'v', 'autor': 'a', 't': 9});
      expect(e.toMap(), {'victima': 'v', 'autor': 'a', 't': 9});
    });
  });

  group('Cajas: rebrote', () {
    // Primera caja inicial.
    late int bx, by;
    setUp(() {
      outer:
      for (var y = 1; y < 16; y++) {
        for (var x = 1; x < 20; x++) {
          if (MapaArena.hayCajaInicial(x, y)) {
            bx = x;
            by = y;
            break outer;
          }
        }
      }
    });

    test('presente si no está rota; vuelve a los 30 s', () {
      final s = EstadoArena(
        cajasRotas: [CajaRota(x: bx, y: by, rota: 1000, por: 'u')],
      );
      expect(EstadoArena().cajaPresente(bx, by, 5), isTrue);
      expect(s.cajaPresente(bx, by, 1000), isFalse);
      expect(s.cajaPresente(bx, by, 30999), isFalse);
      expect(s.cajaPresente(bx, by, 31000), isTrue);
    });

    test('espera si un jugador o cohete ocupa la celda', () {
      final cajas = [CajaRota(x: bx, y: by, rota: 1000, por: 'u')];
      final conJugador = EstadoArena(
        cajasRotas: cajas,
        jugadores: {'p': jug('p', bx, by)},
      );
      expect(conJugador.cajaPresente(bx, by, 40000), isFalse);
      final sinJugador = EstadoArena(cajasRotas: cajas);
      expect(sinJugador.cajaPresente(bx, by, 40000), isTrue);
      final conCohete = EstadoArena(
        cajasRotas: cajas,
        cohetes: {'c': coh('c', 'p', bx, by, 39000)},
      );
      expect(conCohete.cajaPresente(bx, by, 40000), isFalse);
      // Tras explotar, queda libre.
      expect(conCohete.cajaPresente(bx, by, 42000), isTrue);
    });

    test('no hay caja donde nunca hubo', () {
      expect(EstadoArena().cajaPresente(2, 2, 0), isFalse);
      expect(EstadoArena().cajaPresente(1, 1, 0), isFalse);
    });
  });

  group('Explosiones', () {
    const t0 = 100000;

    test('explota a los 2500 ms; fuego 600 ms; alcance en 4 direcciones', () {
      final s = EstadoArena(
        cajasRotas: sinCajas(t0),
        cohetes: {'a': coh('a', 'u', 3, 3, t0)},
      ); // (3,3) alcance 2
      expect(s.explosiones(t0 + 2499), isEmpty);
      expect(s.celdasEnFuego(t0 + 2499), isEmpty);
      final e = s.explosiones(t0 + 2500);
      expect(e.length, 1);
      expect(e.first.inicio, t0 + 2500);
      expect(e.first.fin, t0 + 3100);
      expect(e.first.uid, 'u');
      // (3,3): (3,2),(3,1) arriba; (3,4),(3,5) abajo; (2,3),(1,3); (4,3),(5,3)
      expect(celdas(s.celdasEnFuego(t0 + 2500)), {
        (3, 3),
        (3, 2),
        (3, 1),
        (3, 4),
        (3, 5),
        (2, 3),
        (1, 3),
        (4, 3),
        (5, 3),
      });
      expect(s.celdasEnFuego(t0 + 3099), isNotEmpty);
      expect(s.celdasEnFuego(t0 + 3100), isEmpty);
    });

    test('se detiene en muros', () {
      final s = EstadoArena(
        cajasRotas: sinCajas(t0),
        cohetes: {'a': coh('a', 'u', 1, 2, t0, alcance: 5)},
      );
      // (1,2): derecha (2,2) es muro; arriba (1,1) y borde; abajo hasta (1,7)
      expect(celdas(s.celdasEnFuego(t0 + 2500)), {
        (1, 2),
        (1, 1),
        (1, 3),
        (1, 4),
        (1, 5),
        (1, 6),
        (1, 7),
      });
    });

    test(
      'se detiene en la primera caja y la destruye; no pasa a la siguiente',
      () {
        // Primera caja en la fila 1 con la vecina izquierda libre de caja.
        int? bx;
        for (var x = 3; x < 19; x++) {
          if (MapaArena.hayCajaInicial(x, 1) &&
              !MapaArena.hayCajaInicial(x - 1, 1)) {
            bx = x;
            break;
          }
        }
        expect(bx, isNotNull);
        final s = EstadoArena(
          cohetes: {'a': coh('a', 'u', bx! - 1, 1, t0, alcance: 4)},
        );
        final e = s.explosiones(t0 + 2500).single;
        expect(e.cajasRotas, contains((bx, 1)));
        final f = celdas(s.celdasEnFuego(t0 + 2500));
        expect(f, contains((bx, 1)));
        expect(f, isNot(contains((bx + 1, 1))));
        // Mientras no se escriba en la base, la caja ya cuenta como rota.
        expect(s.cajaPresente(bx, 1, t0 + 2500), isFalse);
        expect(s.cajaPresente(bx, 1, t0 + 2499), isTrue);
      },
    );

    test('el fuego atraviesa jugadores y mata', () {
      final s = EstadoArena(
        cajasRotas: sinCajas(t0),
        cohetes: {'a': coh('a', 'u', 3, 3, t0)},
        jugadores: {'v': jug('v', 3, 2), 'w': jug('w', 3, 1)},
      );
      expect(s.muereEn(s.jugadores['v']!, t0 + 2499), isFalse);
      expect(s.muereEn(s.jugadores['v']!, t0 + 2600), isTrue);
      expect(
        s.muereEn(s.jugadores['w']!, t0 + 2600),
        isTrue,
        reason: 'atraviesa a v',
      );
      expect(s.autorMuerte(s.jugadores['w']!, t0 + 2600), 'u');
      expect(s.muereEn(s.jugadores['v']!, t0 + 3100), isFalse);
    });

    test('reacción en cadena', () {
      final s = EstadoArena(
        cajasRotas: sinCajas(t0),
        cohetes: {
          'a': coh('a', 'u1', 1, 1, t0),
          'b': coh('b', 'u2', 3, 1, t0 + 1000),
          'c': coh('c', 'u3', 3, 3, t0 + 1500),
          'lejos': coh('lejos', 'u4', 19, 15, t0 + 1000),
        },
      );
      final e = s.explosiones(t0 + 2500);
      final por = {for (final x in e) x.idCohete: x.inicio};
      expect(por, {'a': t0 + 2500, 'b': t0 + 2500, 'c': t0 + 2500});
      expect(
        s.explosiones(t0 + 3499).map((x) => x.idCohete),
        isNot(contains('lejos')),
      );
      expect(
        s.explosiones(t0 + 3500).map((x) => x.idCohete),
        contains('lejos'),
      );
      // Cada fuego recuerda al dueño de su cohete.
      final fuegoC = s
          .celdasEnFuego(t0 + 2600)
          .where((f) => f.idCohete == 'c')
          .map((f) => f.uid)
          .toSet();
      expect(fuegoC, {'u3'});
    });

    test('un cohete colocado tras apagarse el fuego no se enciende', () {
      final s = EstadoArena(
        cajasRotas: sinCajas(t0),
        cohetes: {
          'a': coh('a', 'u', 1, 1, t0),
          'd': coh('d', 'u', 1, 3, t0 + 3100),
          'e': coh('e', 'u', 3, 1 + 0, t0 + 2900), // dentro del fuego
        },
      );
      final por = {
        for (final x in s.explosiones(t0 + 9000)) x.idCohete: x.inicio,
      };
      expect(por['d'], t0 + 3100 + 2500);
      expect(por['e'], t0 + 2900, reason: 'colocado dentro del fuego');
    });

    test('cohetes activos y bloqueo del fuego por cajas intactas (cadena)', () {
      final s = EstadoArena(cohetes: {'a': coh('a', 'u', 3, 3, t0)});
      expect(s.cohetesActivos(t0 + 2499).map((c) => c.id), ['a']);
      expect(s.cohetesActivos(t0 + 2500), isEmpty);
    });
  });

  group('Movimiento', () {
    test('puedeMoverA: muros, cajas, cohetes', () {
      int bx = 0, by = 0;
      outer:
      for (var y = 1; y < 16; y++) {
        for (var x = 1; x < 20; x++) {
          if (MapaArena.hayCajaInicial(x, y)) {
            bx = x;
            by = y;
            break outer;
          }
        }
      }
      final p = jug('p', 1, 1);
      final s = EstadoArena(
        cohetes: {
          'c': coh('c', 'x', 2, 1, 0),
          'propio': coh('p', 'p', 1, 1, 0),
        },
        jugadores: {'p': p},
      );
      expect(s.puedeMoverA(p, 1, 2, 10), isTrue);
      expect(s.puedeMoverA(p, 0, 1, 10), isFalse, reason: 'borde');
      expect(s.puedeMoverA(p, 2, 2, 10), isFalse, reason: 'muro');
      expect(s.puedeMoverA(p, 2, 1, 10), isFalse, reason: 'cohete ajeno');
      expect(
        s.puedeMoverA(p, 1, 1, 10),
        isTrue,
        reason: 'cohete en la celda donde está de pie',
      );
      expect(s.puedeMoverA(p, bx, by, 10), isFalse, reason: 'caja');
      // Tras explotar el cohete la celda se libera.
      expect(s.puedeMoverA(p, 2, 1, 3000), isTrue);
    });

    test('puedeColocarCohete respeta el máximo simultáneo y la celda', () {
      final p = jug('p', 1, 1);
      var s = EstadoArena(jugadores: {'p': p});
      expect(s.puedeColocarCohete(p, 10), isTrue);
      s = EstadoArena(
        jugadores: {'p': p},
        cohetes: {'a': coh('a', 'p', 3, 3, 0)},
      );
      expect(s.puedeColocarCohete(p, 10), isFalse);
      expect(s.puedeColocarCohete(p.conMejora(TipoMejora.cohetes), 10), isTrue);
      s = EstadoArena(
        jugadores: {'p': p},
        cohetes: {'a': coh('a', 'otro', 1, 1, 0)},
      );
      expect(
        s.puedeColocarCohete(p.conMejora(TipoMejora.cohetes), 10),
        isFalse,
        reason: 'ya hay un cohete en la celda',
      );
    });

    test('velocidad: 4 + nivel celdas por segundo', () {
      expect(ReglasCohetazo.celdasPorSegundo(0), 4);
      expect(ReglasCohetazo.celdasPorSegundo(3), 7);
      final m = MotorMovimiento(x: 1, y: 1);
      final pasos = m.avanzar(
        sostenida: Direccion.abajo,
        velocidad: 0,
        dtSeg: 1.0,
        puedeMoverA: (x, y) => y <= 6,
      );
      expect(pasos.length, 4);
      expect((m.x, m.y), (1, 5));
      final m3 = MotorMovimiento(x: 1, y: 1);
      final p3 = m3.avanzar(
        sostenida: Direccion.abajo,
        velocidad: 3,
        dtSeg: 1.0,
        puedeMoverA: (x, y) => true,
      );
      expect(p3.length, 7);
      expect(m3.y, 8);
    });

    test('movimiento parcial se acumula entre cuadros', () {
      final m = MotorMovimiento(x: 1, y: 1);
      bool libre(int x, int y) => true;
      var total = 0;
      for (var i = 0; i < 5; i++) {
        total += m
            .avanzar(
              sostenida: Direccion.derecha,
              velocidad: 0,
              dtSeg: 0.125,
              puedeMoverA: libre,
            )
            .length;
      }
      // 5 * 0.125 * 4 = 2.5 celdas
      expect(total, 2);
      expect(m.x, 3);
      expect(m.xVisual, closeTo(3.5, 1e-9));
    });

    test('bloqueado: no avanza, pero cambia de dirección', () {
      final m = MotorMovimiento(x: 1, y: 1);
      final pasos = m.avanzar(
        sostenida: Direccion.izquierda,
        velocidad: 0,
        dtSeg: 1,
        puedeMoverA: (x, y) => false,
      );
      expect(pasos, isEmpty);
      expect((m.x, m.y), (1, 1));
      expect(m.dir, Direccion.izquierda);
      expect(m.xVisual, 1);
    });

    test('sin tecla sostenida termina el paso en curso y se detiene', () {
      final m = MotorMovimiento(x: 1, y: 1);
      m.avanzar(
        sostenida: Direccion.derecha,
        velocidad: 0,
        dtSeg: 0.125,
        puedeMoverA: (x, y) => true,
      );
      expect(m.x, 1);
      final p = m.avanzar(
        sostenida: null,
        velocidad: 0,
        dtSeg: 1,
        puedeMoverA: (x, y) => true,
      );
      expect(p.length, 1);
      expect(m.x, 2);
      expect(m.enMovimiento, isFalse);
    });
  });

  group('Mejoras sueltas', () {
    test('aparecen al romper la caja y se reclaman una vez', () {
      // Busca una (x,y,rota) con mejora.
      late int rota;
      for (rota = 1000000; MapaArena.mejoraEn(3, 3, rota) == null; rota++) {}
      final tipo = MapaArena.mejoraEn(3, 3, rota)!;
      // Usa una celda con caja inicial para que el rebrote la oculte.
      int bx = 0, by = 0;
      outer:
      for (var y = 1; y < 16; y++) {
        for (var x = 1; x < 20; x++) {
          if (MapaArena.hayCajaInicial(x, y)) {
            bx = x;
            by = y;
            break outer;
          }
        }
      }
      while (MapaArena.mejoraEn(bx, by, rota) == null) {
        rota++;
      }
      final esperado = MapaArena.mejoraEn(bx, by, rota)!;
      final caja = CajaRota(x: bx, y: by, rota: rota, por: 'u');
      final s = EstadoArena(cajasRotas: [caja]);
      final sueltas = s.mejorasSueltas(rota + 100);
      expect(sueltas.length, 1);
      expect(sueltas.single.tipo, esperado);
      expect(sueltas.single.clave, CajaRota.claveMejora(bx, by, rota));
      final reclamada = EstadoArena(
        cajasRotas: [caja],
        mejorasReclamadas: {sueltas.single.clave},
      );
      expect(reclamada.mejorasSueltas(rota + 100), isEmpty);
      expect(
        s.mejorasSueltas(rota + 31000),
        isEmpty,
        reason: 'la caja rebrotó',
      );
      expect(tipo, isNotNull);
    });
  });

  group('Marcador y muerte', () {
    test('+1 por eliminar a otro, -1 por autoeliminación', () {
      final m = marcador([
        const Eliminacion(victima: 'b', autor: 'a', t: 1),
        const Eliminacion(victima: 'c', autor: 'a', t: 2),
        const Eliminacion(victima: 'a', autor: 'a', t: 3),
        const Eliminacion(victima: 'a', autor: 'b', t: 4),
        const Eliminacion(victima: 'c', autor: 'c', t: 5),
      ]);
      expect(m, {'a': 1, 'b': 1, 'c': -1});
    });

    test('la víctima sin puntos aparece con 0', () {
      expect(marcador([const Eliminacion(victima: 'v', autor: 'a', t: 1)]), {
        'a': 1,
        'v': 0,
      });
      expect(marcador(const []), isEmpty);
    });

    test('invulnerabilidad de 1500 ms tras reaparecer', () {
      const t0 = 100000;
      final reaparecido = jug(
        'v',
        3,
        3,
      ).alMorir(t0).reaparecer(t0 + 3000, (3, 3));
      expect(ReglasCohetazo.reaparicionMs, 3000);
      expect(ReglasCohetazo.invulnerabilidadMs, 1500);
      expect(reaparecido.invulnerableHasta, t0 + 4500);
      final s = EstadoArena(
        cajasRotas: sinCajas(t0 + 3000),
        // Fuego activo de t0+4000 a t0+4600 sobre (3,3).
        cohetes: {'a': coh('a', 'u', 3, 3, t0 + 1500)},
        jugadores: {'v': reaparecido},
      );
      expect(s.muereEn(reaparecido, t0 + 4000), isFalse);
      expect(s.muereEn(reaparecido, t0 + 4499), isFalse);
      expect(s.muereEn(reaparecido, t0 + 4500), isTrue);
      expect(
        s.muereEn(reaparecido, t0 + 4600),
        isFalse,
        reason: 'fuego apagado',
      );
    });

    test('un jugador muerto no vuelve a morir', () {
      const t0 = 100000;
      final s = EstadoArena(
        cajasRotas: sinCajas(t0),
        cohetes: {'a': coh('a', 'u', 3, 3, t0)},
      );
      expect(s.muereEn(jug('v', 3, 3).alMorir(t0), t0 + 2600), isFalse);
    });
  });
}
