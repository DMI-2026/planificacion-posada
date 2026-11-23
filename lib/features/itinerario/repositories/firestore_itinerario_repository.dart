import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/actividad.dart';
import 'itinerario_repository.dart';

/// Convierte los `DateTime` de un mapa del modelo en `Timestamp` (para escribir).
Map<String, Object?> mapaAFirestore(Map<String, Object?> mapa) => {
  for (final e in mapa.entries)
    e.key: e.value is DateTime
        ? Timestamp.fromDate(e.value! as DateTime)
        : e.value,
};

/// Convierte los `Timestamp` de un documento en `DateTime` (para leer).
Map<String, Object?> mapaDesdeFirestore(Map<String, dynamic> mapa) => {
  for (final e in mapa.entries)
    e.key: e.value is Timestamp ? (e.value as Timestamp).toDate() : e.value,
};

/// Itinerario guardado en la colección `itinerario`.
class FirestoreItinerarioRepository implements ItinerarioRepository {
  FirestoreItinerarioRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _coleccion =>
      _db.collection('itinerario');

  /// Los errores de Firestore salen por el stream y el viewmodel los traduce.
  @override
  Stream<List<Actividad>> get actividades => _coleccion.snapshots().map(
    (s) => [
      for (final d in s.docs)
        Actividad.fromMap(d.id, mapaDesdeFirestore(d.data())),
    ],
  );

  @override
  Future<void> agregar(Actividad actividad) async {
    await _coleccion.add(mapaAFirestore(actividad.toMap()));
  }

  @override
  Future<void> editar(Actividad actividad) =>
      _coleccion.doc(actividad.id).set(mapaAFirestore(actividad.toMap()));

  @override
  Future<void> eliminar(String id) => _coleccion.doc(id).delete();
}
