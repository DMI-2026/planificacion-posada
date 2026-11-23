import 'package:flutter/material.dart';

import '../../features/aportaciones/repositories/aportacion_repository.dart';
import '../../features/aportaciones/viewmodels/aportaciones_view_model.dart';
import '../../features/evento/repositories/evento_repository.dart';
import '../../features/evento/viewmodels/evento_view_model.dart';
import '../../features/participantes/repositories/participante_repository.dart';
import '../../features/participantes/viewmodels/participantes_view_model.dart';
import 'posada_scope.dart';
import 'shell_posada.dart';

/// Contenido de la app con sesión iniciada.
///
/// Crea los viewmodels (y con ellos las suscripciones a Firestore) al entrar
/// y los libera al salir, así no hay lecturas antes de iniciar sesión ni
/// después de cerrarla.
class SesionActiva extends StatefulWidget {
  const SesionActiva({
    super.key,
    required this.eventoRepository,
    required this.participanteRepository,
    required this.aportacionRepository,
    required this.onCerrarSesion,
  });

  final EventoRepository eventoRepository;
  final ParticipanteRepository participanteRepository;
  final AportacionRepository aportacionRepository;
  final VoidCallback onCerrarSesion;

  @override
  State<SesionActiva> createState() => _SesionActivaState();
}

class _SesionActivaState extends State<SesionActiva> {
  late final EventoViewModel _evento;
  late final ParticipantesViewModel _participantes;
  late final AportacionesViewModel _aportaciones;

  @override
  void initState() {
    super.initState();
    _evento = EventoViewModel(widget.eventoRepository);
    _participantes = ParticipantesViewModel(widget.participanteRepository);
    _aportaciones = AportacionesViewModel(widget.aportacionRepository);
  }

  @override
  void dispose() {
    _evento.dispose();
    _participantes.dispose();
    _aportaciones.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PosadaScope(
      evento: _evento,
      participantes: _participantes,
      aportaciones: _aportaciones,
      child: ShellPosada(onCerrarSesion: widget.onCerrarSesion),
    );
  }
}
