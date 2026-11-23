import 'package:flutter/material.dart';

import '../../../core/efectos/efectos.dart';
import '../../../core/theme/app_theme.dart';
import '../models/limites_intercambio.dart';
import '../utilidades/formato.dart';
import '../viewmodels/intercambio_view_model.dart';
import 'regalo_sorpresa.dart';

/// Pantalla del intercambio de regalos («noche mágica»). Fondo transparente:
/// se ve el cielo del shell detrás.
class IntercambioView extends StatelessWidget {
  const IntercambioView({super.key, required this.viewModel});

  final IntercambioViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          final vm = viewModel;
          if (vm.cargando) {
            return const Center(child: CircularProgressIndicator());
          }
          final secciones = <Widget>[
            const TituloMagico('Intercambio de regalos'),
            if (vm.error != null) _Aviso(vm.error!, onCerrar: vm.limpiarError),
            _TarjetaDatos(vm: vm),
            if (!vm.config.sorteado) _Inscripcion(vm: vm),
            if (vm.config.sorteado) _Sorteo(vm: vm),
            if (vm.parejas.isNotEmpty) _Parejas(vm: vm),
            if (vm.esAdmin) _PanelAdmin(vm: vm),
          ];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (var i = 0; i < secciones.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: EntradaEscalonada(indice: i, child: secciones[i]),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso(this.mensaje, {required this.onCerrar});

  final String mensaje;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.error),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: cs.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(mensaje, style: TextStyle(color: cs.error)),
          ),
          IconButton(
            tooltip: 'Cerrar aviso',
            icon: const Icon(Icons.close),
            onPressed: onCerrar,
          ),
        ],
      ),
    );
  }
}

class _TarjetaDatos extends StatelessWidget {
  const _TarjetaDatos({required this.vm});

