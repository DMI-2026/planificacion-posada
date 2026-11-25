import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/captura_foto.dart';

/// Muestra la cámara en vivo y devuelve la miniatura base64 de la foto
/// aceptada, o `null` si se cancela o la cámara no se pudo usar.
Future<String?> pedirFotoEsfera(
  BuildContext context,
  CapturaFoto Function() crearCaptura,
) => showDialog<String>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _CapturaFotoDialogo(captura: crearCaptura()),
);

class _CapturaFotoDialogo extends StatefulWidget {
  const _CapturaFotoDialogo({required this.captura});

  final CapturaFoto captura;

  @override
  State<_CapturaFotoDialogo> createState() => _CapturaFotoDialogoState();
}

class _CapturaFotoDialogoState extends State<_CapturaFotoDialogo> {
  bool _listo = false;
  bool _ocupado = false;
  String? _error;
  String? _foto;

  @override
  void initState() {
    super.initState();
    _abrir();
  }

  Future<void> _abrir() async {
    try {
      await widget.captura.iniciar();
      if (!mounted) return;
      setState(() => _listo = true);
    } on CapturaFotoException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No pudimos abrir la cámara.');
      }
    }
  }

  Future<void> _tomar() async {
    setState(() => _ocupado = true);
    try {
      final bytes = await widget.captura.tomar();
      final miniatura = procesarFoto(bytes);
      if (!mounted) return;
      setState(() {
        _foto = miniatura;
        _ocupado = false;
      });
    } on CapturaFotoException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.mensaje;
          _ocupado = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'No pudimos tomar la foto. Intenta de nuevo.';
          _ocupado = false;
        });
      }
    }
  }

  @override
  void dispose() {
    widget.captura.liberar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final Widget cuerpo;
    final List<Widget> acciones;
    if (_error != null) {
      cuerpo = Text(
        _error!,
        key: const Key('error-camara'),
        style: tema.textTheme.bodyMedium?.copyWith(
          color: tema.colorScheme.error,
        ),
      );
      acciones = [
        TextButton(
          key: const Key('cerrar-camara'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ];
    } else if (_foto != null) {
      cuerpo = Center(
        child: ClipOval(
          child: Image.memory(
            base64Decode(_foto!),
            key: const Key('foto-capturada'),
            width: 200,
            height: 200,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        ),
      );
      acciones = [
        TextButton(
          key: const Key('repetir-foto'),
          onPressed: () => setState(() => _foto = null),
          child: const Text('Repetir'),
        ),
        FilledButton(
          key: const Key('aceptar-foto'),
          onPressed: () => Navigator.of(context).pop(_foto),
          child: const Text('Usar foto'),
        ),
      ];
    } else {
      cuerpo = _listo
          ? AspectRatio(aspectRatio: 1, child: widget.captura.vista(context))
          : const SizedBox(
              height: 120,
              child: Center(
                child: CircularProgressIndicator(key: Key('abriendo-camara')),
              ),
            );
      acciones = [
        TextButton(
          key: const Key('cancelar-foto'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          key: const Key('tomar-foto'),
          onPressed: (_listo && !_ocupado) ? _tomar : null,
          icon: const Icon(Icons.photo_camera),
          label: const Text('Tomar foto'),
        ),
      ];
    }
    return AlertDialog(
      title: const Text('Foto para la esfera'),
      content: SizedBox(width: 280, child: cuerpo),
      actions: acciones,
    );
  }
}
