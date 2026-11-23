import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planificacion_posada/features/itinerario/models/actividad.dart';
import 'package:planificacion_posada/features/itinerario/repositories/fake_itinerario_repository.dart';
import 'package:planificacion_posada/features/itinerario/repositories/firestore_itinerario_repository.dart';
import 'package:planificacion_posada/features/itinerario/viewmodels/itinerario_view_model.dart';

DateTime h(int hora, [int min = 0]) => DateTime(2026, 12, 24, hora, min);

Actividad act(String id, int hora, int dur, {String? resp, int min = 0}) =>
    Actividad(
      id: id,
      titulo: 'T$id',
      inicio: h(hora, min),
      duracionMin: dur,
      responsableId: resp,
    );

void main() {
  group('Actividad', () {
    test('toMap tiene exactamente las claves del documento', () {
      final a = Actividad(
        id: 'x',
        titulo: 'Piñata',
        descripcion: 'd',
        inicio: h(20),
        duracionMin: 30,
        responsableId: 'u1',
      );
      expect(a.toMap(), {
        'titulo': 'Piñata',
        'descripcion': 'd',
        'inicio': h(20),
        'duracion_min': 30,
        'responsable_id': 'u1',
      });
      expect(Actividad.fromMap('x', a.toMap()), a);
      expect(a.fin, h(20, 30));
    });

    test('fromMap acepta responsable nulo', () {
      final a = Actividad.fromMap('x', {
        'titulo': 'A',
        'descripcion': '',
        'inicio': h(1),
        'duracion_min': 5,
        'responsable_id': null,
      });
      expect(a.responsableId, isNull);
    });
  });

  group('helpers Timestamp', () {
    test('ida y vuelta DateTime <-> Timestamp', () {
      final m = mapaAFirestore(act('a', 20, 30, resp: 'u1').toMap());
      expect(m['inicio'], Timestamp.fromDate(h(20)));
      expect(m['responsable_id'], 'u1');
      final v = mapaDesdeFirestore(m.cast<String, dynamic>());
      expect(v['inicio'], h(20));
      expect(Actividad.fromMap('a', v), act('a', 20, 30, resp: 'u1'));
    });
  });

  group('ItinerarioViewModel', () {
    late DateTime reloj;
    late FakeItinerarioRepository repo;
    ItinerarioViewModel crear({bool admin = true, List<Actividad>? ini}) {
      repo = FakeItinerarioRepository(
        inicial: ini ?? [act('c', 21, 30), act('a', 19, 60), act('b', 20, 30)],
      );
      final vm = ItinerarioViewModel(
        repo,
        esAdmin: admin,
        ahora: () => reloj,
        nombresIniciales: const {'u1': 'Ana'},
      );
      addTearDown(vm.dispose);
      return vm;
    }

    setUp(() => reloj = h(18));

    test('ordena por inicio y suma duración', () async {
      final vm = crear();
      await pumpEventQueue();
      expect(vm.actividades.map((a) => a.id), ['a', 'b', 'c']);
      expect(vm.duracionTotal, const Duration(minutes: 120));
      expect(vm.cargando, isFalse);
    });

    test(
      'estados con el reloj: pendiente/siguiente, en curso, pasada',
      () async {
        final vm = crear();
        await pumpEventQueue();
        EstadoActividad e(String id) =>
            vm.estadoDe(vm.actividades.firstWhere((a) => a.id == id));
        expect(e('a'), EstadoActividad.siguiente);
        expect(e('b'), EstadoActividad.pendiente);
        expect(vm.siguiente?.id, 'a');

        reloj = h(19, 30);
        expect(e('a'), EstadoActividad.enCurso);
        expect(e('b'), EstadoActividad.siguiente);
        expect(e('c'), EstadoActividad.pendiente);

        reloj = h(20); // a termina justo a las 20:00
        expect(e('a'), EstadoActividad.pasada);
        expect(e('b'), EstadoActividad.enCurso);

        reloj = h(22);
        expect(e('c'), EstadoActividad.pasada);
        expect(vm.siguiente, isNull);
      },
    );

    test('detecta traslapes (y no los contiguos)', () async {
      final vm = crear(
        ini: [
          act('a', 19, 60),
          act('b', 19, 30, min: 30),
          act('c', 20, 30, min: 30),
        ],
      );
      await pumpEventQueue();
      // a: 19:00-20:00, b: 19:30-20:00 (traslapa), c: 20:30 (no)
      expect(vm.solapamientos.length, 1);
      expect(vm.idsConSolape, {'a', 'b'});
      expect(crear().idsConSolape, isEmpty);
    });

    test('agregar válido guarda, y avisa si traslapa', () async {
      final vm = crear();
      await pumpEventQueue();
      expect(
        await vm.agregar(
          titulo: ' Cena ',
          inicio: h(19, 30),
          duracionMin: 30,
          responsableId: 'u1',
        ),
        isTrue,
      );
      await pumpEventQueue();
      expect(vm.actividades.length, 4);
      expect(vm.actividades.any((a) => a.titulo == 'Cena'), isTrue);
      expect(vm.advertencia, isNotNull);
      expect(vm.error, isNull);
      expect(
        vm.nombreResponsable(
          vm.actividades.firstWhere((a) => a.titulo == 'Cena'),
        ),
        'Ana',
      );
    });

    test('editar y eliminar', () async {
      final vm = crear();
      await pumpEventQueue();
      final a = vm.actividades.first;
      expect(
        await vm.editar(a, titulo: 'Nuevo', inicio: h(23), duracionMin: 10),
        isTrue,
      );
      await pumpEventQueue();
      expect(vm.actividades.last.titulo, 'Nuevo');
      expect(vm.advertencia, isNull);
      expect(await vm.eliminar(a.id), isTrue);
      await pumpEventQueue();
      expect(vm.actividades.length, 2);
    });

    test('validación con mensajes en español y sin guardar', () async {
      final vm = crear();
      await pumpEventQueue();
      Future<void> malo(
        String msg, {
        String t = 'ok',
        String d = '',
        int dur = 30,
        String? r,
      }) async {
        expect(
          await vm.agregar(
            titulo: t,
            descripcion: d,
            inicio: h(23),
            duracionMin: dur,
            responsableId: r,
          ),
          isFalse,
        );
        expect(vm.error, msg);
      }

      await malo('El título no puede estar vacío.', t: '  ');
      await malo('El título no puede pasar de 80 caracteres.', t: 'x' * 81);
      await malo(
        'La descripción no puede pasar de 500 caracteres.',
        d: 'x' * 501,
      );
      await malo('La duración debe estar entre 5 y 600 minutos.', dur: 4);
      await malo('La duración debe estar entre 5 y 600 minutos.', dur: 601);
      await malo('El responsable elegido no es un participante.', r: 'nadie');
      await pumpEventQueue();
      expect(vm.actividades.length, 3);
      // Límites exactos válidos.
      expect(
        await vm.agregar(
          titulo: 'x' * 80,
          descripcion: 'x' * 500,
          inicio: h(23),
          duracionMin: 5,
        ),
        isTrue,
      );
      expect(
        await vm.agregar(titulo: 'y', inicio: h(23), duracionMin: 600),
        isTrue,
      );
    });

    test('no admin: no puede agregar, editar ni eliminar', () async {
      final vm = crear(admin: false);
      await pumpEventQueue();
      const msg = 'Solo el organizador puede cambiar el itinerario.';
      expect(
        await vm.agregar(titulo: 'x', inicio: h(23), duracionMin: 30),
        isFalse,
      );
      expect(vm.error, msg);
      expect(
        await vm.editar(
          vm.actividades.first,
          titulo: 'x',
          inicio: h(23),
          duracionMin: 30,
        ),
        isFalse,
      );
      expect(await vm.eliminar('a'), isFalse);
      await pumpEventQueue();
      expect(vm.actividades.length, 3);
    });

    test('el temporizador notifica y se cancela en dispose', () async {
      var avisos = 0;
      final vm = ItinerarioViewModel(
        FakeItinerarioRepository(),
        esAdmin: true,
        refresco: const Duration(milliseconds: 10),
      )..addListener(() => avisos++);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final antes = avisos;
      expect(antes, greaterThan(1));
      vm.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(avisos, antes);
    });

    test('error del stream y participantes por stream', () async {
      final nombres = StreamController<Map<String, String>>();
      repo = FakeItinerarioRepository();
      final vm = ItinerarioViewModel(
        repo,
        esAdmin: true,
        ahora: () => reloj,
        participantes: nombres.stream,
      );
      await pumpEventQueue();
      expect(vm.vacio, isTrue);
      nombres.add({'u9': 'Zoe'});
      await pumpEventQueue();
      expect(vm.participantes, {'u9': 'Zoe'});
      repo.emitirError(StateError('x'));
      await pumpEventQueue();
      expect(vm.error, 'No pudimos cargar el itinerario. Intenta de nuevo.');
      vm.dispose();
      await nombres.close();
      expect(repo.escuchas, 0);
    });
  });
}
