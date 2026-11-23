import 'admin_repository.dart';

/// Roles en memoria para pruebas y para trabajar sin nube.
class FakeAdminRepository implements AdminRepository {
  FakeAdminRepository({Set<String> admins = const {}, this.falla = false})
    : _admins = {...admins};

  final Set<String> _admins;

  /// Si es `true`, [esAdmin] lanza (simula un error de lectura).
  bool falla;

  @override
  Future<bool> esAdmin(String uid) async {
    if (falla) throw Exception('sin acceso a admins');
    return _admins.contains(uid);
  }
}
