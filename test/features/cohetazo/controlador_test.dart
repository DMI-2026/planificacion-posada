import 'package:flutter_test/flutter_test.dart';
import 'package:planificacion_posada/features/cohetazo/juego/mapa_arena.dart';
import 'package:planificacion_posada/features/cohetazo/juego/reglas_cohetazo.dart';
import 'package:planificacion_posada/features/cohetazo/models/caja_rota.dart';
import 'package:planificacion_posada/features/cohetazo/models/cohete.dart';
import 'package:planificacion_posada/features/cohetazo/models/direccion.dart';
import 'package:planificacion_posada/features/cohetazo/models/eliminacion.dart';
import 'package:planificacion_posada/features/cohetazo/models/jugador.dart';
import 'package:planificacion_posada/features/cohetazo/models/tipo_mejora.dart';
import 'package:planificacion_posada/features/cohetazo/repositories/fake_cohetazo_repository.dart';
import 'package:planificacion_posada/features/cohetazo/viewmodels/cohetazo_view_model.dart';

const _uid = 'u1';

class Banco {
  Banco({int desfase = 0}) {
    repo = FakeCohetazoRepository(reloj: () => t + desfase, desfase: desfase);
    vm = CohetazoViewModel(
      repo,
      uid: _uid,
      nombre: 'Ana',
      avatar: 'AVATAR',
      reloj: () => t,
    );
  }

  int t = 1000000;
  late final FakeCohetazoRepository repo;
  late final CohetazoViewModel vm;

  Future<void> iniciar() async {
    await vm.iniciar();
    await pumpEventQueue();
  }

  /// Avanza el reloj [ms] en cuadros de 16 ms, dejando correr los flujos.
  Future<void> avanzar(int ms) async {
    var resto = ms;
    while (resto > 0) {
      final paso = resto < 16 ? resto : 16;
      t += paso;
      vm.paso(paso / 1000);
      await pumpEventQueue(times: 2);
      resto -= paso;
    }
  }

  /// Avanza hasta pasar de la invulnerabilidad inicial.
  Future<void> pasarInvulnerabilidad() => avanzar(1600);
}

