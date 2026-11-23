import '../../../core/validacion/limites.dart';

import 'package:flutter/material.dart';

import '../../../core/navegacion/posada_scope.dart';
import '../../../core/widgets/estados.dart';
import '../viewmodels/aportaciones_view_model.dart';

/// Lista de aportaciones (qué lleva cada quien).
class AportacionesView extends StatelessWidget {
  const AportacionesView({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = PosadaScope.of(context);
    final vm = scope.aportaciones;
    return ListenableBuilder(
      listenable: Listenable.merge([vm, scope.participantes, scope.sesion]),
      builder: (context, _) {
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _DialogoAportacion(vm: vm),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Text('Aportaciones', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChipConteo(etiqueta: 'Pendientes', valor: vm.pendientes),
            ChipConteo(etiqueta: 'Listas', valor: vm.listas),
          ],
        ),
        if (vm.error != null) BannerError(mensaje: vm.error!),
        if (vm.vacio)
          const SizedBox(
            height: 240,
            child: EstadoVacio(
              icono: Icons.shopping_basket_outlined,
              mensaje: 'Aún no hay aportaciones. ¡Agrega la primera!',
            ),
          ),
        for (final a in vm.aportaciones)
          Card(
            key: ValueKey('aportacion-${a.id}'),
            child: Padding(
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
                        for (final p in vm.opcionesResponsable(
                          a,
                          participantes,
                        ))
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
      ],
    );
  }
}

class _DialogoAportacion extends StatefulWidget {
  const _DialogoAportacion({required this.vm});

  final AportacionesViewModel vm;

  @override
  State<_DialogoAportacion> createState() => _DialogoAportacionState();
}

class _DialogoAportacionState extends State<_DialogoAportacion> {
  final _articulo = TextEditingController();
  final _cantidad = TextEditingController(text: '1');
  String? _error;

  @override
  void dispose() {
    _articulo.dispose();
    _cantidad.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    // Un texto no numérico se trata como 0 y el viewmodel lo rechaza.
    final cantidad = int.tryParse(_cantidad.text.trim()) ?? 0;
    final ok = await widget.vm.agregar(_articulo.text, cantidad);
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
      title: const Text('Nueva aportación'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
        ],
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
