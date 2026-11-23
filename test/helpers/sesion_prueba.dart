import 'package:planificacion_posada/features/auth/models/usuario.dart';
import 'package:planificacion_posada/features/auth/viewmodels/sesion_view_model.dart';

/// Sesión ya resuelta para probar viewmodels: `u-1` como admin o no.
SesionViewModel sesionPrueba({bool admin = false, String uid = 'u-1'}) =>
    SesionViewModel.fija(
      Usuario(id: uid, correo: '$uid@posada.mx', nombre: 'Ana'),
      esAdmin: admin,
    );
