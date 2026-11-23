import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/config/emulador.dart';
import 'core/navegacion/sesion_activa.dart';
import 'core/theme/app_theme.dart';
import 'features/aportaciones/repositories/aportacion_repository.dart';
import 'features/aportaciones/repositories/firestore_aportacion_repository.dart';
import 'features/arbol/repositories/arbol_repository.dart';
import 'features/arbol/repositories/firestore_arbol_repository.dart';
import 'features/auth/repositories/admin_repository.dart';
import 'features/auth/repositories/auth_repository.dart';
import 'features/auth/repositories/firestore_admin_repository.dart';
import 'features/auth/repositories/firebase_auth_repository.dart';
import 'features/auth/viewmodels/auth_view_model.dart';
import 'features/auth/views/puerta_sesion_view.dart';
import 'features/evento/repositories/evento_repository.dart';
import 'features/evento/repositories/firestore_evento_repository.dart';
import 'features/intercambio/repositories/firestore_intercambio_repository.dart';
import 'features/intercambio/repositories/intercambio_repository.dart';
import 'features/itinerario/repositories/firestore_itinerario_repository.dart';
import 'features/itinerario/repositories/itinerario_repository.dart';
import 'features/participantes/repositories/firestore_participante_repository.dart';
import 'features/participantes/repositories/participante_repository.dart';
import 'features/votacion/repositories/firestore_votacion_repository.dart';
import 'features/votacion/repositories/votacion_repository.dart';
import 'firebase_options.dart';

/// `--dart-define=USAR_EMULADOR=true` conecta Auth (9099) y Firestore (8080)
/// a los emuladores locales en vez de a la nube.
///
/// `--dart-define=EMULADOR_HOST=<IP>` fuerza el host (p. ej. teléfono físico).
const _usarEmulador = bool.fromEnvironment('USAR_EMULADOR');
const _emuladorHost = String.fromEnvironment('EMULADOR_HOST');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (_usarEmulador) {
    final host = hostEmulador(
      esWeb: kIsWeb,
      esAndroid: defaultTargetPlatform == TargetPlatform.android,
      definido: _emuladorHost,
    );
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  }
  runApp(
    PosadaApp(
      authRepository: FirebaseAuthRepository(),
      adminRepository: FirestoreAdminRepository(),
      eventoRepository: FirestoreEventoRepository(),
      participanteRepository: FirestoreParticipanteRepository(),
      aportacionRepository: FirestoreAportacionRepository(),
      votacionRepository: FirestoreVotacionRepository(),
      itinerarioRepository: FirestoreItinerarioRepository(),
      arbolRepository: FirestoreArbolRepository(),
      intercambioRepository: FirestoreIntercambioRepository(),
    ),
  );
}

/// Raíz de la app. Recibe los repositorios por constructor (inyección).
class PosadaApp extends StatefulWidget {
  const PosadaApp({
    super.key,
    required this.authRepository,
    required this.adminRepository,
    required this.eventoRepository,
    required this.participanteRepository,
    required this.aportacionRepository,
    required this.votacionRepository,
    required this.itinerarioRepository,
    required this.arbolRepository,
    required this.intercambioRepository,
  });

  final AuthRepository authRepository;
  final AdminRepository adminRepository;
  final EventoRepository eventoRepository;
  final ParticipanteRepository participanteRepository;
  final AportacionRepository aportacionRepository;
  final VotacionRepository votacionRepository;
  final ItinerarioRepository itinerarioRepository;
  final ArbolRepository arbolRepository;
  final IntercambioRepository intercambioRepository;

  @override
  State<PosadaApp> createState() => _PosadaAppState();
}

class _PosadaAppState extends State<PosadaApp> {
  late final AuthViewModel _auth;

  @override
  void initState() {
    super.initState();
    _auth = AuthViewModel(widget.authRepository);
  }

  @override
  void dispose() {
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Posada de la clase',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.claro,
      home: PuertaSesionView(
        viewModel: _auth,
        // Los viewmodels de datos nacen aquí: solo con sesión iniciada.
        sesionBuilder: (context, usuario) => SesionActiva(
          key: ValueKey(usuario.id),
          usuario: usuario,
          adminRepository: widget.adminRepository,
          eventoRepository: widget.eventoRepository,
          participanteRepository: widget.participanteRepository,
          aportacionRepository: widget.aportacionRepository,
          votacionRepository: widget.votacionRepository,
          itinerarioRepository: widget.itinerarioRepository,
          arbolRepository: widget.arbolRepository,
          intercambioRepository: widget.intercambioRepository,
          onCerrarSesion: _auth.cerrarSesion,
        ),
      ),
    );
  }
}
