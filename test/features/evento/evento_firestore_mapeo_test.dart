import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planificacion_posada/features/evento/models/evento.dart';
import 'package:planificacion_posada/features/evento/repositories/firestore_evento_repository.dart';

void main() {
  final fecha = DateTime(2026, 12, 18, 18);

  test('eventoAMapa convierte la fecha a Timestamp', () {
    final mapa = eventoAMapa(
      Evento(nombre: 'Posada', fecha: fecha, lugar: 'Salón', notas: 'n'),
    );
    expect(mapa.keys.toSet(), {'nombre', 'fecha', 'lugar', 'notas'});
    expect(mapa['fecha'], Timestamp.fromDate(fecha));
  });

  test('eventoDesdeMapa convierte Timestamp a DateTime', () {
    final evento = eventoDesdeMapa({
      'nombre': 'Posada',
      'fecha': Timestamp.fromDate(fecha),
      'lugar': 'Salón',
      'notas': 'n',
    });
    expect(evento.fecha, fecha);
    expect(evento.nombre, 'Posada');
    expect(evento.lugar, 'Salón');
  });

  test('ida y vuelta conserva el evento y tolera lugar/notas ausentes', () {
    final e = eventoDesdeMapa({
      'nombre': 'P',
      'fecha': Timestamp.fromDate(fecha),
    });
    expect(e.lugar, '');
    expect(e.notas, '');
    expect(eventoDesdeMapa(eventoAMapa(e)).fecha, fecha);
  });
}
