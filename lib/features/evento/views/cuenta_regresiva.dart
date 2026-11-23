import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/efectos/efectos.dart';

/// Tiempo restante hasta [fecha], desglosado.
class TiempoRestante {
  const TiempoRestante(this.dias, this.horas, this.minutos, this.segundos);

  factory TiempoRestante.de(Duration d) => TiempoRestante(
    d.inDays,
    d.inHours % 24,
    d.inMinutes % 60,
    d.inSeconds % 60,
  );

  final int dias, horas, minutos, segundos;
}

bool _mismoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Cuenta regresiva en vivo hasta la fecha del evento.
///
/// Muestra «¡Es hoy!» durante el día del evento y «La posada ya pasó»
/// después. [ahora] permite inyectar el reloj (pruebas).
class CuentaRegresiva extends StatefulWidget {
  const CuentaRegresiva({super.key, required this.fecha, this.ahora});

  final DateTime fecha;
  final DateTime Function()? ahora;

  @override
  State<CuentaRegresiva> createState() => _CuentaRegresivaState();
}

class _CuentaRegresivaState extends State<CuentaRegresiva> {
  Timer? _reloj;
  late DateTime _ahora = _leer();

  DateTime _leer() => (widget.ahora ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _ahora = _leer());
    });
  }

  @override
  void didUpdateWidget(CuentaRegresiva anterior) {
    super.didUpdateWidget(anterior);
    _ahora = _leer();
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    if (_mismoDia(_ahora, widget.fecha)) {
      return _Mensaje(
        texto: '¡Es hoy!',
        estilo: tema.textTheme.displaySmall?.copyWith(
          color: tema.colorScheme.tertiary,
        ),
      );
    }
    final falta = widget.fecha.difference(_ahora);
    if (falta.isNegative) {
      return _Mensaje(
        texto: 'La posada ya pasó',
        estilo: tema.textTheme.titleLarge?.copyWith(
          color: tema.colorScheme.onSurfaceVariant,
        ),
      );
    }
    final t = TiempoRestante.de(falta);
    return Semantics(
      label:
          'Faltan ${t.dias} días, ${t.horas} horas, ${t.minutos} minutos '
          'y ${t.segundos} segundos',
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Unidad(valor: t.dias, etiqueta: 'días', acento: _colores[0]),
            _Unidad(valor: t.horas, etiqueta: 'horas', acento: _colores[1]),
            _Unidad(valor: t.minutos, etiqueta: 'min', acento: _colores[2]),
            _Unidad(valor: t.segundos, etiqueta: 'seg', acento: _colores[3]),
          ],
        ),
      ),
    );
  }

  static const _colores = [
    Color(0xFFFFC857),
    Color(0xFF2EE6C8),
    Color(0xFFFF9EE6),
    Color(0xFFFF8A94),
  ];
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.texto, required this.estilo});

  final String texto;
  final TextStyle? estilo;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      texto,
      textAlign: TextAlign.center,
      style: estilo?.copyWith(
        shadows: const [Shadow(color: Color(0xFFFFC857), blurRadius: 18)],
      ),
    ),
  );
}

class _Unidad extends StatelessWidget {
  const _Unidad({
    required this.valor,
    required this.etiqueta,
    required this.acento,
  });

  final int valor;
  final String etiqueta;
  final Color acento;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final texto = valor.toString().padLeft(2, '0');
    final reducido = movimientoReducido(context);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0x1AFFFFFF),
            border: Border.all(color: acento.withValues(alpha: 0.55)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: reducido
                      ? Duration.zero
                      : const Duration(milliseconds: 300),
                  transitionBuilder: (hijo, animacion) => FadeTransition(
                    opacity: animacion,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -0.35),
                        end: Offset.zero,
                      ).animate(animacion),
                      child: hijo,
                    ),
                  ),
                  child: Text(
                    texto,
                    key: ValueKey(texto),
                    style: tema.textTheme.headlineMedium?.copyWith(
                      color: acento,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Text(
                  etiqueta,
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
