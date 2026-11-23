import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/participante.dart';
import 'participante_repository.dart';

/// Participantes guardados en la colección `participantes`.
class FirestoreParticipanteRepository implements ParticipanteRepository {
  FirestoreParticipanteRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _coleccion =>
      _db.collection('participantes');

  /// Los errores de Firestore salen por el stream y el viewmodel los traduce.
  @override
  Stream<List<Participante>> get participantes =>
      _coleccion.snapshots().map((s) {
        final lista = [
          for (final d in s.docs) Participante.fromMap(d.id, d.data()),
        ];
        lista.sort(
          (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
        );
        return lista;
      });

  @override
  Future<void> asegurar(String uid, String nombre) async {
    final doc = _coleccion.doc(uid);
    if ((await doc.get()).exists) return;
    await doc.set(Participante(id: uid, nombre: nombre).toMap());
  }

  @override
  Future<void> cambiarAsistencia(String id, Asistencia asistencia) =>
      _coleccion.doc(id).update({'asistencia': asistencia.json});

  @override
  Future<void> eliminar(String id) => _coleccion.doc(id).delete();
}
