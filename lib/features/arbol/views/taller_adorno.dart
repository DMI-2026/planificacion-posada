import 'package:flutter/material.dart';

import '../../../core/efectos/efectos.dart';
import '../models/adorno.dart';
import '../viewmodels/arbol_view_model.dart';
import 'dibujos_adorno.dart';

/// Hoja del «taller»: se elige tipo, colores, dibujo y mensaje con una vista
/// previa en vivo, y se cuelga el adorno (o se guardan los cambios si se
/// edita uno).
class TallerAdorno extends StatefulWidget {
  const TallerAdorno({
    super.key,
    required this.viewModel,
    this.editando,
    this.alTerminar,
  });

  final ArbolViewModel viewModel;

  /// Adorno propio que se edita; `null` para crear uno nuevo.
  final Adorno? editando;

  /// Se llama tras guardar con éxito; recibe `true` si se creó uno nuevo.
  final void Function(bool nuevo)? alTerminar;

  @override
  State<TallerAdorno> createState() => _TallerAdornoState();
}

class _TallerAdornoState extends State<TallerAdorno> {
  late TipoAdorno _tipo = widget.editando?.tipo ?? TipoAdorno.esfera;
  late String _color = widget.editando?.color ?? PaletaArbol.colores.first;
  late String _colorMono = widget.editando?.colorMono ?? PaletaArbol.colores[1];
  late PatronEsfera _patron = widget.editando?.patron ?? PatronEsfera.rayas;
  late final TextEditingController _mensaje = TextEditingController(
    text: widget.editando?.mensaje ?? '',
  );
  bool _guardando = false;
  String? _error;

  bool get _edita => widget.editando != null;

