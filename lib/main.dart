import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'core/navegacion/sesion_activa.dart';
import 'core/theme/app_theme.dart';
import 'features/aportaciones/repositories/aportacion_repository.dart';
import 'features/aportaciones/repositories/firestore_aportacion_repository.dart';
import 'features/auth/repositories/auth_repository.dart';
import 'features/auth/repositories/firebase_auth_repository.dart';
import 'features/auth/viewmodels/auth_view_model.dart';
import 'features/auth/views/puerta_sesion_view.dart';
import 'features/evento/repositories/evento_repository.dart';
import 'features/evento/repositories/firestore_evento_repository.dart';
import 'features/participantes/repositories/firestore_participante_repository.dart';
import 'features/participantes/repositories/participante_repository.dart';
import 'firebase_options.dart';

/// `--dart-define=USAR_EMULADOR=true` conecta Auth (9099) y Firestore (8080)
/// a los emuladores locales en vez de a la nube.
const _usarEmulador = bool.fromEnvironment('USAR_EMULADOR');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (_usarEmulador) {
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  }
  runApp(
    PosadaApp(
      authRepository: FirebaseAuthRepository(),
      eventoRepository: FirestoreEventoRepository(),
      participanteRepository: FirestoreParticipanteRepository(),
      aportacionRepository: FirestoreAportacionRepository(),
    ),
  );
}

/// Raíz de la app. Recibe los repositorios por constructor (inyección).
class PosadaApp extends StatefulWidget {
  const PosadaApp({
    super.key,
    required this.authRepository,
    required this.eventoRepository,
    required this.participanteRepository,
    required this.aportacionRepository,
  });

  final AuthRepository authRepository;
  final EventoRepository eventoRepository;
  final ParticipanteRepository participanteRepository;
  final AportacionRepository aportacionRepository;

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
          eventoRepository: widget.eventoRepository,
          participanteRepository: widget.participanteRepository,
          aportacionRepository: widget.aportacionRepository,
          onCerrarSesion: _auth.cerrarSesion,
        ),
      ),
    );
  }
}
