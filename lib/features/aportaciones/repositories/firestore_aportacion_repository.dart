import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/aportacion.dart';
import 'aportacion_repository.dart';

/// Aportaciones guardadas en la colección `aportaciones`.
class FirestoreAportacionRepository implements AportacionRepository {
  FirestoreAportacionRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _coleccion =>
      _db.collection('aportaciones');

  /// Los errores de Firestore salen por el stream y el viewmodel los traduce.
  @override
  Stream<List<Aportacion>> get aportaciones => _coleccion.snapshots().map((s) {
    final lista = [for (final d in s.docs) Aportacion.fromMap(d.id, d.data())];
    lista.sort(
      (a, b) => a.articulo.toLowerCase().compareTo(b.articulo.toLowerCase()),
    );
    return lista;
  });

  @override
  Future<void> agregar(String articulo, int cantidad) async {
    await _coleccion.add(
      Aportacion(id: '', articulo: articulo, cantidad: cantidad).toMap(),
    );
  }

  @override
  Future<void> asignar(String id, String? responsableId) =>
      _coleccion.doc(id).update({'responsable_id': responsableId});

  @override
  Future<void> marcarLista(String id, bool lista) =>
      _coleccion.doc(id).update({'lista': lista});

  @override
  Future<void> eliminar(String id) => _coleccion.doc(id).delete();
}
