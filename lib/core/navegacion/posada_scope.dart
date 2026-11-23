import 'package:flutter/widgets.dart';

import '../../features/aportaciones/viewmodels/aportaciones_view_model.dart';
import '../../features/auth/viewmodels/sesion_view_model.dart';
import '../../features/evento/viewmodels/evento_view_model.dart';
import '../../features/participantes/viewmodels/participantes_view_model.dart';

/// Expone los viewmodels de la app a las vistas (`PosadaScope.of(context)`).
///
/// Un equipo que agregue una feature con su propio viewmodel puede añadirlo
/// aquí o crearlo dentro de su vista.
class PosadaScope extends InheritedWidget {
  const PosadaScope({
    super.key,
    required this.sesion,
    required this.evento,
    required this.participantes,
    required this.aportaciones,
    required super.child,
  });

  final SesionViewModel sesion;
  final EventoViewModel evento;
  final ParticipantesViewModel participantes;
  final AportacionesViewModel aportaciones;

  static PosadaScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PosadaScope>();
    assert(scope != null, 'No hay PosadaScope sobre este contexto');
    return scope!;
  }

  @override
  bool updateShouldNotify(PosadaScope old) =>
      sesion != old.sesion ||
      evento != old.evento ||
      participantes != old.participantes ||
      aportaciones != old.aportaciones;
}
