import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../viewmodels/cohetazo_view_model.dart';

/// Marcador sobre la arena: los mejores jugadores en línea y, si no está
/// entre ellos, también el propio puntaje. En pantallas angostas empieza
/// replegado (muestra solo la posición propia); un toque lo despliega.
class MarcadorArena extends StatefulWidget {
  const MarcadorArena({
    super.key,
    required this.viewModel,
    this.compacto = false,
  });

  final CohetazoViewModel viewModel;
  final bool compacto;

  @override
  State<MarcadorArena> createState() => _MarcadorArenaState();
}

class _MarcadorArenaState extends State<MarcadorArena> {
  late bool _abierto = !widget.compacto;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final tabla = widget.viewModel.tablero;
        final propia = tabla.indexWhere((e) => e.esYo);
        final mejores = tabla.take(5).toList();
        final filas = <Widget>[
          for (var i = 0; i < mejores.length; i++)
            _Fila(posicion: i + 1, entrada: mejores[i]),
          if (propia >= mejores.length)
            _Fila(posicion: propia + 1, entrada: tabla[propia]),
        ];
        return Semantics(
          label: 'Marcador',
          child: GestureDetector(
            key: const Key('marcador'),
            onTap: () => setState(() => _abierto = !_abierto),
            child: Container(
              width: _abierto ? 150 : null,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xCC070B1F),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x44FFC857)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: _abierto
                    ? CrossAxisAlignment.stretch
                    : CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.emoji_events,
                        size: 14,
                        color: AppTheme.oro,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _abierto
                            ? 'Marcador'
                            : '#${propia + 1} · ${widget.viewModel.puntaje} pts',
                        style: const TextStyle(
                          color: AppTheme.oro,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  if (_abierto) ...[const SizedBox(height: 2), ...filas],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.posicion, required this.entrada});

  final int posicion;
  final EntradaMarcador entrada;

  @override
  Widget build(BuildContext context) {
    final yo = entrada.esYo;
    return Container(
      key: Key('fila-marcador-${entrada.uid}'),
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: yo ? const Color(0x55FFC857) : null,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            child: Text(
              '$posicion',
              style: const TextStyle(color: AppTheme.textoSuave, fontSize: 10),
            ),
          ),
          Expanded(
            child: Text(
              entrada.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: yo ? AppTheme.oro : AppTheme.texto,
                fontSize: 11,
                fontWeight: yo ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            '${entrada.puntos}',
            style: TextStyle(
              color: yo ? AppTheme.oro : AppTheme.texto,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
