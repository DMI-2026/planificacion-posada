import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/evento.dart';
import 'evento_repository.dart';

/// Mapa de Firestore: `fecha` viaja como [Timestamp].
Map<String, dynamic> eventoAMapa(Evento evento) => {
  ...evento.toMap(),
  'fecha': Timestamp.fromDate(evento.fecha),
};

/// Inversa de [eventoAMapa]: convierte `Timestamp` a [DateTime].
Evento eventoDesdeMapa(Map<String, dynamic> mapa) =>
    Evento.fromMap({...mapa, 'fecha': (mapa['fecha'] as Timestamp).toDate()});

/// Evento guardado en el documento `evento/actual`.
class FirestoreEventoRepository implements EventoRepository {
  FirestoreEventoRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection('evento').doc('actual');

  /// Los errores de Firestore salen por el stream y el viewmodel los traduce.
  @override
  Stream<Evento?> get evento => _doc.snapshots().map((s) {
    final datos = s.data();
    return s.exists && datos != null ? eventoDesdeMapa(datos) : null;
  });

  @override
  Future<void> guardar(Evento evento) => _doc.set(eventoAMapa(evento));
}
