import '../../../core/validacion/limites.dart';

import 'package:flutter/material.dart';

import '../../../core/format/formato_fecha.dart';
import '../../../core/navegacion/posada_scope.dart';
import '../../../core/widgets/estados.dart';
import '../../participantes/models/participante.dart';
import '../models/evento.dart';
import '../viewmodels/evento_view_model.dart';

/// Pantalla "Inicio": datos del evento y resumen de la organización.
class EventoView extends StatelessWidget {
  const EventoView({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = PosadaScope.of(context);
    final vm = scope.evento;
    return ListenableBuilder(
      listenable: Listenable.merge([
        vm,
        scope.participantes,
        scope.aportaciones,
      ]),
      builder: (context, _) {
        return Scaffold(
          floatingActionButton: vm.cargando
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => _DialogoEvento(vm: vm),
                  ),
                  icon: const Icon(Icons.edit),
                  label: Text(
                    vm.evento == null ? 'Crear evento' : 'Editar evento',
                  ),
                ),
          body: _cuerpo(context, scope),
        );
      },
    );
  }

  Widget _cuerpo(BuildContext context, PosadaScope scope) {
    final vm = scope.evento;
    if (vm.cargando) return const EstadoCargando();
    final tema = Theme.of(context);
    final evento = vm.evento;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        if (vm.error != null) BannerError(mensaje: vm.error!),
        if (evento == null)
          const SizedBox(
            height: 240,
            child: EstadoVacio(
              icono: Icons.celebration_outlined,
              mensaje: 'Todavía no hay evento. Crea la posada de la clase.',
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(evento.nombre, style: tema.textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  _Dato(
                    icono: Icons.event,
                    texto: formatearFechaHora(evento.fecha),
                  ),
                  if (evento.lugar.isNotEmpty)
                    _Dato(icono: Icons.place, texto: evento.lugar),
                  if (evento.notas.isNotEmpty)
                    _Dato(icono: Icons.notes, texto: evento.notas),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text('Resumen', style: tema.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChipConteo(
              etiqueta: 'Asistentes confirmados',
              valor: scope.participantes.conteo(Asistencia.si),
            ),
            ChipConteo(
              etiqueta: 'Aportaciones pendientes',
              valor: scope.aportaciones.pendientes,
            ),
            ChipConteo(
              etiqueta: 'Aportaciones listas',
              valor: scope.aportaciones.listas,
            ),
          ],
        ),
      ],
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }
}

class _DialogoEvento extends StatefulWidget {
  const _DialogoEvento({required this.vm});

  final EventoViewModel vm;

  @override
  State<_DialogoEvento> createState() => _DialogoEventoState();
}

class _DialogoEventoState extends State<_DialogoEvento> {
  late final TextEditingController _nombre;
  late final TextEditingController _lugar;
  late final TextEditingController _notas;
  late DateTime _fecha;
  String? _error;

  @override
  void initState() {
    super.initState();
    final Evento? e = widget.vm.evento;
    _nombre = TextEditingController(text: e?.nombre ?? '');
    _lugar = TextEditingController(text: e?.lugar ?? '');
    _notas = TextEditingController(text: e?.notas ?? '');
    _fecha = e?.fecha ?? DateTime.now().add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _nombre.dispose();
    _lugar.dispose();
    _notas.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final dia = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (dia == null || !mounted) return;
    setState(
      () => _fecha = DateTime(
        dia.year,
        dia.month,
        dia.day,
        _fecha.hour,
        _fecha.minute,
      ),
    );
  }

  Future<void> _elegirHora() async {
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fecha),
    );
    if (hora == null || !mounted) return;
    setState(
      () => _fecha = DateTime(
        _fecha.year,
        _fecha.month,
        _fecha.day,
        hora.hour,
        hora.minute,
      ),
    );
  }

  Future<void> _guardar() async {
    final ok = await widget.vm.guardar(
      nombre: _nombre.text,
      fecha: _fecha,
      lugar: _lugar.text,
      notas: _notas.text,
    );
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
      title: const Text('Datos del evento'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nombre,
              maxLength: Limites.nombreEvento,
              decoration: InputDecoration(
                labelText: 'Nombre',
                errorText: _error,
                errorMaxLines: 3,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _elegirFecha,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(formatearFechaHora(_fecha).substring(0, 10)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _elegirHora,
                    icon: const Icon(Icons.schedule),
                    label: Text(formatearFechaHora(_fecha).substring(11)),
                  ),
                ),
              ],
            ),
            TextField(
              controller: _lugar,
              maxLength: Limites.lugarEvento,
              decoration: const InputDecoration(labelText: 'Lugar'),
            ),
            TextField(
              controller: _notas,
              maxLength: Limites.notasEvento,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notas'),
            ),
          ],
        ),
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
