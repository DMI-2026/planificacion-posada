import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:planificacion_posada/features/intercambio/models/asignacion.dart';
import 'package:planificacion_posada/features/intercambio/models/config_intercambio.dart';
import 'package:planificacion_posada/features/intercambio/models/inscrito.dart';
import 'package:planificacion_posada/features/intercambio/repositories/fake_intercambio_repository.dart';
import 'package:planificacion_posada/features/intercambio/viewmodels/intercambio_view_model.dart';

const _nombres = {'u1': 'Ana', 'u2': 'Beto', 'u3': 'Caro', 'admin': 'Admin'};

IntercambioViewModel _vm(
  FakeIntercambioRepository repo, {
  String uid = 'u1',
  bool admin = false,
  bool participante = true,
}) => IntercambioViewModel(
  repo,
  uid: uid,
  esAdmin: admin,
  esParticipante: participante,
  nombres: _nombres,
  random: Random(3),
);

const _abierta = ConfigIntercambio(inscripcionAbierta: true);

Future<void> _carga() => pumpEventQueue();

void main() {
  test('carga: config, inscrito, deseos y total', () async {
    final repo = FakeIntercambioRepository(
      config: _abierta.copyWith(presupuestoCentavos: 25000),
      inscritos: const [
        Inscrito(uid: 'u1', deseos: ['Calcetas']),
        Inscrito(uid: 'u2'),
      ],
    );
    final vm = _vm(repo);
    expect(vm.cargando, isTrue);
    await _carga();
    expect(vm.cargando, isFalse);
    expect(vm.config.presupuestoCentavos, 25000);
    expect(vm.inscrito?.uid, 'u1');
    expect(vm.misDeseos, ['Calcetas']);
    expect(vm.totalInscritos, 2);
    expect(vm.puedeInscribirse, isFalse);
    expect(vm.miDestinatario, isNull);
    expect(vm.parejas, isEmpty);
    vm.dispose();
    expect(repo.escuchas, 0);
  });

  group('inscribirse / actualizar / salir', () {
    test('inscribirse guarda deseos recortados', () async {
      final repo = FakeIntercambioRepository(config: _abierta);
      final vm = _vm(repo);
      await _carga();
      expect(vm.puedeInscribirse, isTrue);
      expect(await vm.inscribirse(['  Libro ', 'Taza']), isTrue);
      await _carga();
      expect(vm.misDeseos, ['Libro', 'Taza']);
      expect(vm.totalInscritos, 1);
      expect(vm.error, isNull);
      vm.dispose();
    });

    test('permite inscribirse sin deseos', () async {
      final repo = FakeIntercambioRepository(config: _abierta);
      final vm = _vm(repo);
      await _carga();
      expect(await vm.inscribirse([]), isTrue);
      vm.dispose();
    });

    test('valida deseos y no guarda nada', () async {
      final repo = FakeIntercambioRepository(config: _abierta);
      final vm = _vm(repo);
      await _carga();
      expect(await vm.inscribirse(['a', 'b', 'c', 'd']), isFalse);
      expect(vm.error, 'Máximo 3 deseos.');
      expect(await vm.inscribirse(['  ']), isFalse);
      expect(vm.error, 'Un deseo no puede estar vacío.');
      expect(await vm.inscribirse(['x' * 81]), isFalse);
      expect(vm.error, 'Cada deseo admite máximo 80 caracteres.');
      expect(await vm.inscribirse(['x' * 80]), isTrue);
      expect(vm.error, isNull);
      expect(repo.inscritosActuales, hasLength(1));
      vm.dispose();
    });

    test('rechaza a quien no es participante', () async {
      final repo = FakeIntercambioRepository(config: _abierta);
      final vm = _vm(repo, participante: false);
      await _carga();
      expect(await vm.inscribirse(['a']), isFalse);
      expect(
        vm.error,
        'Solo quienes están en la lista de la posada pueden inscribirse.',
      );
      expect(repo.inscritosActuales, isEmpty);
      vm.dispose();
    });

    test('rechaza con inscripción cerrada o sorteo hecho', () async {
      for (final c in const [
        ConfigIntercambio(),
        ConfigIntercambio(sorteado: true),
      ]) {
        final repo = FakeIntercambioRepository(config: c);
        final vm = _vm(repo);
        await _carga();
        expect(await vm.inscribirse(['a']), isFalse);
        expect(vm.error, 'La inscripción al intercambio está cerrada.');
        expect(repo.inscritosActuales, isEmpty);
        vm.dispose();
      }
    });

    test('actualizarDeseos y salir exigen estar inscrito', () async {
      final repo = FakeIntercambioRepository(config: _abierta);
      final vm = _vm(repo);
      await _carga();
      expect(await vm.actualizarDeseos(['a']), isFalse);
      expect(vm.error, 'Primero inscríbete al intercambio.');
      expect(await vm.salir(), isFalse);
      expect(vm.error, 'Primero inscríbete al intercambio.');
      await vm.inscribirse(['a']);
      await _carga();
      expect(await vm.actualizarDeseos(['b', 'c']), isTrue);
      await _carga();
      expect(vm.misDeseos, ['b', 'c']);
      expect(await vm.salir(), isTrue);
      await _carga();
      expect(vm.inscrito, isNull);
      expect(vm.totalInscritos, 0);
      vm.dispose();
    });

    test('no se puede salir ni editar tras el sorteo', () async {
      final repo = FakeIntercambioRepository(
        config: const ConfigIntercambio(sorteado: true),
        inscritos: const [
          Inscrito(uid: 'u1'),
          Inscrito(uid: 'u2'),
        ],
      );
      final vm = _vm(repo);
      await _carga();
      expect(await vm.salir(), isFalse);
      expect(vm.error, 'La inscripción al intercambio está cerrada.');
      expect(await vm.actualizarDeseos(['z']), isFalse);
      expect(repo.inscritosActuales, hasLength(2));
      vm.dispose();
    });

    test('un fallo de la nube se traduce y no cambia el estado', () async {
      final repo = FakeIntercambioRepository(config: _abierta);
      final vm = _vm(repo);
      await _carga();
      repo.fallarCon = StateError('x');
      expect(await vm.inscribirse(['a']), isFalse);
      expect(vm.error, 'No pudimos guardar los cambios. Intenta de nuevo.');
      expect(vm.ocupado, isFalse);
      vm.limpiarError();
      expect(vm.error, isNull);
      vm.dispose();
    });
  });

  group('admin', () {
    test('un no admin no puede administrar', () async {
      final repo = FakeIntercambioRepository(config: _abierta);
      final vm = _vm(repo);
      await _carga();
      for (final r in [
        await vm.cerrarInscripcion(),
        await vm.abrirInscripcion(),
        await vm.sortear(),
        await vm.rehacerSorteo(),
        await vm.revelar(),
        await vm.editarPresupuesto(100),
        await vm.editarFecha(DateTime(2026, 12, 18)),
      ]) {
        expect(r, isFalse);
        expect(vm.error, 'Solo el organizador puede hacer esto.');
      }
      expect(repo.configActual, _abierta);
      vm.dispose();
    });

    test('abrir y cerrar inscripción', () async {
      final repo = FakeIntercambioRepository();
      final vm = _vm(repo, admin: true, uid: 'admin');
      await _carga();
      expect(await vm.abrirInscripcion(), isTrue);
      expect(repo.configActual.inscripcionAbierta, isTrue);
      expect(await vm.cerrarInscripcion(), isTrue);
      expect(repo.configActual.inscripcionAbierta, isFalse);
      vm.dispose();
    });

    test('sortear: exige cerrada y 2 inscritos; luego escribe todo', () async {
      final repo = FakeIntercambioRepository(
        config: _abierta,
        inscritos: const [Inscrito(uid: 'u1')],
      );
      final vm = _vm(repo, admin: true, uid: 'admin');
      await _carga();
      expect(await vm.sortear(), isFalse);
      expect(vm.error, 'Cierra la inscripción antes de sortear.');
      await vm.cerrarInscripcion();
      await _carga();
      expect(await vm.sortear(), isFalse);
      expect(vm.error, 'Se necesitan al menos 2 inscritos para sortear.');
      expect(repo.asignacionesActuales, isEmpty);
      await repo.guardarInscrito(const Inscrito(uid: 'u2'));
      await repo.guardarInscrito(const Inscrito(uid: 'u3'));
      await _carga();
      expect(await vm.sortear(), isTrue);
      await _carga();
      expect(repo.configActual.sorteado, isTrue);
      expect(repo.configActual.inscripcionAbierta, isFalse);
      final a = {
        for (final x in repo.asignacionesActuales) x.uid: x.destinatarioId,
      };
      expect(a.keys.toSet(), {'u1', 'u2', 'u3'});
      expect(a.values.toSet(), {'u1', 'u2', 'u3'});
      expect(a.entries.every((e) => e.key != e.value), isTrue);
      // ya sorteado: no se vuelve a sortear
      expect(await vm.sortear(), isFalse);
      expect(vm.error, 'El sorteo ya se realizó.');
      vm.dispose();
    });

    test('rehacer solo antes de revelar; revelar una vez', () async {
      final repo = FakeIntercambioRepository(
        config: const ConfigIntercambio(sorteado: true),
        inscritos: const [
          Inscrito(uid: 'u1'),
          Inscrito(uid: 'u2'),
        ],
        asignaciones: const [
          Asignacion(uid: 'u1', destinatarioId: 'u2'),
          Asignacion(uid: 'u2', destinatarioId: 'u1'),
        ],
      );
      final vm = _vm(repo, admin: true, uid: 'admin');
      await _carga();
      expect(await vm.rehacerSorteo(), isTrue);
      expect(repo.asignacionesActuales, hasLength(2));
      expect(await vm.revelar(), isTrue);
      expect(repo.configActual.revelado, isTrue);
      await _carga();
      expect(await vm.revelar(), isFalse);
      expect(vm.error, 'El sorteo ya fue revelado.');
      expect(await vm.rehacerSorteo(), isFalse);
      expect(vm.error, 'El sorteo ya fue revelado; no se puede rehacer.');
      vm.dispose();
    });

    test('revelar y rehacer exigen sorteo hecho', () async {
      final repo = FakeIntercambioRepository(config: _abierta);
      final vm = _vm(repo, admin: true, uid: 'admin');
      await _carga();
      expect(await vm.revelar(), isFalse);
      expect(vm.error, 'Primero haz el sorteo.');
      expect(await vm.rehacerSorteo(), isFalse);
      expect(vm.error, 'Primero haz el sorteo.');
      vm.dispose();
    });

    test('presupuesto y fecha', () async {
      final repo = FakeIntercambioRepository();
      final vm = _vm(repo, admin: true, uid: 'admin');
      await _carga();
      expect(await vm.editarPresupuesto(-1), isFalse);
      expect(
        vm.error,
        'El presupuesto debe estar entre \$0.00 y \$100,000.00.',
      );
      expect(await vm.editarPresupuesto(10000001), isFalse);
      expect(await vm.editarPresupuesto(30000), isTrue);
      expect(repo.configActual.presupuestoCentavos, 30000);
      final f = DateTime(2026, 12, 18, 19);
      expect(await vm.editarFecha(f), isTrue);
      expect(repo.configActual.fecha, f);
      expect(await vm.editarFecha(null), isTrue);
      expect(repo.configActual.fecha, isNull);
      expect(repo.configActual.presupuestoCentavos, 30000);
      vm.dispose();
    });
  });

  group('destinatario y parejas', () {
    FakeIntercambioRepository repo0({bool revelado = false}) =>
        FakeIntercambioRepository(
          config: ConfigIntercambio(sorteado: true, revelado: revelado),
          inscritos: const [
            Inscrito(uid: 'u1', deseos: ['Libro']),
            Inscrito(uid: 'u2', deseos: ['Taza', 'Calcetas']),
            Inscrito(uid: 'u3'),
          ],
          asignaciones: const [
            Asignacion(uid: 'u1', destinatarioId: 'u2'),
            Asignacion(uid: 'u2', destinatarioId: 'u3'),
            Asignacion(uid: 'u3', destinatarioId: 'u1'),
          ],
        );

    test('miDestinatario trae nombre y deseos; parejas ocultas', () async {
      final repo = repo0();
      final vm = _vm(repo);
      await _carga();
      expect(vm.miDestinatario?.uid, 'u2');
      expect(vm.miDestinatario?.nombre, 'Beto');
      expect(vm.miDestinatario?.deseos, ['Taza', 'Calcetas']);
      expect(vm.parejas, isEmpty);
      expect(repo.escuchasTodas, 0, reason: 'no lee las ajenas');
      vm.dispose();
    });

    test('revelado: todas las parejas, por nombre de quien da', () async {
      final repo = repo0(revelado: true);
      final vm = _vm(repo);
      await _carga();
      expect(vm.parejas.map((p) => '${p.dadorNombre}>${p.receptorNombre}'), [
        'Ana>Beto',
        'Beto>Caro',
        'Caro>Ana',
      ]);
      vm.dispose();
      expect(repo.escuchasTodas, 0);
    });

    test('al revelar en vivo aparecen las parejas', () async {
      final repo = repo0();
      final vm = _vm(repo);
      await _carga();
      expect(vm.parejas, isEmpty);
      await repo.guardarConfig(repo.configActual.copyWith(revelado: true));
      await _carga();
      expect(vm.parejas, hasLength(3));
      vm.dispose();
    });

    test('el admin ve las parejas antes de revelar', () async {
      final vm = _vm(repo0(), admin: true, uid: 'admin');
      await _carga();
      expect(vm.parejas, hasLength(3));
      expect(vm.miDestinatario, isNull);
      vm.dispose();
    });

    test('nombre desconocido y actualizarNombres', () async {
      final vm = IntercambioViewModel(
        repo0(),
        uid: 'u1',
        esAdmin: false,
        esParticipante: true,
        nombres: const {},
      );
      await _carga();
      expect(vm.miDestinatario?.nombre, 'Alguien');
      vm.actualizarNombres({'u2': 'Beto'});
      expect(vm.miDestinatario?.nombre, 'Beto');
      vm.dispose();
    });
  });
}