  @override
  void dispose() {
    _mensaje.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final vm = widget.viewModel;
    setState(() {
      _guardando = true;
      _error = null;
    });
    final mensaje = _mensaje.text;
    final bool ok;
    if (_edita) {
      ok = await vm.editar(
        widget.editando!.id,
        color: _color,
        patron: _tipo == TipoAdorno.esfera ? _patron : null,
        colorMono: _tipo == TipoAdorno.regalo ? _colorMono : null,
        mensaje: mensaje,
      );
    } else if (_tipo == TipoAdorno.esfera) {
      ok = await vm.crearEsfera(
        color: _color,
        patron: _patron,
        mensaje: mensaje,
      );
    } else {
      ok = await vm.crearRegalo(
        color: _color,
        colorMono: _colorMono,
        mensaje: mensaje,
      );
    }
    if (!mounted) return;
    if (ok) {
      widget.alTerminar?.call(!_edita);
    } else {
      setState(() {
        _guardando = false;
        _error = vm.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final vm = widget.viewModel;
    final bloqueo = _edita
        ? null
        : !vm.esParticipante
        ? 'Para colgar adornos necesitas estar en la lista de la posada.'
        : !vm.puedeCrear
        ? 'Ya colgaste tus ${LimitesArbol.maxAdornos} adornos. '
              'Quita uno desde el árbol para colgar otro.'
        : null;
    final lugares = vm.slotsLibres;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: TarjetaCristal(
        inclinacion: false,
        radio: 28,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0x66BDBEE6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _edita ? 'Editar adorno' : 'Taller de adornos',
                style: tema.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              _Vista(
                tipo: _tipo,
                color: _color,
                colorMono: _colorMono,
                patron: _patron,
              ),
              if (!_edita)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    lugares == 1
                        ? 'Te queda 1 lugar en el árbol.'
                        : 'Te quedan $lugares lugares en el árbol.',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 14),
              SegmentedButton<TipoAdorno>(
                segments: const [
                  ButtonSegment(
                    value: TipoAdorno.esfera,
                    label: Text('Esfera'),
                    icon: Icon(Icons.circle_outlined),
                  ),
                  ButtonSegment(
                    value: TipoAdorno.regalo,
                    label: Text('Regalo'),
                    icon: Icon(Icons.card_giftcard),
                  ),
                ],
                selected: {_tipo},
                onSelectionChanged: _edita
                    ? null
                    : (s) => setState(() => _tipo = s.first),
              ),
              const SizedBox(height: 14),
              Text(
                _tipo == TipoAdorno.esfera
                    ? 'Color de la esfera'
                    : 'Color de la caja',
                style: tema.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              _Paleta(
                elegido: _color,
                prefijo: 'color',
                alElegir: (c) => setState(() => _color = c),
              ),
              const SizedBox(height: 14),
              if (_tipo == TipoAdorno.esfera) ...[
                Text('Dibujo', style: tema.textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final p in PatronEsfera.values)
                      ChoiceChip(
                        key: Key('patron-${p.clave}'),
                        label: Text(nombrePatron(p)),
                        selected: _patron == p,
                        onSelected: (_) => setState(() => _patron = p),
                      ),
                  ],
                ),
              ] else ...[
                Text('Color del listón', style: tema.textTheme.titleSmall),
                const SizedBox(height: 8),
                _Paleta(
                  elegido: _colorMono,
                  prefijo: 'cinta',
                  alElegir: (c) => setState(() => _colorMono = c),
                ),
              ],
              const SizedBox(height: 14),
              TextField(
                key: const Key('mensaje-adorno'),
                controller: _mensaje,
                maxLength: LimitesArbol.maxMensaje,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Mensaje (opcional)',
                  hintText: 'Un deseo para la clase',
                ),
              ),
              if (bloqueo != null || _error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    bloqueo ?? _error!,
                    key: const Key('aviso-taller'),
                    textAlign: TextAlign.center,
                    style: tema.textTheme.bodyMedium?.copyWith(
                      color: tema.colorScheme.error,
                    ),
                  ),
                ),
              Center(
                child: BotonBrillante(
                  etiqueta: _edita ? 'Guardar cambios' : 'Colgar en el árbol',
                  icono: _edita ? Icons.check : Icons.celebration,
                  onPressed: (bloqueo != null || _guardando) ? null : _guardar,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Vista extends StatelessWidget {
  const _Vista({
    required this.tipo,
    required this.color,
    required this.colorMono,
    required this.patron,
  });

  final TipoAdorno tipo;
  final String color;
  final String colorMono;
  final PatronEsfera patron;

  @override
  Widget build(BuildContext context) {
    final dibujo = tipo == TipoAdorno.esfera
        ? DibujoEsfera(
            key: ValueKey('esfera-$color-${patron.name}'),
            color: color,
            patron: patron,
            tamano: 104,
          )
        : DibujoRegalo(
            key: ValueKey('regalo-$color-$colorMono'),
            color: color,
            colorMono: colorMono,
            tamano: 104,
          );
    return Semantics(
      label: 'Vista previa del adorno',
      child: Container(
        key: const Key('vista-previa'),
        height: 128,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const RadialGradient(
            colors: [Color(0x552EE6C8), Color(0x00000000)],
          ),
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (hijo, anim) => ScaleTransition(
            scale: Tween(begin: 0.85, end: 1.0).animate(anim),
            child: FadeTransition(opacity: anim, child: hijo),
          ),
          child: dibujo,
        ),
      ),
    );
  }
}

class _Paleta extends StatelessWidget {
  const _Paleta({
    required this.elegido,
    required this.prefijo,
    required this.alElegir,
  });

  final String elegido;
  final String prefijo;
  final ValueChanged<String> alElegir;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final hex in PaletaArbol.colores)
          Semantics(
            button: true,
            selected: hex == elegido,
            label: nombresColores[hex] ?? hex,
            child: InkResponse(
              key: Key('$prefijo-$hex'),
              onTap: () => alElegir(hex),
              radius: 26,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorDeHex(hex),
                  border: Border.all(
                    color: hex == elegido
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.25),
                    width: hex == elegido ? 3 : 1,
                  ),
                  boxShadow: hex == elegido
                      ? [
                          BoxShadow(
                            color: colorDeHex(hex).withValues(alpha: 0.7),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
                child: hex == elegido
                    ? Icon(
                        Icons.check,
                        size: 20,
                        color: colorDeHex(hex).computeLuminance() > 0.5
                            ? Colors.black87
                            : Colors.white,
                      )
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}
