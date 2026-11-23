import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_repository.dart';

/// Roles leídos de la colección `admins` (solo se puede leer el propio).
class FirestoreAdminRepository implements AdminRepository {
  FirestoreAdminRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Future<bool> esAdmin(String uid) async =>
      (await _db.collection('admins').doc(uid).get()).exists;
}
