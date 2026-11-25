import 'package:flutter_test/flutter_test.dart';
import 'package:planificacion_posada/features/cohetazo/models/caja_rota.dart';
import 'package:planificacion_posada/features/cohetazo/models/cohete.dart';
import 'package:planificacion_posada/features/cohetazo/models/eliminacion.dart';
import 'package:planificacion_posada/features/cohetazo/models/jugador.dart';
import 'package:planificacion_posada/features/cohetazo/repositories/cohetazo_repository.dart';
import 'package:planificacion_posada/features/cohetazo/repositories/fake_cohetazo_repository.dart';

Jugador _j(String uid, {int x = 1, int y = 1}) =>
    Jugador(uid: uid, nombre: 'N$uid', x: x, y: y);

void main() {
  late int t;
  late FakeCohetazoRepository repo;

  setUp(() {
    t = 5000;
    repo = FakeCohetazoRepository(reloj: () => t, desfase: 120);
  });

  test('es un CohetazoRepository y reporta el desfase del servidor', () async {
    final CohetazoRepository r = repo;
    expect(await r.desfaseServidor.first, 120);
  });

  test('entrar guarda jugador y avatar, y los flujos los emiten', () async {
    await repo.entrar(_j('a'), 'AVATAR');
    expect(repo.entradas, 1);
    expect((await repo.jugadores.first).single.uid, 'a');
    expect((await repo.jugadores.first).single.t, 5000);
    expect(await repo.avatares.first, {'a': 'AVATAR'});
  });

  test('actualizarJugador reemplaza el nodo y sella la hora', () async {
    await repo.entrar(_j('a'), 'X');
    t = 6000;
    await repo.actualizarJugador(_j('a', x: 3, y: 1));
    final j = repo.jugadoresActuales['a']!;
    expect((j.x, j.y, j.t), (3, 1, 6000));
    expect(repo.escriturasJugador, hasLength(1));
  });

  test('colocarCohete asigna id y hora del servidor', () async {
    t = 7000;
    final id = await repo.colocarCohete(
      const Cohete(id: '', uid: 'a', x: 1, y: 1, alcance: 2, colocado: 0),
    );
    final c = repo.cohetesActuales[id]!;
    expect((c.uid, c.colocado, c.id), ('a', 7000, id));
    expect((await repo.cohetes.first).single.id, id);
  });

  test('romperCaja guarda rota (servidor) y autor', () async {
    t = 8000;
    await repo.romperCaja(3, 1, 'a');
    final c = repo.cajasActuales['3_1']!;
    expect((c.x, c.y, c.rota, c.por), (3, 1, 8000, 'a'));
    expect(repo.cajasRotasEscritas, [(3, 1, 'a')]);
  });

  test('reclamarMejora: gana el primero, el segundo recibe false', () async {
    expect(await repo.reclamarMejora('3_1_8000', 'a'), isTrue);
    expect(await repo.reclamarMejora('3_1_8000', 'b'), isFalse);
    expect(repo.mejorasActuales, {'3_1_8000': 'a'});
    expect(await repo.mejoras.first, {'3_1_8000'});
  });

  test('registrarEliminacion añade víctima, autor y hora', () async {
    t = 9000;
    await repo.registrarEliminacion(victima: 'a', autor: 'b');
    final Eliminacion e = (await repo.eliminaciones.first).single;
    expect((e.victima, e.autor, e.t), ('a', 'b', 9000));
  });

  test('limpiarCohetesViejos borra por id', () async {
    final id = await repo.colocarCohete(
      const Cohete(id: '', uid: 'a', x: 1, y: 1, alcance: 2, colocado: 0),
    );
    await repo.limpiarCohetesViejos([id]);
    expect(repo.cohetesActuales, isEmpty);
    expect(repo.idsLimpiados, [id]);
  });

  test('salir elimina el nodo del jugador', () async {
    await repo.entrar(_j('a'), 'X');
    await repo.salir('a');
    expect(repo.jugadoresActuales, isEmpty);
    expect(repo.salidas, ['a']);
  });

  test('los flujos emiten los cambios posteriores', () async {
    final vistas = <int>[];
    final sub = repo.cajas.listen((l) => vistas.add(l.length));
    await pumpEventQueue();
    repo.simularCaja(const CajaRota(x: 1, y: 3, rota: 1, por: 'z'));
    await pumpEventQueue();
    await sub.cancel();
    expect(vistas, [0, 1]);
  });

  test('fallarEscritura hace fallar solo la siguiente escritura', () async {
    repo.fallarEscritura = StateError('sin red');
    await expectLater(repo.romperCaja(1, 1, 'a'), throwsStateError);
    await repo.romperCaja(1, 1, 'a');
    expect(repo.cajasActuales, isNotEmpty);
  });
}
