import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../arbol/views/fotos_esfera.dart';
import '../juego/reglas_cohetazo.dart';
import '../models/direccion.dart';
import '../repositories/cohetazo_repository.dart';
import '../viewmodels/cohetazo_view_model.dart';
import 'controles_tactiles.dart';
import 'marcador_arena.dart';
import 'pintor_arena.dart';

/// Ancho por debajo del cual se consideran pantallas de teléfono: los
/// controles táctiles aparecen solos y el marcador empieza replegado.
const double anchoTelefono = 600;

/// La arena en juego: bucle con `Ticker`, teclado, controles táctiles, barra
/// de estado y marcador. Al salir de la pantalla borra al jugador de la arena.
class VistaArena extends StatefulWidget {
  const VistaArena({
    super.key,
    required this.uid,
    required this.nombre,
    required this.avatar,
    required this.crearRepositorio,
    required this.onSalir,
    this.reloj,
  });

  final String uid;
  final String nombre;
  final String avatar;
  final CohetazoRepository Function() crearRepositorio;

  /// Se llama al pulsar «Salir» (la pantalla padre vuelve a la entrada).
  final VoidCallback onSalir;
  final int Function()? reloj;

  @override
  State<VistaArena> createState() => _VistaArenaState();
}

class _VistaArenaState extends State<VistaArena>
    with SingleTickerProviderStateMixin {
  late final CohetazoViewModel _vm;
  late final Ticker _ticker;
  final FocusNode _foco = FocusNode(debugLabel: 'arena');
  final List<Direccion> _teclas = [];
  Direccion? _toque;
  Duration _anterior = Duration.zero;

  final Map<String, ui.Image> _imagenes = {};
  final Map<String, String> _origen = {};

  /// null hasta que la persona use el interruptor: entonces manda su elección.
  bool? _controlesElegidos;

  @override
  void initState() {
    super.initState();
    _vm = CohetazoViewModel(
      widget.crearRepositorio(),
      uid: widget.uid,
      nombre: widget.nombre,
      avatar: widget.avatar,
      reloj: widget.reloj,
    )..addListener(_alCambiar);
    _foco.addListener(() {
      if (!_foco.hasFocus) {
        _teclas.clear();
        _aplicarEntrada();
      }
    });
    _ticker = createTicker(_alCuadro)..start();
    unawaited(_vm.iniciar());
  }

  void _alCambiar() => _sincronizarAvatares();

  void _alCuadro(Duration t) {
    final dt = (t - _anterior).inMicroseconds / 1e6;
    _anterior = t;
    _vm.paso(dt.clamp(0.0, 0.1));
  }

  /// Decodifica una sola vez cada avatar nuevo (o cambiado).
  void _sincronizarAvatares() {
    for (final e in _vm.avatares.entries) {
      if (_origen[e.key] == e.value) continue;
      _origen[e.key] = e.value;
      FotosEsfera.cargar(e.value).then((imagen) {
        if (!mounted || imagen == null || _origen[e.key] != e.value) return;
        _imagenes[e.key] = imagen;
      });
    }
    _origen.removeWhere((uid, _) {
      final sigue = _vm.avatares.containsKey(uid);
      if (!sigue) _imagenes.remove(uid);
      return !sigue;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _foco.dispose();
    _vm
      ..removeListener(_alCambiar)
      ..salir()
      ..dispose();
    super.dispose();
  }

  // ----------------------------------------------------------------- Entrada

  static Direccion? _direccionDe(LogicalKeyboardKey k) {
    if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.keyW) {
      return Direccion.arriba;
    }
    if (k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.keyS) {
      return Direccion.abajo;
    }
    if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.keyA) {
      return Direccion.izquierda;
    }
    if (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.keyD) {
      return Direccion.derecha;
    }
    return null;
  }

  KeyEventResult _alTecla(FocusNode nodo, KeyEvent e) {
    final d = _direccionDe(e.logicalKey);
    if (d != null) {
      if (e is KeyDownEvent) {
        _teclas
          ..remove(d)
          ..add(d);
      } else if (e is KeyUpEvent) {
        _teclas.remove(d);
      }
      _aplicarEntrada();
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.space) {
      if (e is KeyDownEvent) unawaited(_vm.colocarCohete());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// La dirección del dedo manda; si no, la última tecla pulsada.
  void _aplicarEntrada() =>
      _vm.sostener(_toque ?? (_teclas.isEmpty ? null : _teclas.last));

  void _alDpad(Direccion? d) {
    _toque = d;
    _aplicarEntrada();
  }

  bool _controlesVisibles(double ancho) {
    final elegido = _controlesElegidos;
    if (elegido != null) return elegido;
    final movil =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    return ancho < anchoTelefono || movil;
  }

  // ------------------------------------------------------------------ Build

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    return Focus(
      focusNode: _foco,
      autofocus: true,
      onKeyEvent: _alTecla,
      child: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) {
          switch (_vm.fase) {
            case FaseCohetazo.conectando:
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(key: Key('conectando-arena')),
                    SizedBox(height: 12),
                    Text('Entrando a la arena…'),
                  ],
                ),
              );
            case FaseCohetazo.error:
              return _Error(
                mensaje: _vm.error ?? 'No pudimos entrar a la arena.',
                onReintentar: () => unawaited(_vm.iniciar()),
                onVolver: widget.onSalir,
              );
            case FaseCohetazo.jugando:
              return _juego(context, ancho);
          }
        },
      ),
    );
  }

  Widget _juego(BuildContext context, double ancho) {
    final controles = _controlesVisibles(ancho);
    final compacto = ancho < anchoTelefono;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Column(
        children: [
          _BarraEstado(
            vm: _vm,
            controlesVisibles: controles,
            onAlternarControles: () =>
                setState(() => _controlesElegidos = !controles),
            onSalir: widget.onSalir,
          ),
          if (_vm.aviso != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Material(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
                child: ListTile(
                  key: const Key('aviso-arena'),
                  dense: true,
                  title: Text(_vm.aviso!),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Cerrar aviso',
                    onPressed: _vm.limpiarAviso,
                  ),
                ),
              ),
            ),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: ReglasCohetazo.columnas / ReglasCohetazo.filas,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _foco.requestFocus,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      RepaintBoundary(
                        child: CustomPaint(
                          key: const Key('lienzo-arena'),
                          painter: PintorArena(
                            vm: _vm,
                            imagen: (uid) => _imagenes[uid],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: MarcadorArena(
                          viewModel: _vm,
                          compacto: compacto,
                        ),
                      ),
                      Positioned.fill(child: _MensajeMuerte(vm: _vm)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (controles)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ControlesTactiles(
                onDireccion: _alDpad,
                onCohete: () => unawaited(_vm.colocarCohete()),
              ),
            ),
        ],
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({
    required this.mensaje,
    required this.onReintentar,
    required this.onVolver,
  });

  final String mensaje;
  final VoidCallback onReintentar;
  final VoidCallback onVolver;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppTheme.textoSuave),
            const SizedBox(height: 12),
            Text(
              mensaje,
              key: const Key('error-arena'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  key: const Key('reintentar-arena'),
                  onPressed: onReintentar,
                  child: const Text('Reintentar'),
                ),
                TextButton(onPressed: onVolver, child: const Text('Volver')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Aviso en el centro de la arena mientras se está fuera de combate.
class _MensajeMuerte extends StatelessWidget {
  const _MensajeMuerte({required this.vm});

  final CohetazoViewModel vm;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vm.repintar,
      builder: (context, _) {
        if (vm.yo.vivo) return const SizedBox.shrink();
        final falta = ((vm.yo.reaparece - vm.ahora) / 1000).ceil().clamp(0, 99);
        return IgnorePointer(
          child: Center(
            child: Container(
              key: const Key('mensaje-muerte'),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xCC070B1F),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.rojoFestivo),
              ),
              child: Text(
                'Te alcanzó un cohete. Reapareces en $falta s',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.texto,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BarraEstado extends StatelessWidget {
  const _BarraEstado({
    required this.vm,
    required this.controlesVisibles,
    required this.onAlternarControles,
    required this.onSalir,
  });

  final CohetazoViewModel vm;
  final bool controlesVisibles;
  final VoidCallback onAlternarControles;
  final VoidCallback onSalir;

  @override
  Widget build(BuildContext context) {
    final yo = vm.yo;
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Dato(
                clave: 'en-linea',
                icono: Icons.group,
                texto: '${vm.enLinea}',
                tooltip: 'Jugadores en línea',
              ),
              _Dato(
                clave: 'stat-alcance',
                icono: Icons.local_fire_department,
                texto: '${yo.alcance}',
                tooltip: 'Alcance',
              ),
              _Dato(
                clave: 'stat-cohetes',
                icono: Icons.rocket_launch,
                texto: '${yo.cohetes}',
                tooltip: 'Cohetes simultáneos',
              ),
              _Dato(
                clave: 'stat-velocidad',
                icono: Icons.bolt,
                texto: '${yo.velocidad}',
                tooltip: 'Velocidad',
              ),
            ],
          ),
        ),
        IconButton(
          key: const Key('alternar-controles'),
          tooltip: controlesVisibles
              ? 'Ocultar controles táctiles'
              : 'Mostrar controles táctiles',
          icon: Icon(
            controlesVisibles ? Icons.gamepad : Icons.gamepad_outlined,
          ),
          onPressed: onAlternarControles,
        ),
        IconButton(
          key: const Key('salir-arena'),
          tooltip: 'Salir de la arena',
          icon: const Icon(Icons.logout),
          onPressed: onSalir,
        ),
      ],
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({
    required this.clave,
    required this.icono,
    required this.texto,
    required this.tooltip,
  });

  final String clave;
  final IconData icono;
  final String texto;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        key: Key(clave),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0x99141C4A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 16, color: AppTheme.oro),
            const SizedBox(width: 4),
            Text(texto, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
