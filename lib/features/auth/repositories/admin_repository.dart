/// Consulta de roles (patrón Repository).
///
/// Un admin es quien tiene un documento `admins/{uid}`. Ese documento se crea
/// a mano (consola de Firebase o interfaz del emulador); la app nunca lo escribe.
abstract class AdminRepository {
  /// `true` si existe `admins/{uid}`. Lanza si no se puede leer.
  Future<bool> esAdmin(String uid);
}
