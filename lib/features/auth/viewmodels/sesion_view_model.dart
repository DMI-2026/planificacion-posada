import 'package:flutter/foundation.dart';

import '../../../core/validacion/limites.dart';
import '../../participantes/repositories/participante_repository.dart';
import '../models/usuario.dart';
import '../repositories/admin_repository.dart';

/// Quién es la persona con sesión y qué rol tiene (patrón Observer).
///
/// Al crearse (justo después de iniciar sesión o registrarse) hace dos cosas:
/// asegura su documento `participantes/{uid}` y resuelve si es admin.
class SesionViewModel extends ChangeNotifier {
  SesionViewModel({
    required this.usuario,
    required AdminRepository admins,
    required ParticipanteRepository participantes,
  }) {
    _iniciar(admins, participantes);
  }

  /// Sesión ya resuelta, sin tocar repositorios (pruebas y vistas sin nube).
  SesionViewModel.fija(this.usuario, {bool esAdmin = false})
    // ignore: prefer_initializing_formals
    : _esAdmin = esAdmin,
      _resolviendo = false;

  final Usuario usuario;

  bool _esAdmin = false;
  bool _resolviendo = true;
  bool _liberado = false;

  String get uid => usuario.id;

  /// Mientras se resuelve el rol cuenta como no admin.
  bool get esAdmin => _esAdmin;
  bool get resolviendo => _resolviendo;

  /// Nombre con el que aparece en la lista: el de la cuenta, o la parte del
  /// correo antes de la `@`; nunca vacío y nunca más largo que lo que acepta
  /// `firestore.rules`.
  static String nombreParaParticipante(Usuario usuario) {
    var nombre = usuario.nombre.trim();
    if (nombre.isEmpty) nombre = usuario.correo.split('@').first.trim();
    if (nombre.isEmpty) nombre = 'Participante';
    return nombre.length > Limites.nombreParticipante
        ? nombre.substring(0, Limites.nombreParticipante)
        : nombre;
  }

  Future<void> _iniciar(
    AdminRepository admins,
    ParticipanteRepository participantes,
  ) async {
    // Cada paso falla por separado: un error de red no debe tumbar la sesión.
    try {
      await participantes.asegurar(uid, nombreParaParticipante(usuario));
    } catch (_) {}
    try {
      _esAdmin = await admins.esAdmin(uid);
    } catch (_) {
      _esAdmin = false;
    }
    _resolviendo = false;
    if (!_liberado) notifyListeners();
  }

  @override
  void dispose() {
    _liberado = true;
    super.dispose();
  }
}
