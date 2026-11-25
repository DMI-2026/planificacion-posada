import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/efectos/efectos.dart';
import '../../../core/theme/app_theme.dart';
import '../../arbol/services/captura_foto.dart';
import '../../arbol/views/captura_foto_dialogo.dart';
import '../juego/reglas_cohetazo.dart';
import '../services/avatar_iniciales.dart';

/// Pantalla de entrada: reglas, foto de avatar con la webcam y el botón para
/// entrar a la arena.
///
/// La foto es obligatoria. Si la cámara no está disponible (sin cámara, sin
/// permiso o sitio sin https) se explica el motivo, se puede reintentar y se
/// ofrece, claramente señalado, un avatar de iniciales para poder jugar igual.
class PantallaEntrada extends StatefulWidget {
  const PantallaEntrada({
    super.key,
    required this.uid,
    required this.nombre,
    required this.crearCaptura,
    required this.onEntrar,
    this.avatarInicial,
  });

  final String uid;
  final String nombre;
  final CapturaFoto Function() crearCaptura;

  /// Recibe el avatar (base64 JPEG) con el que se entra.
  final ValueChanged<String> onEntrar;
  final String? avatarInicial;

  @override
  State<PantallaEntrada> createState() => _PantallaEntradaState();
}

/// Envuelve la captura para saber por qué falló la cámara (el diálogo solo
/// devuelve `null`).
class _CapturaVigilada implements CapturaFoto {
  _CapturaVigilada(this._interna, this._alFallar);

  final CapturaFoto _interna;
  final ValueChanged<String> _alFallar;

  @override
  Future<void> iniciar() async {
    try {
      await _interna.iniciar();
    } on CapturaFotoException catch (e) {
      _alFallar(e.mensaje);
      rethrow;
    } catch (_) {
      _alFallar('No pudimos abrir la cámara.');
      rethrow;
    }
  }

  @override
  Widget vista(BuildContext context) => _interna.vista(context);

  @override
  Future<Uint8List> tomar() async {
    try {
      return await _interna.tomar();
    } on CapturaFotoException catch (e) {
      _alFallar(e.mensaje);
      rethrow;
    }
  }

  @override
  Future<void> liberar() => _interna.liberar();
}

class _PantallaEntradaState extends State<PantallaEntrada> {
  String? _avatar;
  bool _soloIniciales = false;
  String? _errorCamara;

  @override
  void initState() {
    super.initState();
    _avatar = widget.avatarInicial;
  }

  Future<void> _tomarFoto() async {
    _errorCamara = null;
    final foto = await pedirFotoEsfera(
      context,
      () => _CapturaVigilada(widget.crearCaptura(), (m) => _errorCamara = m),
      titulo: 'Foto de avatar',
      lado: ReglasCohetazo.avatarLado,
      maxBase64: ReglasCohetazo.avatarMaxLongitud,
    );
    if (!mounted) return;
    setState(() {
      if (foto != null) {
        _avatar = foto;
        _soloIniciales = false;
        _errorCamara = null;
      }
    });
  }

  void _usarIniciales() => setState(() {
    _avatar = generarAvatarIniciales(widget.nombre, widget.uid);
    _soloIniciales = true;
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TituloMagico(
                'Cohetazo navideño',
                textAlign: TextAlign.center,
                estilo: tema.textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Una arena nevada, cohetes y cajas de regalo. ¡Toda la posada '
                'juega al mismo tiempo!',
                textAlign: TextAlign.center,
                style: tema.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textoSuave,
                ),
              ),
              const SizedBox(height: 16),
              TarjetaCristal(
                inclinacion: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reglas', style: tema.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const _Regla(
                      Icons.keyboard,
                      'Muévete con las flechas o WASD y coloca un cohete con '
                      'la barra espaciadora. En el teléfono usa el D-pad y el '
                      'botón del cohete.',
                    ),
                    const _Regla(
                      Icons.rocket_launch,
                      'Cada cohete explota a los 2,5 s en cruz. Las cajas de '
                      'regalo detienen el fuego y se rompen: a veces sueltan '
                      'mejoras de alcance, cohetes o velocidad.',
                    ),
                    const _Regla(
                      Icons.emoji_events,
                      'Si un cohete te alcanza reapareces a los 3 s y pierdes '
                      'las mejoras. +1 punto por eliminar a alguien, -1 si te '
                      'eliminas tú.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _Avatar(avatar: _avatar, soloIniciales: _soloIniciales),
              const SizedBox(height: 4),
              Text(
                'Jugarás como ${widget.nombre}',
                key: const Key('nombre-jugador'),
                style: tema.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              if (_errorCamara != null) ...[
                _ErrorCamara(
                  mensaje: _errorCamara!,
                  onReintentar: _tomarFoto,
                  onIniciales: _usarIniciales,
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton.icon(
                key: const Key('tomar-avatar'),
                onPressed: _tomarFoto,
                icon: const Icon(Icons.photo_camera),
                label: Text(
                  _avatar == null || _soloIniciales
                      ? 'Tomar foto de avatar'
                      : 'Repetir foto de avatar',
                ),
              ),
              const SizedBox(height: 12),
              BotonBrillante(
                key: const Key('entrar-arena'),
                etiqueta: 'Entrar a la arena',
                icono: Icons.play_arrow,
                onPressed: _avatar == null
                    ? null
                    : () => widget.onEntrar(_avatar!),
              ),
              if (_avatar == null) ...[
                const SizedBox(height: 8),
                Text(
                  'Necesitas una foto para jugar. La cámara en la web solo '
                  'funciona con https o en localhost.',
                  textAlign: TextAlign.center,
                  key: const Key('aviso-foto-obligatoria'),
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textoSuave,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Regla extends StatelessWidget {
  const _Regla(this.icono, this.texto);

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: AppTheme.oro),
          const SizedBox(width: 8),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.avatar, required this.soloIniciales});

  final String? avatar;
  final bool soloIniciales;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.oro, width: 3),
            color: AppTheme.indigo,
          ),
          child: ClipOval(
            child: avatar == null
                ? const Icon(
                    Icons.person,
                    key: Key('avatar-vacio'),
                    size: 56,
                    color: AppTheme.textoSuave,
                  )
                : Image.memory(
                    base64Decode(avatar!),
                    key: const Key('avatar-vista'),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
          ),
        ),
        if (soloIniciales)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Avatar de iniciales (sin foto)',
              key: Key('etiqueta-iniciales'),
              style: TextStyle(
                color: AppTheme.oro,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _ErrorCamara extends StatelessWidget {
  const _ErrorCamara({
    required this.mensaje,
    required this.onReintentar,
    required this.onIniciales,
  });

  final String mensaje;
  final VoidCallback onReintentar;
  final VoidCallback onIniciales;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: esquema.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: esquema.error.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(mensaje, key: const Key('error-avatar')),
          const SizedBox(height: 4),
          const Text(
            'En la web la cámara solo funciona con https o en localhost. '
            'También puedes jugar sin foto, con tus iniciales.',
            style: TextStyle(color: AppTheme.textoSuave, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.tonalIcon(
                key: const Key('reintentar-avatar'),
                onPressed: onReintentar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
              TextButton.icon(
                key: const Key('usar-iniciales'),
                onPressed: onIniciales,
                icon: const Icon(Icons.badge_outlined),
                label: const Text('Jugar con mis iniciales'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
