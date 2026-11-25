import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/efectos/efectos.dart';
import '../models/adorno.dart';
import '../services/captura_foto.dart';
import '../services/musica_arbol.dart';
import '../viewmodels/arbol_view_model.dart';
import 'dibujos_adorno.dart';
import 'pintor_arbol.dart';
import 'taller_adorno.dart';

/// Árbol de Navidad virtual: cada persona cuelga esferas y regalos que se ven
/// al instante en la pantalla de todas. Fondo transparente (se ve el cielo del
/// shell). Solo se arrastran los adornos propios; tocar uno muestra quién lo
/// colgó y su mensaje.
class ArbolView extends StatefulWidget {
  const ArbolView({
    super.key,
    required this.viewModel,
    this.crearCaptura = CapturaFotoCamara.new,
    this.crearMusica = MusicaArbolAudio.new,
  });

  final ArbolViewModel viewModel;

  /// Crea el acceso a la cámara del taller (patrón «foto»).
  final CapturaFoto Function() crearCaptura;

  /// Crea el reproductor de la música de fondo (Jingle Bells en loop).
  final MusicaArbol Function() crearMusica;

  @override
  State<ArbolView> createState() => _ArbolViewState();
}

/// Proporción ancho/alto del área del árbol (coordenadas normalizadas).
const double _proporcion = 0.8;

