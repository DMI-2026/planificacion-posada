import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/efectos/efectos.dart';
import '../../../core/theme/app_theme.dart';
import '../viewmodels/intercambio_view_model.dart';

/// Caja de regalo envuelta que se toca para abrirla: la tapa sale volando,
/// hay un destello y confeti, y aparece a quién le regalas y qué desea.
/// Con movimiento reducido el regalo se abre de golpe, sin animación.
class RegaloSorpresa extends StatefulWidget {
  const RegaloSorpresa({super.key, required this.destinatario});

  final MiDestinatario destinatario;

  @override
  State<RegaloSorpresa> createState() => _RegaloSorpresaState();
}

class _RegaloSorpresaState extends State<RegaloSorpresa>
    with TickerProviderStateMixin {
  late final AnimationController _apertura = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  late final AnimationController _flota = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  bool _abierto = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_abierto || movimientoReducido(context)) {
      _flota.stop();
    } else if (!_flota.isAnimating) {
      _flota.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _apertura.dispose();
    _flota.dispose();
    super.dispose();
  }

  void _abrir() {
    if (_abierto) return;
    setState(() => _abierto = true);
    _flota.stop();
    if (movimientoReducido(context)) {
      _apertura.value = 1;
      return;
    }
    _apertura.forward();
    lanzarConfeti(context, origen: const Alignment(0, -0.2), cantidad: 120);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: !_abierto,
          label: _abierto ? 'Regalo abierto' : 'Abrir tu regalo sorpresa',
          excludeSemantics: true,
          child: GestureDetector(
            key: const Key('regalo-sorpresa'),
            behavior: HitTestBehavior.opaque,
            onTap: _abrir,
            child: SizedBox(
              height: 230,
              child: AnimatedBuilder(
                animation: Listenable.merge([_apertura, _flota]),
                builder: (context, _) => _dibujo(),
              ),
            ),
          ),
        ),
        if (!_abierto)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Toca el regalo para descubrir a quién le regalas',
              textAlign: TextAlign.center,
              style: tema.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textoSuave,
              ),
            ),
          ),
        if (_abierto)
          FadeTransition(
            opacity: CurvedAnimation(
              parent: _apertura,
              curve: const Interval(0.45, 1, curve: Curves.easeOut),
            ),
            child: _Revelacion(destinatario: widget.destinatario),
          ),
      ],
    );
  }

  Widget _dibujo() {
    final t = Curves.easeOutCubic.transform(
      const Interval(0, 0.55).transform(_apertura.value),
    );
    final brillo = math.sin(math.pi * _apertura.value.clamp(0.0, 1.0));
    final flota = math.sin(_flota.value * math.pi) * 8;
    const ancho = 150.0, cuerpo = 100.0, tapa = 34.0;
    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        // Destello detrás de la caja.
        Positioned(
          bottom: 20,
          child: Opacity(
            opacity: (0.25 + 0.75 * brillo).clamp(0.0, 1.0),
            child: Container(
              width: 120 + 160 * brillo,
              height: 120 + 160 * brillo,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.oro.withValues(alpha: 0.75),
                    AppTheme.auroraMagenta.withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 16 + flota,
          child: SizedBox(
            width: ancho,
            height: cuerpo + tapa + 30,
            child: Stack(
              alignment: Alignment.bottomCenter,
              clipBehavior: Clip.none,
              children: [
                // Cuerpo.
                Container(
                  width: ancho - 14,
                  height: cuerpo,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(10),
                    ),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppTheme.rojoFestivo, Color(0xFF8E1220)],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Container(width: 22, color: AppTheme.oro),
                ),
                // Tapa que sale volando.
                Positioned(
                  bottom: cuerpo - 4,
                  child: Opacity(
                    opacity: (1 - t).clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(60 * t, -170 * t),
                      child: Transform.rotate(
                        angle: 0.9 * t,
                        child: _Tapa(ancho: ancho, alto: tapa),
                      ),
                    ),
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

class _Tapa extends StatelessWidget {
  const _Tapa({required this.ancho, required this.alto});

  final double ancho;
  final double alto;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ancho,
      height: alto + 26,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: ancho,
            height: alto,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: const LinearGradient(
                colors: [Color(0xFFE63946), AppTheme.rojoFestivo],
              ),
            ),
            alignment: Alignment.center,
            child: Container(width: 22, color: AppTheme.oro),
          ),
          // Moño.
          Positioned(
            bottom: alto - 6,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.rotate(
                  angle: -0.5,
                  child: const Icon(
                    Icons.local_florist,
                    color: AppTheme.oro,
                    size: 30,
                  ),
                ),
                Transform.rotate(
                  angle: 0.5,
                  child: const Icon(
                    Icons.local_florist,
                    color: AppTheme.oro,
                    size: 30,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Revelacion extends StatelessWidget {
  const _Revelacion({required this.destinatario});

  final MiDestinatario destinatario;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return TarjetaCristal(
      acento: AppTheme.oro,
      inclinacion: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Le regalas a',
            style: tema.textTheme.labelLarge?.copyWith(
              color: AppTheme.textoSuave,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            destinatario.nombre,
            textAlign: TextAlign.center,
            style: tema.textTheme.headlineMedium?.copyWith(
              color: AppTheme.oro,
              fontFamily: AppTheme.fuenteTitulos,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (destinatario.deseos.isEmpty)
            Text(
              'No dejó deseos: ¡sorpréndele!',
              style: tema.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textoSuave,
              ),
            )
          else ...[
            Text(
              'Le haría ilusión',
              style: tema.textTheme.labelLarge?.copyWith(
                color: AppTheme.textoSuave,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in destinatario.deseos)
                  Chip(
                    avatar: const Icon(Icons.card_giftcard, size: 16),
                    label: Text(d),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
