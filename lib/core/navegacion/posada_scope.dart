import 'package:flutter/widgets.dart';

import '../../features/aportaciones/viewmodels/aportaciones_view_model.dart';
import '../../features/arbol/viewmodels/arbol_view_model.dart';
import '../../features/auth/viewmodels/sesion_view_model.dart';
import '../../features/evento/viewmodels/evento_view_model.dart';
import '../../features/intercambio/viewmodels/intercambio_view_model.dart';
import '../../features/itinerario/viewmodels/itinerario_view_model.dart';
import '../../features/participantes/viewmodels/participantes_view_model.dart';
import '../../features/votacion/viewmodels/votacion_view_model.dart';

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

/// Viewmodels de los módulos que dependen del rol (admin / participante).
///
/// Se crean de nuevo cuando cambia el rol, por eso viven aparte de
/// [PosadaScope]: las vistas toman su viewmodel de aquí en cada `build` y usan
/// `ObjectKey(vm)` para reiniciar su estado con el nuevo.
class ModulosScope extends InheritedWidget {
  const ModulosScope({
    super.key,
    required this.votacion,
    required this.itinerario,
    required this.arbol,
    required this.intercambio,
    required super.child,
  });

  final VotacionViewModel votacion;
  final ItinerarioViewModel itinerario;
  final ArbolViewModel arbol;
  final IntercambioViewModel intercambio;

  static ModulosScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ModulosScope>();
    assert(scope != null, 'No hay ModulosScope sobre este contexto');
    return scope!;
  }

  @override
  bool updateShouldNotify(ModulosScope old) =>
      votacion != old.votacion ||
      itinerario != old.itinerario ||
      arbol != old.arbol ||
      intercambio != old.intercambio;
}
