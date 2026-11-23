import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/comida_opcion.dart';
import '../models/voto.dart';
import 'votacion_repository.dart';

/// Votación guardada en `comida_opciones`, `comida_votos` y `config/votacion`.
class FirestoreVotacionRepository implements VotacionRepository {
  FirestoreVotacionRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _opciones =>
      _db.collection('comida_opciones');
  CollectionReference<Map<String, dynamic>> get _votos =>
      _db.collection('comida_votos');
  DocumentReference<Map<String, dynamic>> get _config =>
      _db.collection('config').doc('votacion');

  /// Los errores de Firestore salen por el stream y el viewmodel los traduce.
  @override
  Stream<List<ComidaOpcion>> get opciones => _opciones.snapshots().map((s) {
    final lista = [
      for (final d in s.docs) ComidaOpcion.fromMap(d.id, d.data()),
    ];
    lista.sort((a, b) {
      final fa = a.creada, fb = b.creada;
      if (fa == null && fb == null) return 0;
      if (fa == null) return 1;
      if (fb == null) return -1;
      return fa.compareTo(fb);
    });
    return lista;
  });

  @override
  Stream<List<Voto>> get votos => _votos.snapshots().map(
    (s) => [for (final d in s.docs) Voto.fromMap(d.id, d.data())],
  );

  @override
  Stream<bool> get cerrada =>
      _config.snapshots().map((d) => d.data()?['cerrada'] == true);

  @override
  Future<void> proponer({
    required String nombre,
    required String descripcion,
    required String uid,
  }) async {
    final mapa = ComidaOpcion(
      id: '',
      nombre: nombre,
      descripcion: descripcion,
      propuestaPor: uid,
    ).toMap();
    mapa['creada'] = FieldValue.serverTimestamp();
    await _opciones.add(mapa);
  }

  @override
  Future<void> eliminarOpcion(String id) => _opciones.doc(id).delete();

  @override
  Future<void> votar(String uid, String opcionId) =>
      _votos.doc(uid).set(Voto(uid: uid, opcionId: opcionId).toMap());

  @override
  Future<void> quitarVoto(String uid) => _votos.doc(uid).delete();

  @override
  Future<void> fijarCerrada(bool cerrada) => _config.set({'cerrada': cerrada});
}
