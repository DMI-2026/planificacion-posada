import 'package:flutter/material.dart';

import '../../features/aportaciones/repositories/aportacion_repository.dart';
import '../../features/aportaciones/viewmodels/aportaciones_view_model.dart';
import '../../features/arbol/repositories/arbol_repository.dart';
import '../../features/arbol/viewmodels/arbol_view_model.dart';
import '../../features/auth/models/usuario.dart';
import '../../features/auth/repositories/admin_repository.dart';
import '../../features/auth/viewmodels/sesion_view_model.dart';
import '../../features/cohetazo/repositories/cohetazo_repository.dart';
import '../../features/cohetazo/repositories/rtdb_cohetazo_repository.dart';
import '../../features/evento/repositories/evento_repository.dart';
import '../../features/evento/viewmodels/evento_view_model.dart';
import '../../features/intercambio/repositories/intercambio_repository.dart';
import '../../features/intercambio/viewmodels/intercambio_view_model.dart';
import '../../features/itinerario/repositories/itinerario_repository.dart';
import '../../features/itinerario/viewmodels/itinerario_view_model.dart';
import '../../features/participantes/repositories/participante_repository.dart';
import '../../features/participantes/viewmodels/participantes_view_model.dart';
import '../../features/votacion/repositories/votacion_repository.dart';
import '../../features/votacion/viewmodels/votacion_view_model.dart';
import 'posada_scope.dart';
import 'shell_posada.dart';

/// Contenido de la app con sesión iniciada.
///
/// Crea los viewmodels (y con ellos las suscripciones a Firestore) al entrar
/// y los libera al salir, así no hay lecturas antes de iniciar sesión ni
/// después de cerrarla.
///
/// Votación, itinerario, árbol e intercambio dependen del rol (admin y
/// participante, que las reglas de Firestore exigen). Se crean al entrar y se
/// vuelven a crear solo cuando ese rol cambia (p. ej. al resolverse el admin o
/// aparecer la persona en la lista de participantes); los cambios de nombres
/// se les pasan sin recrearlos.
class SesionActiva extends StatefulWidget {
  const SesionActiva({
    super.key,
    required this.usuario,
    required this.adminRepository,
    required this.eventoRepository,
    required this.participanteRepository,
    required this.aportacionRepository,
    required this.votacionRepository,
    required this.itinerarioRepository,
    required this.arbolRepository,
    required this.intercambioRepository,
    this.crearRepositorioCohetazo = RtdbCohetazoRepository.new,
    required this.onCerrarSesion,
  });

  final Usuario usuario;
  final AdminRepository adminRepository;
  final EventoRepository eventoRepository;
  final ParticipanteRepository participanteRepository;
  final AportacionRepository aportacionRepository;
  final VotacionRepository votacionRepository;
  final ItinerarioRepository itinerarioRepository;
  final ArbolRepository arbolRepository;
  final IntercambioRepository intercambioRepository;

  /// Crea el repositorio de la arena del Cohetazo (Realtime Database).
  final CohetazoRepository Function() crearRepositorioCohetazo;
  final VoidCallback onCerrarSesion;

  @override
  State<SesionActiva> createState() => _SesionActivaState();
}

/// Los cuatro viewmodels que dependen del rol, creados juntos.
class _Modulos {
  _Modulos(this.votacion, this.itinerario, this.arbol, this.intercambio);

  final VotacionViewModel votacion;
  final ItinerarioViewModel itinerario;
  final ArbolViewModel arbol;
  final IntercambioViewModel intercambio;

  void dispose() {
    votacion.dispose();
    itinerario.dispose();
    arbol.dispose();
    intercambio.dispose();
  }
}

class _SesionActivaState extends State<SesionActiva> {
  late final SesionViewModel _sesion;
  late final EventoViewModel _evento;
  late final ParticipantesViewModel _participantes;
  late final AportacionesViewModel _aportaciones;
  late _Modulos _modulos;
  bool _esAdmin = false;
  bool _esParticipante = false;

  @override
  void initState() {
    super.initState();
    // Al crearse asegura participantes/{uid} y resuelve el rol de admin.
    _sesion = SesionViewModel(
      usuario: widget.usuario,
      admins: widget.adminRepository,
      participantes: widget.participanteRepository,
    );
    _evento = EventoViewModel(widget.eventoRepository, sesion: _sesion);
    _participantes = ParticipantesViewModel(
      widget.participanteRepository,
      sesion: _sesion,
    );
    _aportaciones = AportacionesViewModel(
      widget.aportacionRepository,
      sesion: _sesion,
    );
    _esAdmin = _sesion.esAdmin;
    _esParticipante = _soyParticipante;
    _modulos = _crearModulos();
    _sesion.addListener(_alCambiarRol);
    _participantes.addListener(_alCambiarRol);
  }

  bool get _soyParticipante =>
      _participantes.participantes.any((p) => p.id == _sesion.uid);

  Map<String, String> get _nombres => {
    for (final p in _participantes.participantes) p.id: p.nombre,
  };

  _Modulos _crearModulos() {
    final nombres = _nombres;
    return _Modulos(
      VotacionViewModel(
        widget.votacionRepository,
        uid: _sesion.uid,
        esAdmin: _esAdmin,
        esParticipante: _esParticipante,
      ),
      ItinerarioViewModel(
        widget.itinerarioRepository,
        esAdmin: _esAdmin,
        nombresIniciales: nombres,
      ),
      ArbolViewModel(
        widget.arbolRepository,
        uid: _sesion.uid,
        esAdmin: _esAdmin,
        esParticipante: _esParticipante,
        nombres: nombres,
      ),
      IntercambioViewModel(
        widget.intercambioRepository,
        uid: _sesion.uid,
        esAdmin: _esAdmin,
        esParticipante: _esParticipante,
        nombres: nombres,
      ),
    );
  }

  void _alCambiarRol() {
    if (!mounted) return;
    final esAdmin = _sesion.esAdmin;
    final esParticipante = _soyParticipante;
    if (esAdmin != _esAdmin || esParticipante != _esParticipante) {
      final viejos = _modulos;
      setState(() {
        _esAdmin = esAdmin;
        _esParticipante = esParticipante;
        _modulos = _crearModulos();
      });
      // Se liberan después del cuadro: las vistas viejas aún se desmontan.
      WidgetsBinding.instance.addPostFrameCallback((_) => viejos.dispose());
    } else {
      final nombres = _nombres;
      _modulos.itinerario.actualizarParticipantes(nombres);
      _modulos.arbol.actualizarNombres(nombres);
      _modulos.intercambio.actualizarNombres(nombres);
    }
  }

  @override
  void dispose() {
    _sesion.removeListener(_alCambiarRol);
    _participantes.removeListener(_alCambiarRol);
    _modulos.dispose();
    _evento.dispose();
    _sesion.dispose();
    _participantes.dispose();
    _aportaciones.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PosadaScope(
      sesion: _sesion,
      evento: _evento,
      participantes: _participantes,
      aportaciones: _aportaciones,
      crearRepositorioCohetazo: widget.crearRepositorioCohetazo,
      child: ModulosScope(
        votacion: _modulos.votacion,
        itinerario: _modulos.itinerario,
        arbol: _modulos.arbol,
        intercambio: _modulos.intercambio,
        child: ShellPosada(onCerrarSesion: widget.onCerrarSesion),
      ),
    );
  }
}
