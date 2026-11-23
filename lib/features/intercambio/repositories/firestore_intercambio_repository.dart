import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/asignacion.dart';
import '../models/config_intercambio.dart';
import '../models/inscrito.dart';
import 'intercambio_repository.dart';

/// Intercambio guardado en `config/intercambio`, `intercambio_inscritos` e
/// `intercambio_asignaciones` (reglas en `intercambio.rules`).
class FirestoreIntercambioRepository implements IntercambioRepository {
  FirestoreIntercambioRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _config =>
      _db.collection('config').doc('intercambio');
  CollectionReference<Map<String, dynamic>> get _inscritos =>
      _db.collection('intercambio_inscritos');
  CollectionReference<Map<String, dynamic>> get _asignaciones =>
      _db.collection('intercambio_asignaciones');

  /// Los errores de Firestore salen por el stream y el viewmodel los traduce.
  @override
  Stream<ConfigIntercambio> get config =>
      _config.snapshots().map((d) => ConfigIntercambio.fromMap(d.data()));

  @override
  Stream<List<Inscrito>> get inscritos => _inscritos.snapshots().map(
    (s) => [for (final d in s.docs) Inscrito.fromMap(d.id, d.data())],
  );

  @override
  Stream<Asignacion?> miAsignacion(String uid) =>
      _asignaciones.doc(uid).snapshots().map((d) {
        final datos = d.data();
        return datos == null ? null : Asignacion.fromMap(d.id, datos);
      });

  @override
  Stream<List<Asignacion>> get asignaciones => _asignaciones.snapshots().map(
    (s) => [for (final d in s.docs) Asignacion.fromMap(d.id, d.data())],
  );

  @override
  Future<void> guardarInscrito(Inscrito inscrito) =>
      _inscritos.doc(inscrito.uid).set(inscrito.toMap());

  @override
  Future<void> eliminarInscrito(String uid) => _inscritos.doc(uid).delete();

  @override
  Future<void> guardarConfig(ConfigIntercambio config) =>
      _config.set(config.toMap());

  /// Un solo `WriteBatch` (tope de 500 operaciones: sobra para una posada).
  @override
  Future<void> publicarSorteo(
    List<Asignacion> asignaciones,
    ConfigIntercambio config,
  ) async {
    final previas = await _asignaciones.get();
    final nuevos = {for (final a in asignaciones) a.uid};
    final batch = _db.batch();
    for (final d in previas.docs) {
      if (!nuevos.contains(d.id)) batch.delete(d.reference);
    }
    for (final a in asignaciones) {
      batch.set(_asignaciones.doc(a.uid), a.toMap());
    }
    batch.set(_config, config.toMap());
    await batch.commit();
  }
}
