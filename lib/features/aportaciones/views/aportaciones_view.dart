import 'package:flutter/material.dart';

import '../../../core/efectos/efectos.dart';
import '../../../core/navegacion/posada_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/validacion/limites.dart';
import '../../../core/widgets/estados.dart';
import '../../participantes/models/participante.dart';
import '../models/aportacion.dart';
import '../utils/dinero.dart';
import '../viewmodels/aportaciones_view_model.dart';

/// Aportaciones de la posada: material (qué lleva cada quien) y económicas
/// (dinero para la meta).
class AportacionesView extends StatefulWidget {
  const AportacionesView({super.key});

  @override
  State<AportacionesView> createState() => _AportacionesViewState();
}

class _AportacionesViewState extends State<AportacionesView> {
  TipoAportacion _tipo = TipoAportacion.material;
  bool _celebrada = false;

  /// Confeti una sola vez por vez que se alcanza la meta.
  void _celebrarSiCorresponde(AportacionesViewModel vm) {
    if (!vm.metaAlcanzada) {
      _celebrada = false;
      return;
    }
    if (_celebrada) return;
    _celebrada = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) lanzarConfeti(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = PosadaScope.of(context);
    final vm = scope.aportaciones;
    return ListenableBuilder(
      listenable: Listenable.merge([vm, scope.participantes, scope.sesion]),
      builder: (context, _) {
        _celebrarSiCorresponde(vm);
        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _DialogoAportacion(
                vm: vm,
                participantes: scope.participantes.participantes,
                tipoInicial: _tipo,
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Agregar aportación'),
          ),
          body: _cuerpo(context, scope),
        );
      },
    );
  }

  Widget _cuerpo(BuildContext context, PosadaScope scope) {
    final vm = scope.aportaciones;
    final participantes = scope.participantes.participantes;
    if (vm.cargando) return const EstadoCargando();
    final economica = _tipo == TipoAportacion.economica;
    final tarjetas = economica
        ? _tarjetasEconomicas(context, vm, participantes)
        : _tarjetasMateriales(context, vm, participantes);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        const TituloMagico('Aportaciones'),
        const SizedBox(height: 12),
        SegmentedButton<TipoAportacion>(
          key: const ValueKey('tipo-aportacion'),
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: TipoAportacion.material,
              icon: Icon(Icons.card_giftcard),
              label: Text('Material'),
            ),
            ButtonSegment(
              value: TipoAportacion.economica,
              icon: Icon(Icons.savings_outlined),
              label: Text('Económica'),
            ),
          ],
          selected: {_tipo},
          onSelectionChanged: (s) => setState(() => _tipo = s.first),
        ),
        const SizedBox(height: 12),
        if (economica)
          _EncabezadoEconomico(vm: vm)
        else
          Wrap(
            spacing: 8,
            children: [
              ChipConteo(etiqueta: 'Pendientes', valor: vm.pendientes),
              ChipConteo(etiqueta: 'Listas', valor: vm.listas),
            ],
          ),
        if (vm.error != null) BannerError(mensaje: vm.error!),
        if (economica ? vm.vacioEconomicas : vm.vacioMateriales)
          SizedBox(
            height: 240,
            child: EstadoVacio(
              icono: economica
                  ? Icons.savings_outlined
                  : Icons.shopping_basket_outlined,
              mensaje: economica
                  ? 'Aún no hay aportaciones económicas. ¡Registra la primera!'
                  : 'Aún no hay aportaciones. ¡Agrega la primera!',
            ),
          ),
        ...EntradaEscalonada.lista(tarjetas),
      ],
    );
  }

  List<Widget> _tarjetasMateriales(
    BuildContext context,
    AportacionesViewModel vm,
    List<Participante> participantes,
  ) {
    return [
      for (final a in vm.materiales)
        Padding(
          key: ValueKey('aportacion-${a.id}'),
          padding: const EdgeInsets.only(bottom: 12),
          child: TarjetaCristal(
            inclinacion: false,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: a.lista,
                      onChanged: vm.puedeMarcarLista(a)
                          ? (v) => vm.marcarLista(a.id, v ?? false)
                          : null,
                    ),
                    Expanded(
                      child: Text(
                        '${a.articulo} (x${a.cantidad})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (vm.puedeEliminar)
                      IconButton(
                        tooltip: 'Eliminar ${a.articulo}',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          if (await confirmarEliminar(context, a.articulo)) {
                            await vm.eliminar(a.id);
                          }
                        },
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: DropdownButton<String?>(
                    key: ValueKey('responsable-${a.id}'),
                    value: participantes.any((p) => p.id == a.responsableId)
                        ? a.responsableId
                        : null,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Sin asignar'),
                      ),
                      for (final p in vm.opcionesResponsable(a, participantes))
                        DropdownMenuItem<String?>(
                          value: p.id,
                          child: Text(p.nombre),
                        ),
                    ],
                    onChanged: vm.puedeAsignar(a)
                        ? (id) => vm.asignar(a.id, id)
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  List<Widget> _tarjetasEconomicas(
    BuildContext context,
    AportacionesViewModel vm,
    List<Participante> participantes,
  ) {
    final tema = Theme.of(context);
    return [
      for (final a in vm.economicas)
        Padding(
          key: ValueKey('aportacion-${a.id}'),
          padding: const EdgeInsets.only(bottom: 12),
          child: TarjetaCristal(
            inclinacion: false,
            padding: const EdgeInsets.all(12),
            acento: a.recibido ? AppTheme.auroraTurquesa : AppTheme.oro,
            child: Row(
              children: [
                Icon(
                  a.recibido ? Icons.check_circle : Icons.hourglass_bottom,
                  color: a.recibido ? AppTheme.auroraTurquesa : AppTheme.oro,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatoDinero(a.montoCentavos),
                        style: tema.textTheme.titleMedium,
                      ),
                      Text(
                        '${vm.nombreResponsable(a, participantes)}'
                        ' · ${a.recibido ? 'Recibido' : 'Pendiente'}',
                        style: tema.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (vm.puedeMarcarRecibido)
                  Switch(
                    key: ValueKey('recibido-${a.id}'),
                    value: a.recibido,
                    onChanged: (v) => vm.marcarRecibido(a.id, v),
                  ),
                if (vm.puedeEditarEconomica(a))
                  IconButton(
                    tooltip: 'Editar monto',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => _DialogoMonto(
                        titulo: 'Editar monto',
                        etiqueta: 'Monto',
                        inicial: a.montoCentavos,
                        permiteVacio: false,
                        guardar: (c) => vm.editarMonto(a.id, c!),
                        error: () => vm.error,
                      ),
                    ),
                  ),
                if (vm.puedeEliminarAportacion(a))
                  IconButton(
                    tooltip: 'Eliminar ${formatoDinero(a.montoCentavos)}',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      if (await confirmarEliminar(
                        context,
                        'la aportación de ${formatoDinero(a.montoCentavos)}',
                      )) {
                        await vm.eliminar(a.id);
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
    ];
  }
}

/// Total recibido (animado) contra la meta, con barra de progreso brillante.
class _EncabezadoEconomico extends StatelessWidget {
  const _EncabezadoEconomico({required this.vm});

  final AportacionesViewModel vm;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final meta = vm.meta;
    final alcanzada = vm.metaAlcanzada;
    final color = alcanzada ? AppTheme.auroraTurquesa : AppTheme.oro;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TarjetaCristal(
        inclinacion: false,
        acento: color,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recaudado', style: tema.textTheme.labelLarge),
            const SizedBox(height: 4),
            ContadorAnimado(
              key: const ValueKey('total-recibido'),
              valor: vm.totalRecibido,
              formato: formatoDinero,
              estilo: tema.textTheme.headlineMedium?.copyWith(color: color),
            ),
            const SizedBox(height: 4),
            Text(
              meta == null || meta <= 0
                  ? 'Sin meta definida'
                  : 'Meta: ${formatoDinero(meta)}'
                        ' · ${(vm.progreso * 100).round()}%',
              key: const ValueKey('texto-meta'),
            ),
            const SizedBox(height: 12),
            _BarraProgreso(progreso: vm.progreso, color: color),
            const SizedBox(height: 8),
            Text(
              'Registrado: ${formatoDinero(vm.totalComprometido)}',
              style: tema.textTheme.bodySmall,
            ),
            if (alcanzada)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '¡Meta alcanzada!',
                  key: const ValueKey('meta-alcanzada'),
                  style: tema.textTheme.titleMedium?.copyWith(color: color),
                ),
              ),
            if (vm.sesion.esAdmin)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: const ValueKey('editar-meta'),
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Editar meta'),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => _DialogoMonto(
                      titulo: 'Meta de recaudación',
                      etiqueta: 'Meta (vacío para quitarla)',
                      inicial: meta,
                      permiteVacio: true,
                      guardar: vm.guardarMeta,
                      error: () => vm.error,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BarraProgreso extends StatelessWidget {
  const _BarraProgreso({required this.progreso, required this.color});

  final double progreso;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final duracion = movimientoReducido(context)
        ? Duration.zero
        : const Duration(milliseconds: 1200);
    return Semantics(
      label: 'Progreso de la meta',
      value: '${(progreso * 100).round()}%',
      child: Container(
        height: 14,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(7),
        ),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progreso),
          duration: duracion,
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              key: const ValueKey('barra-progreso'),
              widthFactor: v,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  gradient: LinearGradient(
                    colors: [color, AppTheme.auroraMagenta],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.6),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Diálogo de un monto (meta o edición de una económica).
class _DialogoMonto extends StatefulWidget {
  const _DialogoMonto({
    required this.titulo,
    required this.etiqueta,
    required this.inicial,
    required this.permiteVacio,
    required this.guardar,
    required this.error,
  });

  final String titulo;
  final String etiqueta;
  final int? inicial;
  final bool permiteVacio;
  final Future<bool> Function(int? centavos) guardar;
  final String? Function() error;

  @override
  State<_DialogoMonto> createState() => _DialogoMontoState();
}

class _DialogoMontoState extends State<_DialogoMonto> {
  late final _monto = TextEditingController(
    text: widget.inicial == null
        ? ''
        : (widget.inicial! / 100).toStringAsFixed(2),
  );
  String? _error;

  @override
  void dispose() {
    _monto.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final texto = _monto.text.trim();
    int? centavos;
    if (texto.isEmpty && widget.permiteVacio) {
      centavos = null;
    } else {
      centavos = centavosDeTexto(texto);
      if (centavos == null) {
        setState(() => _error = 'Escribe un monto válido, por ejemplo 150.50.');
        return;
      }
    }
    final ok = await widget.guardar(centavos);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _error = widget.error());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: TextField(
        key: const ValueKey('campo-monto'),
        controller: _monto,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: widget.etiqueta,
          prefixText: r'$ ',
          errorText: _error,
          errorMaxLines: 3,
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

class _DialogoAportacion extends StatefulWidget {
  const _DialogoAportacion({
    required this.vm,
    required this.participantes,
    required this.tipoInicial,
  });

  final AportacionesViewModel vm;
  final List<Participante> participantes;
  final TipoAportacion tipoInicial;

  @override
  State<_DialogoAportacion> createState() => _DialogoAportacionState();
}

class _DialogoAportacionState extends State<_DialogoAportacion> {
  final _articulo = TextEditingController();
  final _cantidad = TextEditingController(text: '1');
  final _monto = TextEditingController();
  late TipoAportacion _tipo = widget.tipoInicial;
  late String? _responsable =
      widget.participantes.any((p) => p.id == widget.vm.sesion.uid)
      ? widget.vm.sesion.uid
      : widget.participantes.firstOrNull?.id;
  String? _error;

  @override
  void dispose() {
    _articulo.dispose();
    _cantidad.dispose();
    _monto.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final bool ok;
    if (_tipo == TipoAportacion.material) {
      // Un texto no numérico se trata como 0 y el viewmodel lo rechaza.
      final cantidad = int.tryParse(_cantidad.text.trim()) ?? 0;
      ok = await widget.vm.agregar(_articulo.text, cantidad);
    } else {
      // Un texto inválido se trata como 0 y el viewmodel lo rechaza.
      final centavos = centavosDeTexto(_monto.text) ?? 0;
      ok = await widget.vm.agregarEconomica(
        centavos,
        responsableId: widget.vm.sesion.esAdmin ? _responsable : null,
      );
    }
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _error = widget.vm.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final material = _tipo == TipoAportacion.material;
    return AlertDialog(
      title: const Text('Nueva aportación'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<TipoAportacion>(
              key: const ValueKey('dialogo-tipo'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: TipoAportacion.material,
                  label: Text('Material'),
                ),
                ButtonSegment(
                  value: TipoAportacion.economica,
                  label: Text('Económica'),
                ),
              ],
              selected: {_tipo},
              onSelectionChanged: (s) => setState(() {
                _tipo = s.first;
                _error = null;
              }),
            ),
            const SizedBox(height: 12),
            if (material) ...[
              TextField(
                controller: _articulo,
                maxLength: Limites.articulo,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Artículo'),
              ),
              TextField(
                controller: _cantidad,
                keyboardType: TextInputType.number,
                maxLength: 3, // dígitos de Limites.cantidadMaxima
                decoration: InputDecoration(
                  labelText: 'Cantidad',
                  errorText: _error,
                  errorMaxLines: 3,
                ),
              ),
            ] else ...[
              if (widget.vm.sesion.esAdmin && widget.participantes.isNotEmpty)
                DropdownButton<String>(
                  key: const ValueKey('dialogo-responsable'),
                  isExpanded: true,
                  value: _responsable,
                  items: [
                    for (final p in widget.participantes)
                      DropdownMenuItem(value: p.id, child: Text(p.nombre)),
                  ],
                  onChanged: (id) => setState(() => _responsable = id),
                ),
              TextField(
                key: const ValueKey('campo-monto'),
                controller: _monto,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Monto',
                  prefixText: r'$ ',
                  errorText: _error,
                  errorMaxLines: 3,
                ),
              ),
            ],
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