class _ArbolViewState extends State<ArbolView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reloj = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  String? _seleccionado;
  String? _arrastrando;
  Offset _acumulado = Offset.zero;

  /// Adornos que ya estaban al cargar: no se animan al entrar (solo los que
  /// llegan después caen con rebote).
  final Set<String> _conocidos = {};
  bool _inicializado = false;
  bool _reducido = false;

  late final MusicaArbol _musica = widget.crearMusica();

  /// Si la persona quiere música (activa por defecto hasta que la silencia).
  bool _quiereMusica = true;
  bool _sonando = false;

  /// Los navegadores bloquean el autoplay: si el intento al abrir falla, se
  /// reintenta una sola vez con el primer toque dentro de la vista.
  bool _reintentoPendiente = false;
  bool _toqueEnBoton = false;

  @override
  void initState() {
    super.initState();
    _arrancarMusica(alAbrir: true);
  }

  Future<void> _arrancarMusica({bool alAbrir = false}) async {
    var ok = false;
    try {
      ok = await _musica.iniciar();
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    if (!_quiereMusica) {
      // Se silenció mientras arrancaba.
      if (ok) _detenerMusica();
      return;
    }
    setState(() {
      _sonando = ok;
      _reintentoPendiente = alAbrir && !ok;
    });
  }

  void _detenerMusica() {
    _musica.pausar().catchError((Object _) {});
  }

  void _alternarMusica() {
    if (_sonando) {
      setState(() {
        _quiereMusica = false;
        _sonando = false;
      });
      _detenerMusica();
    } else {
      _quiereMusica = true;
      _reintentoPendiente = false;
      _arrancarMusica();
    }
  }

  /// Primer toque en la vista tras un arranque bloqueado por el navegador.
  void _alTocarVista() {
    if (_toqueEnBoton) {
      _toqueEnBoton = false;
      return;
    }
    if (_reintentoPendiente && _quiereMusica && !_sonando) {
      _reintentoPendiente = false;
      _arrancarMusica();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducido = movimientoReducido(context);
    if (_reducido) {
      _reloj
        ..stop()
        ..value = 0.35;
    } else if (!_reloj.isAnimating) {
      _reloj.repeat();
    }
  }

  @override
  void dispose() {
    _musica.liberar().catchError((Object _) {});
    _reloj.dispose();
    super.dispose();
  }

  ArbolViewModel get _vm => widget.viewModel;

  Future<void> _abrirTaller({Adorno? editando}) {
    final ctx = context;
    return showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (hoja) => TallerAdorno(
        viewModel: _vm,
        crearCaptura: widget.crearCaptura,
        editando: editando,
        alTerminar: (nuevo) {
          Navigator.of(hoja).pop();
          if (nuevo && mounted) {
            lanzarConfeti(context, origen: const Alignment(0, -0.1));
          }
        },
      ),
    );
  }

  void _iniciarArrastre(Adorno a, Size area) {
    setState(() {
      _arrastrando = a.id;
      _seleccionado = null;
      _acumulado = Offset(a.x * area.width, a.y * area.height);
    });
  }

  void _arrastrar(String id, Offset delta, Size area) {
    _acumulado += delta;
    _vm.mover(id, _acumulado.dx / area.width, _acumulado.dy / area.height);
  }

  void _soltar(String id) {
    if (_arrastrando != id) return;
    _vm.terminarMovimiento(id);
    if (mounted) setState(() => _arrastrando = null);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        if (!_vm.cargando && !_inicializado) {
          _inicializado = true;
          _conocidos.addAll(_vm.adornos.map((a) => a.id));
        }
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _alTocarVista(),
          child: Column(
            children: [
              _Encabezado(
                viewModel: _vm,
                alCrear: () => _abrirTaller(),
                sonando: _sonando,
                alAlternarMusica: _alternarMusica,
                alPulsarBoton: () => _toqueEnBoton = true,
              ),
              if (_vm.error != null)
                _Aviso(texto: _vm.error!, alCerrar: _vm.limpiarError),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, caja) {
                    final ancho = math.min(
                      caja.maxWidth,
                      caja.maxHeight * _proporcion,
                    );
                    if (!ancho.isFinite || ancho <= 0) {
                      return const SizedBox.shrink();
                    }
                    final area = Size(ancho, ancho / _proporcion);
                    return Center(
                      child: SizedBox.fromSize(size: area, child: _arbol(area)),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _arbol(Size area) {
    if (_vm.cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    final adornos = _vm.adornos;
    Adorno? elegido;
    for (final a in adornos) {
      if (a.id == _seleccionado) elegido = a;
    }
    // Si el adorno elegido desapareció, no hay tarjeta.
    final tamano = (area.width * 0.1).clamp(30.0, 52.0);
    final caja = math.max(tamano, 44.0);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: GestureDetector(
            key: const Key('fondo-arbol'),
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_seleccionado != null) setState(() => _seleccionado = null);
            },
            child: RepaintBoundary(
              child: CustomPaint(
                painter: PintorArbol(reloj: _reloj, animado: !_reducido),
              ),
            ),
          ),
        ),
        for (final a in adornos)
          AnimatedPositioned(
            key: ValueKey(a.id),
            duration: (_arrastrando == a.id || _reducido)
                ? Duration.zero
                : const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            left: a.x * area.width - caja / 2,
            top: a.y * area.height - caja / 2,
            width: caja,
            height: caja,
            child: _AdornoColgado(
              adorno: a,
              tamano: tamano,
              reloj: _reloj,
              animar: !_reducido,
              entra: _inicializado && !_conocidos.contains(a.id),
              caida: area.height * 0.5,
              propio: _vm.puedeMover(a),
              seleccionado: a.id == _seleccionado,
              alTocar: () => setState(
                () => _seleccionado = _seleccionado == a.id ? null : a.id,
              ),
              alIniciarArrastre: () => _iniciarArrastre(a, area),
              alArrastrar: (d) => _arrastrar(a.id, d, area),
              alSoltar: () => _soltar(a.id),
            ),
          ),
        if (_vm.vacio)
          const IgnorePointer(
            child: Align(
              alignment: Alignment(0, 0.1),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'El árbol espera su primer adorno.\nCrea una esfera o un regalo.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        if (elegido != null) _tarjeta(elegido, area, tamano),
      ],
    );
  }

  Widget _tarjeta(Adorno a, Size area, double tamano) {
    final ancho = math.min(230.0, area.width - 8);
    final izq = (a.x * area.width - ancho / 2)
        .clamp(4.0, math.max(4.0, area.width - ancho - 4))
        .toDouble();
    final arriba = a.y * area.height - tamano / 2 - 112;
    final top = arriba >= 0 ? arriba : a.y * area.height + tamano / 2 + 8;
    final tema = Theme.of(context);
    return Positioned(
      left: izq,
      top: top,
      width: ancho,
      child: TarjetaCristal(
        key: const Key('tarjeta-adorno'),
        inclinacion: false,
        radio: 18,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _vm.nombreAutor(a.autorId),
              style: tema.textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              a.mensaje.isEmpty ? 'Sin mensaje' : a.mensaje,
              style: tema.textTheme.bodyMedium?.copyWith(
                fontStyle: a.mensaje.isEmpty ? FontStyle.italic : null,
              ),
            ),
            if (_vm.puedeEditar(a) || _vm.puedeEliminar(a))
              Wrap(
                alignment: WrapAlignment.end,
                children: [
                  if (_vm.puedeEditar(a))
                    TextButton(
                      key: const Key('editar-adorno'),
                      onPressed: () {
                        setState(() => _seleccionado = null);
                        _abrirTaller(editando: a);
                      },
                      child: const Text('Editar'),
                    ),
                  if (_vm.puedeEliminar(a))
                    TextButton(
                      key: const Key('quitar-adorno'),
                      onPressed: () {
                        setState(() => _seleccionado = null);
                        _vm.eliminar(a.id);
                      },
                      child: const Text('Quitar'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({
    required this.viewModel,
    required this.alCrear,
    required this.sonando,
    required this.alAlternarMusica,
    required this.alPulsarBoton,
  });

  final ArbolViewModel viewModel;
  final VoidCallback alCrear;
  final bool sonando;
  final VoidCallback alAlternarMusica;

  /// Avisa al contenedor de que el toque fue en el botón de música (para que
  /// no cuente como el «primer toque» que arranca la melodía).
  final VoidCallback alPulsarBoton;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              TarjetaCristal(
                inclinacion: false,
                radio: 20,
                desenfoque: 10,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Mis adornos ${viewModel.cantidadMios}/${LimitesArbol.maxAdornos}',
                      style: tema.textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Listener(
                    onPointerDown: (_) => alPulsarBoton(),
                    child: IconButton(
                      key: const Key('musica-toggle'),
                      tooltip: sonando ? 'Silenciar música' : 'Activar música',
                      onPressed: alAlternarMusica,
                      icon: Icon(sonando ? Icons.music_note : Icons.music_off),
                    ),
                  ),
                  const SizedBox(width: 4),
                  BotonBrillante(
                    etiqueta: 'Crear adorno',
                    icono: Icons.add,
                    onPressed: alCrear,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Arrastra tus adornos para moverlos. Toca uno para ver quién lo colgó.',
            textAlign: TextAlign.center,
            style: tema.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto, required this.alCerrar});

  final String texto;
  final VoidCallback alCerrar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Material(
        color: tema.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  texto,
                  key: const Key('aviso-arbol'),
                  style: TextStyle(color: tema.colorScheme.onErrorContainer),
                ),
              ),
              IconButton(
                tooltip: 'Cerrar aviso',
                onPressed: alCerrar,
                icon: Icon(
                  Icons.close,
                  color: tema.colorScheme.onErrorContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un adorno colgado: tamaño fijo, balanceo suave (esferas) y caída con
/// rebote al aparecer. Si es propio se arrastra con el dedo.
class _AdornoColgado extends StatelessWidget {
  const _AdornoColgado({
    required this.adorno,
    required this.tamano,
    required this.reloj,
    required this.animar,
    required this.entra,
    required this.caida,
    required this.propio,
    required this.seleccionado,
    required this.alTocar,
    required this.alIniciarArrastre,
    required this.alArrastrar,
    required this.alSoltar,
  });

  final Adorno adorno;
  final double tamano;
  final Animation<double> reloj;
  final bool animar;
  final bool entra;
  final double caida;
  final bool propio;
  final bool seleccionado;
  final VoidCallback alTocar;
  final VoidCallback alIniciarArrastre;
  final ValueChanged<Offset> alArrastrar;
  final VoidCallback alSoltar;

  @override
  Widget build(BuildContext context) {
    // Fase estable por adorno para que no se balanceen al unísono.
    final fase = (adorno.id.hashCode % 100) / 100;
    Widget dibujo = RepaintBoundary(
      child: DibujoAdorno(adorno: adorno, tamano: tamano),
    );
    if (seleccionado) {
      dibujo = DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFC857).withValues(alpha: 0.75),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: dibujo,
      );
    }
    if (animar && adorno.tipo == TipoAdorno.esfera) {
      final hijo = dibujo;
      dibujo = AnimatedBuilder(
        animation: reloj,
        child: hijo,
        builder: (context, hijo) => Transform.rotate(
          angle: math.sin(2 * math.pi * (reloj.value * 2 + fase)) * 0.07,
          alignment: Alignment.topCenter,
          child: hijo,
        ),
      );
    }
    final contenido = TweenAnimationBuilder<double>(
      tween: Tween(begin: entra && animar ? 0.0 : 1.0, end: 1.0),
      duration: entra && animar
          ? const Duration(milliseconds: 900)
          : Duration.zero,
      curve: Curves.bounceOut,
      child: dibujo,
      builder: (context, v, hijo) {
        if (v >= 1) return hijo!;
        return Opacity(
          opacity: math.min(1.0, v * 6),
          child: Transform.translate(
            offset: Offset(0, -(1 - v) * caida),
            child: hijo,
          ),
        );
      },
    );

    return Semantics(
      button: true,
      label: adorno.tipo == TipoAdorno.esfera ? 'Esfera' : 'Regalo',
      child: MouseRegion(
        cursor: propio ? SystemMouseCursors.grab : SystemMouseCursors.click,
        child: GestureDetector(
          key: Key('adorno-${adorno.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: alTocar,
          onPanStart: propio ? (_) => alIniciarArrastre() : null,
          onPanUpdate: propio ? (d) => alArrastrar(d.delta) : null,
          onPanEnd: propio ? (_) => alSoltar() : null,
          onPanCancel: propio ? alSoltar : null,
          child: Center(
            child: SizedBox(width: tamano, height: tamano, child: contenido),
          ),
        ),
      ),
    );
  }
}
