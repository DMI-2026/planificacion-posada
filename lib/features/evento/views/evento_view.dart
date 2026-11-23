import '../../../core/validacion/limites.dart';

import 'package:flutter/material.dart';

import '../../../core/efectos/efectos.dart';
import '../../../core/format/formato_fecha.dart';
import '../../../core/navegacion/posada_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/estados.dart';
import '../../participantes/models/participante.dart';
import '../models/evento.dart';
import '../viewmodels/evento_view_model.dart';
import 'cuenta_regresiva.dart';

/// Pantalla "Inicio": datos del evento y resumen de la organización.
class EventoView extends StatelessWidget {
  const EventoView({super.key, this.ahora});

  /// Reloj inyectable para la cuenta regresiva (pruebas).
  final DateTime Function()? ahora;

  @override
  Widget build(BuildContext context) {
    final scope = PosadaScope.of(context);
    final vm = scope.evento;
    return ListenableBuilder(
      listenable: Listenable.merge([
        vm,
        scope.sesion,
        scope.participantes,
        scope.aportaciones,
      ]),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: vm.cargando || !vm.puedeEditar
              ? null
              : BotonBrillante(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => _DialogoEvento(vm: vm),
                  ),
                  icono: Icons.edit,
                  etiqueta: vm.evento == null
                      ? 'Crear evento'
                      : 'Editar evento',
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
    final hijos = <Widget>[
      if (vm.error != null) BannerError(mensaje: vm.error!),
      if (evento == null)
        SizedBox(
          height: 240,
          child: EstadoVacio(
            icono: Icons.celebration_outlined,
            mensaje: vm.puedeEditar
                ? 'Todavía no hay evento. Crea la posada de la clase.'
                : 'El organizador aún no ha definido el evento',
          ),
        )
      else ...[
        _Hero(evento: evento, ahora: ahora),
        const SizedBox(height: 12),
        _TarjetaDato(
          icono: Icons.event,
          etiqueta: 'Fecha',
          texto: formatearFechaHora(evento.fecha),
          acento: AppTheme.oro,
        ),
        if (evento.lugar.isNotEmpty)
          _TarjetaDato(
            icono: Icons.place,
            etiqueta: 'Lugar',
            texto: evento.lugar,
            acento: AppTheme.auroraTurquesa,
          ),
        if (evento.notas.isNotEmpty)
          _TarjetaDato(
            icono: Icons.notes,
            etiqueta: 'Notas',
            texto: evento.notas,
            acento: AppTheme.auroraMagenta,
          ),
      ],
      const SizedBox(height: 16),
      Text('Resumen', style: tema.textTheme.titleMedium),
      const SizedBox(height: 8),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Estadistica(
              clave: 'confirmados',
              etiqueta: 'Asistentes confirmados',
              valor: scope.participantes.conteo(Asistencia.si),
              acento: AppTheme.oro,
            ),
            _Estadistica(
              clave: 'pendientes',
              etiqueta: 'Aportaciones pendientes',
              valor: scope.aportaciones.pendientes,
              acento: AppTheme.auroraMagenta,
            ),
            _Estadistica(
              clave: 'listas',
              etiqueta: 'Aportaciones listas',
              valor: scope.aportaciones.listas,
              acento: AppTheme.auroraTurquesa,
            ),
          ],
        ),
      ),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: EntradaEscalonada.lista(hijos),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.evento, this.ahora});

  final Evento evento;
  final DateTime Function()? ahora;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return TarjetaCristal(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      inclinacion: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LucesNavidenas(),
          const SizedBox(height: 8),
          TituloMagico(
            evento.nombre,
            textAlign: TextAlign.center,
            estilo: tema.textTheme.headlineLarge?.copyWith(height: 1.15),
          ),
          const SizedBox(height: 16),
          CuentaRegresiva(fecha: evento.fecha, ahora: ahora),
        ],
      ),
    );
  }
}

class _TarjetaDato extends StatelessWidget {
  const _TarjetaDato({
    required this.icono,
    required this.etiqueta,
    required this.texto,
    required this.acento,
  });

  final IconData icono;
  final String etiqueta;
  final String texto;
  final Color acento;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TarjetaCristal(
        acento: acento,
        radio: 20,
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: acento.withValues(alpha: 0.18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(icono, size: 22, color: acento),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    etiqueta,
                    style: tema.textTheme.labelMedium?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(texto, style: tema.textTheme.bodyLarge),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Estadistica extends StatelessWidget {
  const _Estadistica({
    required this.clave,
    required this.etiqueta,
    required this.valor,
    required this.acento,
  });

  final String clave;
  final String etiqueta;
  final int valor;
  final Color acento;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: TarjetaCristal(
          key: ValueKey('estadistica-$clave'),
          acento: acento,
          radio: 20,
          inclinacion: false,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          child: Semantics(
            label: '$etiqueta: $valor',
            excludeSemantics: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ContadorAnimado(
                  valor: valor,
                  estilo: tema.textTheme.displaySmall?.copyWith(color: acento),
                ),
                const SizedBox(height: 4),
                Text(
                  etiqueta,
                  textAlign: TextAlign.center,
                  style: tema.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
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
