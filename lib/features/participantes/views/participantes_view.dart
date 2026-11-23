import 'package:flutter/material.dart';

import '../../../core/navegacion/posada_scope.dart';
import '../../../core/widgets/estados.dart';
import '../models/participante.dart';
import '../viewmodels/participantes_view_model.dart';

String _etiqueta(Asistencia a) => switch (a) {
  Asistencia.si => 'Sí',
  Asistencia.talVez => 'Tal vez',
  Asistencia.no => 'No',
};

/// Lista de participantes con su asistencia.
class ParticipantesView extends StatelessWidget {
  const ParticipantesView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = PosadaScope.of(context).participantes;
    return ListenableBuilder(
      listenable: Listenable.merge([vm, vm.sesion]),
      builder: (context, _) => Scaffold(body: _cuerpo(context, vm)),
    );
  }

  Widget _cuerpo(BuildContext context, ParticipantesViewModel vm) {
    if (vm.cargando) return const EstadoCargando();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Participantes', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Aquí aparece cada persona que se registró en la app.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (vm.sesion.esAdmin)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                avatar: Icon(Icons.verified_user, size: 18),
                label: Text('Eres admin'),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final a in Asistencia.values)
              ChipConteo(etiqueta: _etiqueta(a), valor: vm.conteo(a)),
          ],
        ),
        if (vm.error != null) BannerError(mensaje: vm.error!),
        if (vm.vacio)
          const SizedBox(
            height: 240,
            child: EstadoVacio(
              icono: Icons.group_outlined,
              mensaje: 'Aún no hay participantes registrados.',
            ),
          ),
        for (final p in vm.participantes)
          Card(
            key: ValueKey('participante-${p.id}'),
            color: vm.esYo(p.id)
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          vm.esYo(p.id) ? '${p.nombre} (Tú)' : p.nombre,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (vm.puedeEliminar)
                        IconButton(
                          tooltip: 'Quitar a ${p.nombre} de la lista',
                          icon: const Icon(Icons.person_remove_outlined),
                          onPressed: () async {
                            if (await confirmarEliminar(context, p.nombre)) {
                              await vm.eliminar(p.id);
                            }
                          },
                        ),
                    ],
                  ),
                  SegmentedButton<Asistencia>(
                    showSelectedIcon: false,
                    segments: [
                      for (final a in Asistencia.values)
                        ButtonSegment(value: a, label: Text(_etiqueta(a))),
                    ],
                    selected: {p.asistencia},
                    onSelectionChanged: vm.puedeCambiarAsistencia(p.id)
                        ? (s) => vm.cambiarAsistencia(p.id, s.first)
                        : null,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