void main() {
  late Banco b;

  tearDown(() => b.vm.dispose());

  group('entrar', () {
    test('aparece en su punto, guarda avatar y queda jugando', () async {
      b = Banco();
      await b.iniciar();
      final punto = MapaArena.puntoAparicion(_uid, 0);
      expect(b.vm.fase, FaseCohetazo.jugando);
      expect((b.vm.yo.x, b.vm.yo.y), punto);
      expect(b.vm.yo.vivo, isTrue);
      expect(b.repo.entradas, 1);
      expect(b.repo.avataresActuales[_uid], 'AVATAR');
      final nodo = b.repo.jugadoresActuales[_uid]!;
      expect(
        (nodo.nombre, nodo.alcance, nodo.cohetes, nodo.velocidad),
        ('Ana', 2, 1, 0),
      );
    });

    test(
      'un fallo al entrar deja la fase en error y se puede reintentar',
      () async {
        b = Banco();
        b.repo.fallarEscritura = StateError('sin red');
        await b.vm.iniciar();
        expect(b.vm.fase, FaseCohetazo.error);
        expect(b.vm.error, isNotEmpty);
        await b.iniciar();
        expect(b.vm.fase, FaseCohetazo.jugando);
        expect(b.vm.error, isNull);
      },
    );

    test('la hora del servidor se corrige con el desfase', () async {
      b = Banco(desfase: 5000);
      await b.iniciar();
      expect(b.vm.ahora, b.t + 5000);
    });

    test('si su nodo desaparece (reconexión) vuelve a entrar', () async {
      b = Banco();
      await b.iniciar();
      b.repo.simularSalida(_uid);
      await pumpEventQueue();
      expect(b.repo.entradas, 2);
      expect(b.repo.jugadoresActuales, contains(_uid));
    });
  });

  group('movimiento', () {
    test('un muro bloquea: la celda no cambia ni se escribe', () async {
      b = Banco();
      await b.iniciar();
      final (x, y) = (b.vm.yo.x, b.vm.yo.y);
      final bloqueada = Direccion.values.firstWhere(
        (d) => MapaArena.esMuro(x + d.dx, y + d.dy),
      );
      final escritas = b.repo.escriturasJugador.length;
      b.vm.sostener(bloqueada);
      await b.avanzar(1000);
      expect((b.vm.yo.x, b.vm.yo.y), (x, y));
      expect(b.vm.yo.dir, bloqueada, reason: 'mira hacia el muro');
      expect(b.repo.escriturasJugador.length, lessThanOrEqualTo(escritas + 1));
    });

    test('una celda libre se recorre y se escribe una vez por celda', () async {
      b = Banco();
      await b.iniciar();
      final (x, y) = (b.vm.yo.x, b.vm.yo.y);
      final libre = Direccion.values.firstWhere(
        (d) => !MapaArena.esMuro(x + d.dx, y + d.dy),
      );
      b.vm.sostener(libre);
      await b.avanzar(
        200,
      ); // 4 celdas/s: 0,8 celdas; el paso empezado se completa
      b.vm.sostener(null);
      await b.avanzar(300);
      expect((b.vm.yo.x, b.vm.yo.y), (x + libre.dx, y + libre.dy));
      expect(b.repo.jugadoresActuales[_uid]!.x, x + libre.dx);
    });

    test('sin cambios de celda, dirección ni vida no hay escrituras', () async {
      b = Banco();
      await b.iniciar();
      await b.avanzar(500);
      expect(b.repo.escriturasJugador, isEmpty);
    });
  });

  group('cohetes', () {
    test(
      'coloca un cohete en su celda con su alcance y respeta el límite',
      () async {
        b = Banco();
        await b.iniciar();
        await b.vm.colocarCohete();
        await pumpEventQueue();
        final c = b.repo.cohetesActuales.values.single;
        expect(
          (c.uid, c.x, c.y, c.alcance),
          (_uid, b.vm.yo.x, b.vm.yo.y, ReglasCohetazo.alcanceBase),
        );
        await b.vm.colocarCohete();
        await pumpEventQueue();
        expect(b.repo.cohetesActuales, hasLength(1));
      },
    );

    test('no coloca cohetes si está muerto', () async {
      b = Banco();
      await b.iniciar();
      await b.pasarInvulnerabilidad();
      b.repo.simularCohete(
        Cohete(
          id: 'r',
          uid: 'otro',
          x: b.vm.yo.x,
          y: b.vm.yo.y,
          alcance: 2,
          colocado: b.t - 2490,
        ),
      );
      await pumpEventQueue();
      await b.avanzar(100);
      expect(b.vm.yo.vivo, isFalse);
      await b.vm.colocarCohete();
      expect(b.repo.cohetesActuales, hasLength(1));
    });

    test('su explosión escribe las cajas que rompió, una sola vez', () async {
      b = Banco();
      await b.iniciar();
      // Una caja con su vecina izquierda libre (ni muro ni caja).
      late int bx, by;
      outer:
      for (var y = 1; y < ReglasCohetazo.filas - 1; y++) {
        for (var x = 3; x < ReglasCohetazo.columnas - 1; x++) {
          if (MapaArena.hayCajaInicial(x, y) &&
              !MapaArena.esMuro(x - 1, y) &&
              !MapaArena.hayCajaInicial(x - 1, y) &&
              (x - 1, y) != (b.vm.yo.x, b.vm.yo.y)) {
            bx = x;
            by = y;
            break outer;
          }
        }
      }
      b.repo.simularCohete(
        Cohete(
          id: 'mio',
          uid: _uid,
          x: bx - 1,
          y: by,
          alcance: 1,
          colocado: b.t,
        ),
      );
      await pumpEventQueue();
      await b.avanzar(2400);
      expect(b.repo.cajasRotasEscritas, isEmpty);
      await b.avanzar(300);
      expect(b.repo.cajasRotasEscritas, [(bx, by, _uid)]);
      await b.avanzar(1000);
      expect(b.repo.cajasRotasEscritas, hasLength(1));
    });

    test('la explosión de otro jugador no escribe cajas desde aquí', () async {
      b = Banco();
      await b.iniciar();
      late int bx, by;
      outer:
      for (var y = 1; y < ReglasCohetazo.filas - 1; y++) {
        for (var x = 3; x < ReglasCohetazo.columnas - 1; x++) {
          if (MapaArena.hayCajaInicial(x, y) &&
              !MapaArena.esMuro(x - 1, y) &&
              !MapaArena.hayCajaInicial(x - 1, y) &&
              (x - 1, y) != (b.vm.yo.x, b.vm.yo.y)) {
            bx = x;
            by = y;
            break outer;
          }
        }
      }
      b.repo.simularCohete(
        Cohete(
          id: 'ajeno',
          uid: 'otro',
          x: bx - 1,
          y: by,
          alcance: 1,
          colocado: b.t,
        ),
      );
      await pumpEventQueue();
      await b.avanzar(3000);
      expect(b.repo.cajasRotasEscritas, isEmpty);
    });

    test('limpia los cohetes con más de 10 s', () async {
      b = Banco();
      await b.iniciar();
      b.repo.simularCohete(
        Cohete(
          id: 'viejo',
          uid: 'otro',
          x: 3,
          y: 1,
          alcance: 2,
          colocado: b.t - 12000,
        ),
      );
      b.repo.simularCohete(
        Cohete(
          id: 'nuevo',
          uid: 'otro',
          x: 5,
          y: 3,
          alcance: 2,
          colocado: b.t - 1000,
        ),
      );
      await pumpEventQueue();
      await b.avanzar(2500);
      expect(b.repo.idsLimpiados, ['viejo']);
    });
  });

  group('muerte y reaparición', () {
    test(
      'el fuego mata: eliminación, mejoras perdidas, reaparece a los 3 s',
      () async {
        b = Banco();
        await b.iniciar();
        await b.pasarInvulnerabilidad();
        final (x, y) = (b.vm.yo.x, b.vm.yo.y);
        final inicio = b.t + 2500;
        b.repo.simularCohete(
          Cohete(id: 'r', uid: 'otro', x: x, y: y, alcance: 2, colocado: b.t),
        );
        await pumpEventQueue();
        await b.avanzar(2490);
        expect(b.vm.yo.vivo, isTrue);
        await b.avanzar(20);
        expect(b.vm.yo.vivo, isFalse);
        expect(
          b.vm.yo.reaparece,
          inInclusiveRange(inicio + 2980, inicio + 3040),
        );
        expect(b.repo.eliminacionesActuales.map((e) => (e.victima, e.autor)), [
          (_uid, 'otro'),
        ]);
        expect(b.repo.jugadoresActuales[_uid]!.vivo, isFalse);
        final reaparece = b.vm.yo.reaparece;
        await b.avanzar(reaparece - b.t - 32);
        expect(b.vm.yo.vivo, isFalse, reason: 'aún faltan ms');
        await b.avanzar(64);
        expect(b.vm.yo.vivo, isTrue);
        expect(b.vm.yo.celda, MapaArena.puntoAparicion(_uid, 1));
        expect(b.vm.yo.invulnerableHasta, greaterThan(b.t));
        expect(b.vm.invulnerable, isTrue);
        expect(b.repo.jugadoresActuales[_uid]!.vivo, isTrue);
        expect(b.repo.eliminacionesActuales, hasLength(1));
      },
    );

    test('la autoeliminación se registra con autor == víctima', () async {
      b = Banco();
      await b.iniciar();
      await b.pasarInvulnerabilidad();
      b.repo.simularCohete(
        Cohete(
          id: 'm',
          uid: _uid,
          x: b.vm.yo.x,
          y: b.vm.yo.y,
          alcance: 2,
          colocado: b.t,
        ),
      );
      await pumpEventQueue();
      await b.avanzar(2600);
      expect(b.repo.eliminacionesActuales.single.victima, _uid);
      expect(b.repo.eliminacionesActuales.single.autor, _uid);
      expect(b.vm.puntaje, -1);
    });

    test('la invulnerabilidad inicial evita la muerte', () async {
      b = Banco();
      await b.iniciar();
      // Explota a los 500 ms y el fuego dura hasta los 1100 ms (< 1500 ms).
      b.repo.simularCohete(
        Cohete(
          id: 'r',
          uid: 'otro',
          x: b.vm.yo.x,
          y: b.vm.yo.y,
          alcance: 2,
          colocado: b.t - 2000,
        ),
      );
      await pumpEventQueue();
      await b.avanzar(1400);
      expect(b.vm.invulnerable, isTrue);
      expect(b.vm.yo.vivo, isTrue);
      expect(b.repo.eliminacionesActuales, isEmpty);
    });
  });

  group('mejoras', () {
    ({int rota, TipoMejora tipo}) hallar(
      int x,
      int y,
      int desde,
      TipoMejora? quiere,
    ) {
      for (var k = 1; k < 2000; k++) {
        final r = desde - k;
        final tipo = MapaArena.mejoraEn(x, y, r);
        if (tipo != null && (quiere == null || tipo == quiere)) {
          return (rota: r, tipo: tipo);
        }
      }
      throw StateError('sin mejora');
    }

    test('la reclama en una transacción y aplica sus stats', () async {
      b = Banco();
      await b.iniciar();
      final (x, y) = (b.vm.yo.x, b.vm.yo.y);
      final m = hallar(x, y, b.t - 500, null);
      b.repo.simularCaja(CajaRota(x: x, y: y, rota: m.rota, por: 'otro'));
      await pumpEventQueue();
      await b.avanzar(100);
      final clave = CajaRota.claveMejora(x, y, m.rota);
      expect(b.repo.mejorasActuales, {clave: _uid});
      final yo = b.vm.yo;
      switch (m.tipo) {
        case TipoMejora.alcance:
          expect(yo.alcance, ReglasCohetazo.alcanceBase + 1);
        case TipoMejora.cohetes:
          expect(yo.cohetes, ReglasCohetazo.cohetesBase + 1);
        case TipoMejora.velocidad:
          expect(yo.velocidad, ReglasCohetazo.velocidadBase + 1);
      }
      expect(b.repo.jugadoresActuales[_uid]!.alcance, yo.alcance);
      await b.avanzar(300);
      expect(
        b.vm.yo.alcance + b.vm.yo.cohetes + b.vm.yo.velocidad,
        2 + 1 + 0 + 1,
      );
    });

    test('si otro la reclamó antes no aplica nada', () async {
      b = Banco();
      await b.iniciar();
      final (x, y) = (b.vm.yo.x, b.vm.yo.y);
      final m = hallar(x, y, b.t - 500, null);
      b.repo.simularCaja(CajaRota(x: x, y: y, rota: m.rota, por: 'otro'));
      b.repo.simularMejora(CajaRota.claveMejora(x, y, m.rota), 'otro');
      await pumpEventQueue();
      await b.avanzar(200);
      expect(b.vm.yo.alcance + b.vm.yo.cohetes + b.vm.yo.velocidad, 3);
      expect(b.repo.mejorasActuales.values, ['otro']);
    });

    test('al morir se pierden las mejoras', () async {
      b = Banco();
      await b.iniciar();
      final (x, y) = (b.vm.yo.x, b.vm.yo.y);
      final m = hallar(x, y, b.t - 500, null);
      b.repo.simularCaja(CajaRota(x: x, y: y, rota: m.rota, por: 'otro'));
      await pumpEventQueue();
      await b.avanzar(1600);
      expect(b.vm.yo.alcance + b.vm.yo.cohetes + b.vm.yo.velocidad, 4);
      b.repo.simularCohete(
        Cohete(id: 'r', uid: 'otro', x: x, y: y, alcance: 2, colocado: b.t),
      );
      await pumpEventQueue();
      await b.avanzar(2700);
      expect(b.vm.yo.vivo, isFalse);
      expect(b.vm.yo.alcance, ReglasCohetazo.alcanceBase);
      expect(b.vm.yo.cohetes, ReglasCohetazo.cohetesBase);
      expect(b.vm.yo.velocidad, ReglasCohetazo.velocidadBase);
    });
  });

  group('marcador y presencia', () {
    test(
      'cuenta jugadores en línea y ordena el marcador con el propio',
      () async {
        b = Banco();
        await b.iniciar();
        b.repo.simularJugador(
          const Jugador(uid: 'b', nombre: 'Beto', x: 3, y: 1),
          avatar: 'AV-B',
        );
        b.repo.simularJugador(
          const Jugador(uid: 'c', nombre: 'Cami', x: 5, y: 3),
        );
        for (final e in [('c', 'b'), ('b', 'c'), ('b', 'c'), (_uid, _uid)]) {
          b.repo.simularEliminacion(
            Eliminacion(victima: e.$1, autor: e.$2, t: 1),
          );
        }
        await pumpEventQueue();
        expect(b.vm.enLinea, 3);
        expect(b.vm.avatares['b'], 'AV-B');
        final tabla = b.vm.tablero;
        expect(tabla.map((e) => (e.nombre, e.puntos)).toList(), [
          ('Cami', 2),
          ('Beto', 1),
          ('Ana', -1),
        ]);
        expect(tabla.last.esYo, isTrue);
        expect(b.vm.puntaje, -1);
      },
    );

    test('los remotos se interpolan entre celdas', () async {
      b = Banco();
      await b.iniciar();
      b.repo.simularJugador(
        const Jugador(uid: 'b', nombre: 'Beto', x: 3, y: 1),
      );
      await pumpEventQueue();
      await b.avanzar(32);
      expect(b.vm.posicionVisual('b'), (3.0, 1.0));
      b.repo.simularJugador(
        const Jugador(uid: 'b', nombre: 'Beto', x: 4, y: 1),
      );
      await pumpEventQueue();
      await b.avanzar(32);
      final (vx, _) = b.vm.posicionVisual('b');
      expect(vx, greaterThan(3.0));
      expect(vx, lessThan(4.0));
      await b.avanzar(500);
      expect(b.vm.posicionVisual('b'), (4.0, 1.0));
    });
  });

  group('salir', () {
    test('quita su nodo y deja de procesar cuadros', () async {
      b = Banco();
      await b.iniciar();
      await b.vm.salir();
      expect(b.repo.salidas, [_uid]);
      expect(b.repo.jugadoresActuales, isEmpty);
      b.vm.sostener(Direccion.derecha);
      b.vm.paso(1);
      await pumpEventQueue();
      expect(b.repo.entradas, 1);
      expect(b.repo.escriturasJugador, isEmpty);
    });
  });
}
