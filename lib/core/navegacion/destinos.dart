import 'package:flutter/material.dart';

import '../../features/aportaciones/views/aportaciones_view.dart';
import '../../features/evento/views/evento_view.dart';
import '../../features/participantes/views/participantes_view.dart';

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
    etiqueta: 'Aportaciones',
    icono: Icons.shopping_basket_outlined,
    iconoSeleccionado: Icons.shopping_basket,
    builder: (_) => const AportacionesView(),
  ),
];
