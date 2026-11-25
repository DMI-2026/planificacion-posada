import 'package:flutter/material.dart';

import '../../arbol/services/captura_foto.dart';
import '../repositories/cohetazo_repository.dart';
import 'pantalla_entrada.dart';
import 'vista_arena.dart';

/// Módulo «Cohetazo navideño»: pantalla de entrada (foto de avatar) y arena.
///
/// El repositorio de la arena se crea solo al entrar a jugar, y al salir de la
/// pantalla (o pulsar «Salir») el jugador se borra de la arena.
class CohetazoView extends StatefulWidget {
  const CohetazoView({
    super.key,
    required this.uid,
    required this.nombre,
    required this.crearRepositorio,
    this.crearCaptura = CapturaFotoCamara.new,
    this.reloj,
  });

  final String uid;
  final String nombre;
  final CohetazoRepository Function() crearRepositorio;

  /// Acceso a la cámara para el avatar (sustituible en pruebas).
  final CapturaFoto Function() crearCaptura;

  /// Hora local en ms (sustituible en pruebas).
  final int Function()? reloj;

  @override
  State<CohetazoView> createState() => _CohetazoViewState();
}

class _CohetazoViewState extends State<CohetazoView> {
  String? _avatar;
  bool _jugando = false;

  @override
  Widget build(BuildContext context) {
    final avatar = _avatar;
    if (_jugando && avatar != null) {
      return VistaArena(
        key: const Key('vista-arena'),
        uid: widget.uid,
        nombre: widget.nombre,
        avatar: avatar,
        crearRepositorio: widget.crearRepositorio,
        reloj: widget.reloj,
        onSalir: () => setState(() => _jugando = false),
      );
    }
    return PantallaEntrada(
      uid: widget.uid,
      nombre: widget.nombre,
      crearCaptura: widget.crearCaptura,
      avatarInicial: avatar,
      onEntrar: (a) => setState(() {
        _avatar = a;
        _jugando = true;
      }),
    );
  }
}
