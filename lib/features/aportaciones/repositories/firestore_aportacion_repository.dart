import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/aportacion.dart';
import 'aportacion_repository.dart';

/// Aportaciones guardadas en la colección `aportaciones`; la meta, en el
/// documento `config/aportaciones`.
class FirestoreAportacionRepository implements AportacionRepository {
  FirestoreAportacionRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _coleccion =>
      _db.collection('aportaciones');

  DocumentReference<Map<String, dynamic>> get _docMeta =>
      _db.collection('config').doc('aportaciones');

  /// Los errores de Firestore salen por el stream y el viewmodel los traduce.
  @override
  Stream<List<Aportacion>> get aportaciones => _coleccion.snapshots().map((s) {
    final lista = [for (final d in s.docs) Aportacion.fromMap(d.id, d.data())];
    lista.sort((a, b) {
      // Materiales por artículo; económicas por monto (mayor primero).
      if (a.tipo != b.tipo) return a.tipo.index.compareTo(b.tipo.index);
      if (a.esEconomica) return b.montoCentavos.compareTo(a.montoCentavos);
      return a.articulo.toLowerCase().compareTo(b.articulo.toLowerCase());
    });
    return lista;
  });

  @override
  Stream<int?> get meta => _docMeta.snapshots().map(
    (s) => (s.data()?['meta_centavos'] as num?)?.toInt(),
  );

  @override
  Future<void> agregar(String articulo, int cantidad) async {
    await _coleccion.add(
      Aportacion(id: '', articulo: articulo, cantidad: cantidad).toMap(),
    );
  }

  @override
  Future<void> agregarEconomica(String responsableId, int montoCentavos) async {
    await _coleccion.add(
      Aportacion.economica(
        id: '',
        responsableId: responsableId,
        montoCentavos: montoCentavos,
      ).toMap(),
    );
  }

  @override
  Future<void> asignar(String id, String? responsableId) =>
      _coleccion.doc(id).update({'responsable_id': responsableId});

  @override
  Future<void> marcarLista(String id, bool lista) =>
      _coleccion.doc(id).update({'lista': lista});

  @override
  Future<void> editarMonto(String id, int montoCentavos) =>
      _coleccion.doc(id).update({'monto_centavos': montoCentavos});

  @override
  Future<void> marcarRecibido(String id, bool recibido) =>
      _coleccion.doc(id).update({'recibido': recibido});

  @override
  Future<void> guardarMeta(int? centavos) =>
      _docMeta.set({'meta_centavos': centavos});

  @override
  Future<void> eliminar(String id) => _coleccion.doc(id).delete();
}
