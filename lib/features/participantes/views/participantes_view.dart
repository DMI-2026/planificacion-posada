import '../../../core/validacion/limites.dart';

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
      listenable: vm,
      builder: (context, _) {
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _agregar(context, vm),
            icon: const Icon(Icons.person_add),
            label: const Text('Agregar participante'),
          ),
          body: _cuerpo(context, vm),
        );
      },
    );
  }

  Widget _cuerpo(BuildContext context, ParticipantesViewModel vm) {
    if (vm.cargando) return const EstadoCargando();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Text('Participantes', style: Theme.of(context).textTheme.headlineSmall),
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
              mensaje: 'Aún no hay participantes. ¡Agrega al primero!',
            ),
          ),
        for (final p in vm.participantes)
          Card(
            key: ValueKey('participante-${p.id}'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.nombre,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Eliminar ${p.nombre}',
                        icon: const Icon(Icons.delete_outline),
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
                    onSelectionChanged: (s) =>
                        vm.cambiarAsistencia(p.id, s.first),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _agregar(BuildContext context, ParticipantesViewModel vm) {
    return showDialog<void>(
      context: context,
      builder: (_) => _DialogoParticipante(vm: vm),
    );
  }
}

class _DialogoParticipante extends StatefulWidget {
  const _DialogoParticipante({required this.vm});

  final ParticipantesViewModel vm;

  @override
  State<_DialogoParticipante> createState() => _DialogoParticipanteState();
}

class _DialogoParticipanteState extends State<_DialogoParticipante> {
  final _nombre = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final ok = await widget.vm.agregar(_nombre.text);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _error = widget.vm.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo participante'),
      content: TextField(
        controller: _nombre,
        maxLength: Limites.nombreParticipante,
        autofocus: true,
        decoration: InputDecoration(labelText: 'Nombre', errorText: _error),
        onSubmitted: (_) => _guardar(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}
