import 'package:flutter/material.dart';

import '../../features/aportaciones/views/aportaciones_view.dart';
import '../../features/arbol/views/arbol_view.dart';
import '../../features/auth/viewmodels/sesion_view_model.dart';
import '../../features/cohetazo/views/cohetazo_view.dart';
import '../../features/evento/views/evento_view.dart';
import '../../features/intercambio/views/intercambio_view.dart';
import '../../features/itinerario/views/itinerario_view.dart';
import '../../features/participantes/views/participantes_view.dart';
import '../../features/votacion/views/votacion_view.dart';
import 'posada_scope.dart';

/// Una sección de la app que aparece en la navegación.
class DestinoFeature {
  const DestinoFeature({
    required this.etiqueta,
    required this.icono,
    required this.iconoSeleccionado,
    required this.builder,
  });

  final String etiqueta;
  final IconData icono;
  final IconData iconoSeleccionado;
  final WidgetBuilder builder;
}

/// Lista única de destinos. Para agregar una feature, añade UNA entrada aquí.
final List<DestinoFeature> destinos = [
  DestinoFeature(
    etiqueta: 'Inicio',
    icono: Icons.celebration_outlined,
    iconoSeleccionado: Icons.celebration,
    builder: (_) => const EventoView(),
  ),
  DestinoFeature(
    etiqueta: 'Participantes',
    icono: Icons.group_outlined,
    iconoSeleccionado: Icons.group,
    builder: (_) => const ParticipantesView(),
  ),
  DestinoFeature(
    etiqueta: 'Comida',
    icono: Icons.restaurant_outlined,
    iconoSeleccionado: Icons.restaurant,
    builder: (context) {
      final vm = ModulosScope.of(context).votacion;
      return VotacionView(key: ObjectKey(vm), viewModel: vm);
    },
  ),
  DestinoFeature(
    etiqueta: 'Itinerario',
    icono: Icons.event_note_outlined,
    iconoSeleccionado: Icons.event_note,
    builder: (context) {
      final vm = ModulosScope.of(context).itinerario;
      return ItinerarioView(key: ObjectKey(vm), viewModel: vm);
    },
  ),
  DestinoFeature(
    etiqueta: 'Aportaciones',
    icono: Icons.shopping_basket_outlined,
    iconoSeleccionado: Icons.shopping_basket,
    builder: (_) => const AportacionesView(),
  ),
  DestinoFeature(
    etiqueta: 'Árbol',
    icono: Icons.park_outlined,
    iconoSeleccionado: Icons.park,
    builder: (context) {
      final vm = ModulosScope.of(context).arbol;
      return ArbolView(key: ObjectKey(vm), viewModel: vm);
    },
  ),
  DestinoFeature(
    etiqueta: 'Intercambio',
    icono: Icons.card_giftcard_outlined,
    iconoSeleccionado: Icons.card_giftcard,
    builder: (context) {
      final vm = ModulosScope.of(context).intercambio;
      return IntercambioView(key: ObjectKey(vm), viewModel: vm);
    },
  ),
  DestinoFeature(
    etiqueta: 'Cohetazo',
    icono: Icons.rocket_launch_outlined,
    iconoSeleccionado: Icons.rocket_launch,
    builder: (context) {
      final scope = PosadaScope.of(context);
      return CohetazoView(
        key: ValueKey(scope.sesion.uid),
        uid: scope.sesion.uid,
        nombre: SesionViewModel.nombreParaParticipante(scope.sesion.usuario),
        crearRepositorio: scope.crearRepositorioCohetazo,
      );
    },
  ),
];
