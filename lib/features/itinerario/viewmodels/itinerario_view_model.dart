import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/actividad.dart';
import '../repositories/itinerario_repository.dart';

/// Situación de una actividad respecto a la hora actual.
enum EstadoActividad { pasada, enCurso, siguiente, pendiente }

/// Estado de la pantalla del itinerario (patrón Observer).
///
/// Participantes: el mapa `id -> nombre` se alimenta con [participantes]
/// (un stream, p. ej. el de participantes mapeado a `{p.id: p.nombre}`), con
/// [nombresIniciales], o llamando a [actualizarParticipantes]. Sirve para
/// mostrar el responsable y validar que exista.
class ItinerarioViewModel extends ChangeNotifier {
  ItinerarioViewModel(
    this._repository, {
    required this.esAdmin,
    DateTime Function()? ahora,
    Stream<Map<String, String>>? participantes,
    Map<String, String> nombresIniciales = const {},
    Duration refresco = const Duration(seconds: 30),
  }) : _ahora = ahora ?? DateTime.now,
       _nombres = Map.of(nombresIniciales) {
    _suscripcion = _repository.actividades.listen(
      (lista) {
        _actividades = _ordenar(lista);
        _cargando = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object _) {
        _cargando = false;
        _error = 'No pudimos cargar el itinerario. Intenta de nuevo.';
        notifyListeners();
      },
    );
    _suscripcionNombres = participantes?.listen(actualizarParticipantes);
    _timer = Timer.periodic(refresco, (_) => notifyListeners());
  }

  final ItinerarioRepository _repository;
  final bool esAdmin;
  final DateTime Function() _ahora;
  late final StreamSubscription<List<Actividad>> _suscripcion;
  StreamSubscription<Map<String, String>>? _suscripcionNombres;
  Timer? _timer;

  List<Actividad> _actividades = const [];
  Map<String, String> _nombres;
  bool _cargando = true;
  String? _error;
  String? _advertencia;

  /// Actividades ordenadas por inicio.
  List<Actividad> get actividades => _actividades;
  bool get cargando => _cargando;
  String? get error => _error;
  bool get vacio => !_cargando && _error == null && _actividades.isEmpty;

  /// Aviso (no bloqueante) tras guardar una actividad que se traslapa.
  String? get advertencia => _advertencia;

  Map<String, String> get participantes => Map.unmodifiable(_nombres);

  void actualizarParticipantes(Map<String, String> nombres) {
    _nombres = Map.of(nombres);
    notifyListeners();
  }

  /// Nombre del responsable, o `null` si no hay o ya no existe.
  String? nombreResponsable(Actividad a) =>
      a.responsableId == null ? null : _nombres[a.responsableId];

  /// La siguiente actividad que aún no empieza (la más próxima), si hay.
  Actividad? get siguiente {
    final ahora = _ahora();
    for (final a in _actividades) {
      if (a.inicio.isAfter(ahora)) return a;
    }
    return null;
  }

  EstadoActividad estadoDe(Actividad a) {
    final ahora = _ahora();
    if (!ahora.isBefore(a.fin)) return EstadoActividad.pasada;
    if (!ahora.isBefore(a.inicio)) return EstadoActividad.enCurso;
    return siguiente?.id == a.id
        ? EstadoActividad.siguiente
        : EstadoActividad.pendiente;
  }

  Duration get duracionTotal =>
      Duration(minutes: _actividades.fold(0, (s, a) => s + a.duracionMin));

  /// Parejas de actividades que se traslapan.
  List<(Actividad, Actividad)> get solapamientos =>
      _solapamientosDe(_actividades);

  /// Ids de las actividades que se traslapan con otra.
  Set<String> get idsConSolape => {
    for (final (a, b) in solapamientos) ...[a.id, b.id],
  };

  static List<Actividad> _ordenar(List<Actividad> lista) =>
      List.of(lista)..sort((a, b) {
        final c = a.inicio.compareTo(b.inicio);
        return c != 0 ? c : a.titulo.compareTo(b.titulo);
      });

