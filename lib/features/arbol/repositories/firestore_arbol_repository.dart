import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/adorno.dart';
import 'arbol_repository.dart';

/// Adornos guardados en la colección `arbol_adornos`.
class FirestoreArbolRepository implements ArbolRepository {
  FirestoreArbolRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _coleccion =>
      _db.collection('arbol_adornos');

  static DateTime? _fecha(Object? v) => v is Timestamp ? v.toDate() : null;

  /// Los errores de Firestore salen por el stream y el viewmodel los traduce.
  /// Los documentos mal formados se ignoran.
  @override
  Stream<List<Adorno>> get adornos => _coleccion.snapshots().map((s) {
    final lista = <Adorno>[];
    for (final d in s.docs) {
      final datos = d.data();
      try {
        lista.add(
          Adorno.fromMap(
            d.id,
            datos,
            creado: _fecha(datos['creado']),
            actualizado: _fecha(datos['actualizado']),
          ),
        );
      } on FormatException {
        continue;
      } on TypeError {
        continue;
      }
    }
    lista.sort((a, b) {
      final ca = a.creado, cb = b.creado;
      if (ca == null || cb == null) {
        return ca == cb ? 0 : (ca == null ? 1 : -1);
      }
      return ca.compareTo(cb);
    });
    return lista;
  });

  @override
  Future<void> crear(Adorno adorno) => _coleccion.doc(adorno.id).set({
    ...adorno.toMap(),
    'creado': FieldValue.serverTimestamp(),
    'actualizado': FieldValue.serverTimestamp(),
  });

  @override
  Future<void> mover(String id, double x, double y) => _coleccion
      .doc(id)
      .update({'x': x, 'y': y, 'actualizado': FieldValue.serverTimestamp()});

  @override
  Future<void> editar(Adorno adorno) => _coleccion.doc(adorno.id).update({
    'color': adorno.color,
    if (adorno.tipo == TipoAdorno.esfera) 'patron': adorno.patron!.clave,
    if (adorno.tipo == TipoAdorno.regalo) 'color_mono': adorno.colorMono,
    'mensaje': adorno.mensaje,
    'actualizado': FieldValue.serverTimestamp(),
  });

  @override
  Future<void> eliminar(String id) => _coleccion.doc(id).delete();
}
