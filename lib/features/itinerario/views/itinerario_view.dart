import 'package:flutter/material.dart';

import '../../../core/efectos/efectos.dart';
import '../../../core/theme/app_theme.dart';
import '../models/actividad.dart';
import '../viewmodels/itinerario_view_model.dart';

String _hora(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _duracion(int min) {
  final h = min ~/ 60, m = min % 60;
  if (h == 0) return '$m min';
  return m == 0 ? '$h h' : '$h h $m min';
}

/// Itinerario de la posada como línea de tiempo vertical «noche mágica».
class ItinerarioView extends StatelessWidget {
  const ItinerarioView({super.key, required this.viewModel});

  final ItinerarioViewModel viewModel;

  Future<void> _abrirFormulario(BuildContext context, [Actividad? actividad]) =>
      showDialog<void>(
        context: context,
        builder: (_) =>
            _FormularioActividad(viewModel: viewModel, actividad: actividad),
      );

  Future<void> _confirmarBorrado(BuildContext context, Actividad a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar actividad'),
        content: Text('¿Quitar «${a.titulo}» del itinerario?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) await viewModel.eliminar(a.id);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final vm = viewModel;
        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: vm.esAdmin
              ? FloatingActionButton.extended(
                  onPressed: () => _abrirFormulario(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar actividad'),
                )
              : null,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                const TituloMagico(
                  'Itinerario de la posada',
                  estilo: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    fontFamily: AppTheme.fuenteTitulos,
                  ),
                ),
                const SizedBox(height: 8),
                if (vm.actividades.isNotEmpty)
                  Text(
                    '${vm.actividades.length} actividades · '
                    '${_duracion(vm.duracionTotal.inMinutes)} en total',
                    style: const TextStyle(color: AppTheme.textoSuave),
                  ),
                const SizedBox(height: 16),
                if (vm.error != null) _Aviso(vm.error!, error: true),
                if (vm.advertencia != null) _Aviso(vm.advertencia!),
                if (vm.cargando)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (vm.vacio)
                  const _Vacio()
                else
                  for (var i = 0; i < vm.actividades.length; i++)
                    EntradaEscalonada(
                      indice: i,
                      child: _FilaActividad(
                        actividad: vm.actividades[i],
                        estado: vm.estadoDe(vm.actividades[i]),
                        responsable: vm.nombreResponsable(vm.actividades[i]),
                        solapada: vm.idsConSolape.contains(
                          vm.actividades[i].id,
                        ),
                        primera: i == 0,
                        ultima: i == vm.actividades.length - 1,
                        onEditar: vm.esAdmin
                            ? () => _abrirFormulario(context, vm.actividades[i])
                            : null,
                        onEliminar: vm.esAdmin
                            ? () =>
                                  _confirmarBorrado(context, vm.actividades[i])
                            : null,
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso(this.texto, {this.error = false});
  final String texto;
  final bool error;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Semantics(
      liveRegion: true,
      child: Row(
        children: [
          Icon(
            error ? Icons.error_outline : Icons.warning_amber_rounded,
            color: error ? const Color(0xFFFF8A95) : AppTheme.oro,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                color: error ? const Color(0xFFFF8A95) : AppTheme.oro,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Vacio extends StatelessWidget {
  const _Vacio();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 48),
    child: Column(
      children: [
        Text('🎄', style: TextStyle(fontSize: 56)),
        SizedBox(height: 12),
        Text(
          'Aún no hay actividades. ¡La noche promete magia!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: AppTheme.textoSuave),
        ),
      ],
    ),
  );
}

class _FilaActividad extends StatelessWidget {
  const _FilaActividad({
    required this.actividad,
    required this.estado,
    required this.responsable,
    required this.solapada,
    required this.primera,
    required this.ultima,
    this.onEditar,
    this.onEliminar,
  });

  final Actividad actividad;
  final EstadoActividad estado;
  final String? responsable;
  final bool solapada;
  final bool primera;
  final bool ultima;
  final VoidCallback? onEditar;
  final VoidCallback? onEliminar;

  @override
  Widget build(BuildContext context) {
    final pasada = estado == EstadoActividad.pasada;
    final enCurso = estado == EstadoActividad.enCurso;
    final color = enCurso
        ? AppTheme.auroraTurquesa
        : estado == EstadoActividad.siguiente
        ? AppTheme.oro
        : pasada
        ? AppTheme.textoSuave
        : AppTheme.auroraMagenta;
    final a = actividad;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 52,
            child: Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Text(
                _hora(a.inicio),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: pasada ? AppTheme.textoSuave : AppTheme.texto,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 32,
            child: CustomPaint(
              painter: _LineaPainter(
                color: color,
                primera: primera,
                ultima: ultima,
              ),
              child: Align(
                alignment: const Alignment(0, -0.85),
                child: _Punto(color: color, pulsa: enCurso),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Opacity(
                opacity: pasada ? 0.6 : 1,
                child: TarjetaCristal(
                  acento: color,
                  inclinacion: false,
                  radio: 20,
                  padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  a.titulo,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.texto,
                                  ),
                                ),
                                if (enCurso) _Insignia('En curso', color),
                                if (estado == EstadoActividad.siguiente)
                                  _Insignia('Siguiente', color),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_hora(a.inicio)} – ${_hora(a.fin)} · ${_duracion(a.duracionMin)}',
                              style: const TextStyle(
                                color: AppTheme.textoSuave,
                              ),
                            ),
                            if (a.descripcion.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                a.descripcion,
                                style: const TextStyle(color: AppTheme.texto),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              responsable == null
                                  ? 'Sin responsable'
                                  : 'Responsable: $responsable',
                              style: const TextStyle(
                                color: AppTheme.textoSuave,
                              ),
                            ),
                            if (solapada)
                              const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      size: 16,
                                      color: AppTheme.oro,
                                    ),
                                    SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        'Se traslapa con otra actividad',
                                        style: TextStyle(
                                          color: AppTheme.oro,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (onEditar != null)
                        IconButton(
                          tooltip: 'Editar ${a.titulo}',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: onEditar,
                        ),
                      if (onEliminar != null)
                        IconButton(
                          tooltip: 'Eliminar ${a.titulo}',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: onEliminar,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Insignia extends StatelessWidget {
  const _Insignia(this.texto, this.color);
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.18),
      border: Border.all(color: color),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      texto,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}

/// Punto de la línea de tiempo; pulsa cuando la actividad está en curso.
class _Punto extends StatefulWidget {
  const _Punto({required this.color, required this.pulsa});
  final Color color;
  final bool pulsa;

  @override
  State<_Punto> createState() => _PuntoState();
}

class _PuntoState extends State<_Punto> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sincronizar();
  }

  @override
  void didUpdateWidget(_Punto anterior) {
    super.didUpdateWidget(anterior);
    _sincronizar();
  }

  void _sincronizar() {
    if (widget.pulsa && !movimientoReducido(context)) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) {
      final p = widget.pulsa ? 0.5 + 0.5 * _c.value : 0.4;
      return Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.6 * p),
              blurRadius: 6 + 12 * p,
              spreadRadius: 1 + 4 * p * (widget.pulsa ? 1 : 0),
            ),
          ],
        ),
      );
    },
  );
}

class _LineaPainter extends CustomPainter {
  const _LineaPainter({
    required this.color,
    required this.primera,
    required this.ultima,
  });
  final Color color;
  final bool primera;
  final bool ultima;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final y0 = primera ? size.height * 0.07 : 0.0;
    final y1 = ultima ? size.height * 0.07 + 8 : size.height;
    final brillo = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final trazo = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(x, y0), Offset(x, y1), brillo);
    canvas.drawLine(Offset(x, y0), Offset(x, y1), trazo);
  }

  @override
  bool shouldRepaint(_LineaPainter o) =>
      o.color != color || o.primera != primera || o.ultima != ultima;
}

class _FormularioActividad extends StatefulWidget {
  const _FormularioActividad({required this.viewModel, this.actividad});
  final ItinerarioViewModel viewModel;
  final Actividad? actividad;

  @override
  State<_FormularioActividad> createState() => _FormularioActividadState();
}

class _FormularioActividadState extends State<_FormularioActividad> {
  late final TextEditingController _titulo;
  late final TextEditingController _descripcion;
  late final TextEditingController _duracion;
  late DateTime _inicio;
  String? _responsable;
  String? _error;

  @override
  void initState() {
    super.initState();
    final a = widget.actividad;
    _titulo = TextEditingController(text: a?.titulo ?? '');
    _descripcion = TextEditingController(text: a?.descripcion ?? '');
    _duracion = TextEditingController(text: '${a?.duracionMin ?? 30}');
    final ahora = DateTime.now();
    _inicio = a?.inicio ?? DateTime(ahora.year, ahora.month, ahora.day, 19);
    _responsable = widget.viewModel.participantes.containsKey(a?.responsableId)
        ? a?.responsableId
        : null;
  }

  @override
  void dispose() {
    _titulo.dispose();
    _descripcion.dispose();
    _duracion.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final f = await showDatePicker(
      context: context,
      initialDate: _inicio,
      firstDate: DateTime(_inicio.year - 1),
      lastDate: DateTime(_inicio.year + 2),
    );
    if (f != null) {
      setState(
        () => _inicio = DateTime(
          f.year,
          f.month,
          f.day,
          _inicio.hour,
          _inicio.minute,
        ),
      );
    }
  }

  Future<void> _elegirHora() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_inicio),
    );
    if (t != null) {
      setState(
        () => _inicio = DateTime(
          _inicio.year,
          _inicio.month,
          _inicio.day,
          t.hour,
          t.minute,
        ),
      );
    }
  }

  Future<void> _guardar() async {
    final vm = widget.viewModel;
    final dur = int.tryParse(_duracion.text.trim());
    if (dur == null) {
      setState(() => _error = 'La duración debe ser un número de minutos.');
      return;
    }
    final a = widget.actividad;
    final ok = a == null
        ? await vm.agregar(
            titulo: _titulo.text,
            descripcion: _descripcion.text,
            inicio: _inicio,
            duracionMin: dur,
            responsableId: _responsable,
          )
        : await vm.editar(
            a,
            titulo: _titulo.text,
            descripcion: _descripcion.text,
            inicio: _inicio,
            duracionMin: dur,
            responsableId: _responsable,
          );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _error = vm.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombres = widget.viewModel.participantes;
    final loc = MaterialLocalizations.of(context);
    return AlertDialog(
      title: Text(
        widget.actividad == null ? 'Agregar actividad' : 'Editar actividad',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titulo,
              decoration: const InputDecoration(labelText: 'Título'),
              maxLength: LimitesItinerario.tituloMax,
            ),
            TextField(
              controller: _descripcion,
              decoration: const InputDecoration(labelText: 'Descripción'),
              maxLines: 3,
              maxLength: LimitesItinerario.descripcionMax,
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _elegirFecha,
                    icon: const Icon(Icons.event),
                    label: Text(loc.formatShortDate(_inicio)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _elegirHora,
                    icon: const Icon(Icons.schedule),
                    label: Text(_hora(_inicio)),
                  ),
                ),
              ],
            ),
            TextField(
              controller: _duracion,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Duración (minutos)',
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: _responsable,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Responsable'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Sin responsable'),
                ),
                for (final e in nombres.entries)
                  DropdownMenuItem<String?>(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _responsable = v),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFFF8A95)),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.viewModel.limpiarMensajes();
            Navigator.pop(context);
          },
          child: const Text('Cancelar'),
        ),
        BotonBrillante(onPressed: _guardar, etiqueta: 'Guardar'),
      ],
    );
  }
}