  static List<(Actividad, Actividad)> _solapamientosDe(List<Actividad> l) => [
    for (var i = 0; i < l.length; i++)
      for (var j = i + 1; j < l.length; j++)
        if (l[i].inicio.isBefore(l[j].fin) && l[j].inicio.isBefore(l[i].fin))
          (l[i], l[j]),
  ];

  /// Mensaje de error si los datos no son válidos; `null` si lo son.
  String? validar({
    required String titulo,
    required String descripcion,
    required int duracionMin,
    String? responsableId,
  }) {
    final t = titulo.trim();
    if (t.length < LimitesItinerario.tituloMin) {
      return 'El título no puede estar vacío.';
    }
    if (t.length > LimitesItinerario.tituloMax) {
      return 'El título no puede pasar de ${LimitesItinerario.tituloMax} caracteres.';
    }
    if (descripcion.trim().length > LimitesItinerario.descripcionMax) {
      return 'La descripción no puede pasar de ${LimitesItinerario.descripcionMax} caracteres.';
    }
    if (duracionMin < LimitesItinerario.duracionMinima ||
        duracionMin > LimitesItinerario.duracionMaxima) {
      return 'La duración debe estar entre ${LimitesItinerario.duracionMinima} y ${LimitesItinerario.duracionMaxima} minutos.';
    }
    if (responsableId != null && !_nombres.containsKey(responsableId)) {
      return 'El responsable elegido no es un participante.';
    }
    return null;
  }

  static const _soloAdmin = 'Solo el organizador puede cambiar el itinerario.';

  /// Devuelve `false` y deja [error] si no es admin o los datos no son válidos.
  Future<bool> agregar({
    required String titulo,
    String descripcion = '',
    required DateTime inicio,
    required int duracionMin,
    String? responsableId,
  }) => _guardar(
    Actividad(
      id: '',
      titulo: titulo.trim(),
      descripcion: descripcion.trim(),
      inicio: inicio,
      duracionMin: duracionMin,
      responsableId: responsableId,
    ),
    nueva: true,
  );

  Future<bool> editar(
    Actividad original, {
    required String titulo,
    String descripcion = '',
    required DateTime inicio,
    required int duracionMin,
    String? responsableId,
  }) => _guardar(
    Actividad(
      id: original.id,
      titulo: titulo.trim(),
      descripcion: descripcion.trim(),
      inicio: inicio,
      duracionMin: duracionMin,
      responsableId: responsableId,
    ),
    nueva: false,
  );

  Future<bool> _guardar(Actividad a, {required bool nueva}) async {
    _advertencia = null;
    if (!esAdmin) return _fallar(_soloAdmin);
    final msg = validar(
      titulo: a.titulo,
      descripcion: a.descripcion,
      duracionMin: a.duracionMin,
      responsableId: a.responsableId,
    );
    if (msg != null) return _fallar(msg);
    final otras = _actividades.where((x) => x.id != a.id);
    final traslapa = otras.any(
      (x) => a.inicio.isBefore(x.fin) && x.inicio.isBefore(a.fin),
    );
    try {
      if (nueva) {
        await _repository.agregar(a);
      } else {
        await _repository.editar(a);
      }
    } catch (_) {
      return _fallar('No pudimos guardar la actividad. Intenta de nuevo.');
    }
    _error = null;
    if (traslapa) {
      _advertencia = 'La actividad se traslapa con otra del itinerario.';
    }
    notifyListeners();
    return true;
  }

  Future<bool> eliminar(String id) async {
    _advertencia = null;
    if (!esAdmin) return _fallar(_soloAdmin);
    try {
      await _repository.eliminar(id);
    } catch (_) {
      return _fallar('No pudimos eliminar la actividad. Intenta de nuevo.');
    }
    _error = null;
    notifyListeners();
    return true;
  }

  bool _fallar(String mensaje) {
    _error = mensaje;
    notifyListeners();
    return false;
  }

  void limpiarMensajes() {
    _error = null;
    _advertencia = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _suscripcion.cancel();
    _suscripcionNombres?.cancel();
    super.dispose();
  }
}