  final IntercambioViewModel vm;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final c = vm.config;
    final fecha = c.fecha;
    return TarjetaCristal(
      acento: AppTheme.auroraTurquesa,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Presupuesto',
                  style: tema.textTheme.labelLarge?.copyWith(
                    color: AppTheme.textoSuave,
                  ),
                ),
                ContadorAnimado(
                  valor: c.presupuestoCentavos,
                  formato: formatearMonto,
                  estilo: tema.textTheme.headlineMedium?.copyWith(
                    color: AppTheme.oro,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Entrega de regalos',
                  style: tema.textTheme.labelLarge?.copyWith(
                    color: AppTheme.textoSuave,
                  ),
                ),
                if (fecha == null)
                  Text('Fecha por definir', style: tema.textTheme.titleMedium)
                else ...[
                  Text(
                    formatearFecha(fecha),
                    textAlign: TextAlign.end,
                    style: tema.textTheme.titleMedium,
                  ),
                  Text(
                    cuentaRegresiva(fecha, DateTime.now()),
                    style: tema.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.auroraTurquesa,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Antes del sorteo: estado de la inscripción y editor de deseos.
class _Inscripcion extends StatelessWidget {
  const _Inscripcion({required this.vm});

  final IntercambioViewModel vm;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final abierta = vm.config.inscripcionAbierta;
    return TarjetaCristal(
      inclinacion: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                abierta ? Icons.lock_open : Icons.lock_outline,
                color: abierta ? AppTheme.auroraTurquesa : AppTheme.textoSuave,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  abierta
                      ? 'Inscripción abierta'
                      : 'Inscripción cerrada: el organizador aún no la abre '
                            'o ya está por sortear.',
                  style: tema.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${vm.totalInscritos} '
            '${vm.totalInscritos == 1 ? 'persona inscrita' : 'personas inscritas'}',
            style: tema.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textoSuave,
            ),
          ),
          if (vm.nombresInscritos.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final n in vm.nombresInscritos)
                  Chip(
                    avatar: const Icon(Icons.person, size: 16),
                    label: Text(n),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
          if (vm.puedeInscribirse) ...[
            const Divider(height: 24),
            Text('¿Qué te gustaría recibir?', style: tema.textTheme.titleSmall),
            _EditorDeseos(
              inicial: const [],
              etiqueta: 'Inscribirme',
              ocupado: vm.ocupado,
              onGuardar: vm.inscribirse,
            ),
          ] else if (vm.puedeEditarDeseos) ...[
            const Divider(height: 24),
            Text('Tus deseos', style: tema.textTheme.titleSmall),
            _EditorDeseos(
              inicial: vm.misDeseos,
              etiqueta: 'Guardar deseos',
              ocupado: vm.ocupado,
              onGuardar: vm.actualizarDeseos,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: vm.ocupado ? null : vm.salir,
              icon: const Icon(Icons.logout),
              label: const Text('Salir del intercambio'),
            ),
          ] else if (vm.inscrito != null) ...[
            const Divider(height: 24),
            Text(
              'Estás inscrit@. Pronto se hará el sorteo.',
              style: tema.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

/// Editor de deseos con fichas (máximo 3, 80 caracteres cada uno).
class _EditorDeseos extends StatefulWidget {
  const _EditorDeseos({
    required this.inicial,
    required this.etiqueta,
    required this.ocupado,
    required this.onGuardar,
  });

  final List<String> inicial;
  final String etiqueta;
  final bool ocupado;
  final Future<bool> Function(List<String>) onGuardar;

  @override
  State<_EditorDeseos> createState() => _EditorDeseosState();
}

class _EditorDeseosState extends State<_EditorDeseos> {
  late final List<String> _deseos = List.of(widget.inicial);
  final _texto = TextEditingController();

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  void _agregar() {
    final t = _texto.text.trim();
    if (t.isEmpty || _deseos.length >= LimitesIntercambio.maxDeseos) return;
    setState(() {
      _deseos.add(t);
      _texto.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lleno = _deseos.length >= LimitesIntercambio.maxDeseos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _deseos.length; i++)
              InputChip(
                label: Text(_deseos[i]),
                onDeleted: () => setState(() => _deseos.removeAt(i)),
                deleteButtonTooltipMessage: 'Quitar deseo',
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('campo-deseo'),
                controller: _texto,
                enabled: !lleno,
                maxLength: LimitesIntercambio.maxCaracteresDeseo,
                buildCounter: (
                  _, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) => null,
                decoration: InputDecoration(
                  labelText: lleno
                      ? 'Ya tienes ${LimitesIntercambio.maxDeseos} deseos'
                      : 'Un deseo (ej. una bufanda)',
                ),
                onSubmitted: (_) => _agregar(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              key: const Key('agregar-deseo'),
              tooltip: 'Agregar deseo',
              onPressed: lleno ? null : _agregar,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 12),
        BotonBrillante(
          etiqueta: widget.etiqueta,
          icono: Icons.card_giftcard,
          onPressed: widget.ocupado
              ? null
              : () => widget.onGuardar(List.of(_deseos)),
        ),
      ],
    );
  }
}

/// Después del sorteo: el regalo sorpresa (o aviso si no participas).
class _Sorteo extends StatelessWidget {
  const _Sorteo({required this.vm});

  final IntercambioViewModel vm;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final destino = vm.miDestinatario;
    if (destino == null) {
      return TarjetaCristal(
        inclinacion: false,
        child: Text(
          vm.esParticipante && vm.inscrito != null
              ? 'Ya se hizo el sorteo. Tu regalo aparecerá aquí en un momento.'
              : 'Ya se hizo el sorteo y no estabas inscrit@ a tiempo. '
                    '¡Para la próxima!',
          style: tema.textTheme.titleMedium,
        ),
      );
    }
    return RegaloSorpresa(destinatario: destino);
  }
}

/// Cuadrícula de parejas (todas, tras revelar; el admin las ve siempre).
class _Parejas extends StatelessWidget {
  const _Parejas({required this.vm});

  final IntercambioViewModel vm;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final parejas = vm.parejas;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          vm.config.revelado
              ? 'Todas las parejas'
              : 'Parejas (solo las ve el organizador)',
          style: tema.textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var i = 0; i < parejas.length; i++)
              EntradaEscalonada(
                indice: i,
                child: SizedBox(
                  width: 180,
                  child: TarjetaCristal(
                    key: Key('pareja-${parejas[i].dadorId}'),
                    inclinacion: false,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Text(
                          parejas[i].dadorNombre,
                          style: tema.textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const Icon(
                          Icons.arrow_downward,
                          color: AppTheme.oro,
                          size: 20,
                        ),
                        Text(
                          parejas[i].receptorNombre,
                          style: tema.textTheme.titleMedium?.copyWith(
                            color: AppTheme.oro,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PanelAdmin extends StatefulWidget {
  const _PanelAdmin({required this.vm});

  final IntercambioViewModel vm;

  @override
  State<_PanelAdmin> createState() => _PanelAdminState();
}

class _PanelAdminState extends State<_PanelAdmin> {
  late final TextEditingController _presupuesto = TextEditingController(
    text: widget.vm.config.presupuestoCentavos == 0
        ? ''
        : (widget.vm.config.presupuestoCentavos / 100).toStringAsFixed(2),
  );

  @override
  void dispose() {
    _presupuesto.dispose();
    super.dispose();
  }

  Future<bool> _confirmar(String titulo, String texto, String accion) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(texto),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(accion),
          ),
        ],
      ),
    );
    return r ?? false;
  }

  Future<void> _guardarPresupuesto() async {
    final c = parsearMonto(_presupuesto.text);
    if (c == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Escribe un monto válido, ej. 250 o 250.50.'),
        ),
      );
      return;
    }
    await widget.vm.editarPresupuesto(c);
  }

  Future<void> _elegirFecha() async {
    final vm = widget.vm;
    final ahora = DateTime.now();
    final f = await showDatePicker(
      context: context,
      initialDate: vm.config.fecha ?? ahora,
      firstDate: DateTime(ahora.year - 1),
      lastDate: DateTime(ahora.year + 3),
    );
    if (f != null) await vm.editarFecha(f);
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final tema = Theme.of(context);
    final c = vm.config;
    final libre = !vm.ocupado;
    return TarjetaCristal(
      acento: AppTheme.auroraMagenta,
      inclinacion: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Panel del organizador', style: tema.textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (!c.sorteado)
                OutlinedButton.icon(
                  onPressed: !libre
                      ? null
                      : (c.inscripcionAbierta
                            ? vm.cerrarInscripcion
                            : vm.abrirInscripcion),
                  icon: Icon(
                    c.inscripcionAbierta ? Icons.lock : Icons.lock_open,
                  ),
                  label: Text(
                    c.inscripcionAbierta
                        ? 'Cerrar inscripción'
                        : 'Abrir inscripción',
                  ),
                ),
              if (!c.sorteado)
                BotonBrillante(
                  key: const Key('admin-sortear'),
                  etiqueta: 'Sortear',
                  icono: Icons.shuffle,
                  onPressed: libre ? vm.sortear : null,
                ),
              if (c.sorteado && !c.revelado)
                OutlinedButton.icon(
                  key: const Key('admin-rehacer'),
                  onPressed: !libre
                      ? null
                      : () async {
                          if (await _confirmar(
                            '¿Rehacer el sorteo?',
                            'Se borran las parejas actuales y se sortea de nuevo.',
                            'Rehacer',
                          )) {
                            await vm.rehacerSorteo();
                          }
                        },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Rehacer sorteo'),
                ),
              if (c.sorteado && !c.revelado)
                BotonBrillante(
                  key: const Key('admin-revelar'),
                  etiqueta: 'Revelar sorteo',
                  icono: Icons.auto_awesome,
                  onPressed: !libre
                      ? null
                      : () async {
                          if (await _confirmar(
                            '¿Revelar todas las parejas?',
                            'Todos podrán ver quién le regala a quién y ya no '
                                'se podrá rehacer el sorteo.',
                            'Revelar',
                          )) {
                            await vm.revelar();
                          }
                        },
                ),
              if (c.revelado)
                Text(
                  'Sorteo revelado.',
                  style: tema.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.auroraTurquesa,
                  ),
                ),
            ],
          ),
          const Divider(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('campo-presupuesto'),
                  controller: _presupuesto,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Presupuesto (\$)',
                  ),
                  onSubmitted: (_) => _guardarPresupuesto(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('guardar-presupuesto'),
                onPressed: libre ? _guardarPresupuesto : null,
                child: const Text('Guardar'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: libre ? _elegirFecha : null,
                icon: const Icon(Icons.event),
                label: const Text('Elegir fecha'),
              ),
              if (c.fecha != null)
                TextButton(
                  onPressed: libre ? () => vm.editarFecha(null) : null,
                  child: const Text('Quitar fecha'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
