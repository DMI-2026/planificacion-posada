import 'package:flutter/material.dart';

import '../../../core/efectos/efectos.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/estados.dart';
import '../models/comida_opcion.dart';
import '../models/limites_votacion.dart';
import '../viewmodels/votacion_view_model.dart';

/// Votación de la comida de la posada, con resultados en vivo.
class VotacionView extends StatelessWidget {
  const VotacionView({super.key, required this.viewModel});

  final VotacionViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final vm = viewModel;
        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: vm.esParticipante && !vm.cerrada
              ? BotonBrillante(
                  onPressed: () => _proponer(context),
                  etiqueta: 'Proponer platillo',
                  icono: Icons.add,
                )
              : null,
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          body: vm.cargando ? const EstadoCargando() : _lista(context),
        );
      },
    );
  }

  Widget _lista(BuildContext context) {
    final vm = viewModel;
    final resultados = vm.resultados;
    final ganadores = {for (final g in vm.ganadores) g.id};
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      children: [
        const TituloMagico(
          'Votación de la comida',
          estilo: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Chip(
              avatar: Icon(
                vm.cerrada ? Icons.lock : Icons.how_to_vote,
                size: 18,
              ),
              label: Text(vm.cerrada ? 'Votación cerrada' : 'Votación abierta'),
            ),
            ChipConteo(etiqueta: 'Votos', valor: vm.totalVotos),
            if (vm.esAdmin)
              OutlinedButton.icon(
                onPressed: vm.cerrada ? vm.reabrir : vm.cerrar,
                icon: Icon(vm.cerrada ? Icons.lock_open : Icons.lock),
                label: Text(
                  vm.cerrada ? 'Reabrir votación' : 'Cerrar votación',
                ),
              ),
          ],
        ),
        if (vm.error != null) ...[
          const SizedBox(height: 8),
          BannerError(mensaje: vm.error!),
        ],
        if (vm.cerrada) _Resultado(ganadores: vm.ganadores),
        if (vm.vacio)
          const SizedBox(
            height: 240,
            child: EstadoVacio(
              icono: Icons.restaurant_menu,
              mensaje: 'Aún no hay platillos. ¡Propón el primero!',
            ),
          ),
        const SizedBox(height: 8),
        for (var i = 0; i < resultados.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: EntradaEscalonada(
              indice: i,
              child: _TarjetaOpcion(
                key: ValueKey(resultados[i].opcion.id),
                vm: vm,
                r: resultados[i],
                esMia: vm.miVoto == resultados[i].opcion.id,
                ganadora: ganadores.contains(resultados[i].opcion.id),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _proponer(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => _DialogoPlatillo(vm: viewModel),
  );
}

class _Resultado extends StatelessWidget {
  const _Resultado({required this.ganadores});

  final List<ComidaOpcion> ganadores;

  @override
  Widget build(BuildContext context) {
    final texto = ganadores.isEmpty
        ? 'Nadie votó todavía.'
        : ganadores.length == 1
        ? 'Ganador: ${ganadores.first.nombre}'
        : 'Empate: ${ganadores.map((g) => g.nombre).join(', ')}';
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TarjetaCristal(
        inclinacion: false,
        child: Row(
          children: [
            const Icon(Icons.emoji_events, color: AppTheme.oro, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                texto,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaOpcion extends StatelessWidget {
  const _TarjetaOpcion({
    super.key,
    required this.vm,
    required this.r,
    required this.esMia,
    required this.ganadora,
  });

  final VotacionViewModel vm;
  final OpcionResultado r;
  final bool esMia;
  final bool ganadora;

  Future<void> _votar(BuildContext context) async {
    final ok = await vm.votar(r.opcion.id);
    if (ok && context.mounted) lanzarConfeti(context);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final o = r.opcion;
    final reducido = movimientoReducido(context);
    final duracion = reducido
        ? Duration.zero
        : const Duration(milliseconds: 600);
    final acento = ganadora ? AppTheme.oro : AppTheme.auroraTurquesa;
    return AnimatedContainer(
      duration: duracion,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: esMia || ganadora
            ? [
                BoxShadow(
                  color: acento.withValues(alpha: 0.55),
                  blurRadius: 24,
                  spreadRadius: 1,
                ),
              ]
            : const [],
      ),
      child: TarjetaCristal(
        inclinacion: false,
        acento: esMia || ganadora ? acento : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (ganadora) ...[
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: reducido ? 1 : 0, end: 1),
                    duration: duracion * 2,
                    curve: Curves.elasticOut,
                    builder: (_, v, hijo) =>
                        Transform.scale(scale: v, child: hijo),
                    child: const Icon(
                      Icons.emoji_events,
                      color: AppTheme.oro,
                      semanticLabel: 'Ganador',
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(o.nombre, style: tema.textTheme.titleMedium),
                ),
                if (vm.puedeEliminar(o))
                  IconButton(
                    tooltip: 'Eliminar platillo',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => vm.eliminarOpcion(o.id),
                  ),
              ],
            ),
            if (o.descripcion.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  o.descripcion,
                  style: tema.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textoSuave,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: r.porcentaje),
                duration: duracion,
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 10,
                  color: acento,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ContadorAnimado(
                  valor: r.votos,
                  estilo: tema.textTheme.titleLarge,
                ),
                const SizedBox(width: 6),
                Text(r.votos == 1 ? 'voto' : 'votos'),
                const SizedBox(width: 8),
                Text('(${(r.porcentaje * 100).round()} %)'),
                const Spacer(),
                if (vm.esParticipante && !vm.cerrada)
                  esMia
                      ? OutlinedButton.icon(
                          onPressed: vm.quitarVoto,
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Quitar voto'),
                        )
                      : FilledButton(
                          onPressed: () => _votar(context),
                          child: const Text('Votar'),
                        )
                else if (esMia)
                  const Chip(
                    avatar: Icon(Icons.check_circle, size: 18),
                    label: Text('Tu voto'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogoPlatillo extends StatefulWidget {
  const _DialogoPlatillo({required this.vm});

  final VotacionViewModel vm;

  @override
  State<_DialogoPlatillo> createState() => _DialogoPlatilloState();
}

class _DialogoPlatilloState extends State<_DialogoPlatillo> {
  final _nombre = TextEditingController();
  final _descripcion = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final ok = await widget.vm.proponer(_nombre.text, _descripcion.text);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _error = widget.vm.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Proponer platillo'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nombre,
              autofocus: true,
              maxLength: LimitesVotacion.nombreMax,
              decoration: const InputDecoration(labelText: 'Platillo'),
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: _descripcion,
              maxLength: LimitesVotacion.descripcionMax,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _enviar, child: const Text('Proponer')),
      ],
    );
  }
}
