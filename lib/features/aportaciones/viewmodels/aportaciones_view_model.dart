import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/validacion/limites.dart';
import '../../auth/viewmodels/sesion_view_model.dart';
import '../../participantes/models/participante.dart';
import '../models/aportacion.dart';
import '../repositories/aportacion_repository.dart';
import '../utils/dinero.dart';

/// Estado de la pantalla de aportaciones (patrón Observer).
class AportacionesViewModel extends ChangeNotifier {
  AportacionesViewModel(this._repository, {required this.sesion}) {
    _suscripcion = _repository.aportaciones.listen(
      (lista) {
        _aportaciones = lista;
        _cargando = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object _) {
        _cargando = false;
        _error = 'No pudimos cargar las aportaciones. Intenta de nuevo.';
        notifyListeners();
      },
    );
    _suscripcionMeta = _repository.meta.listen(
      (meta) {
        _meta = meta;
        notifyListeners();
      },
      onError: (Object _) {
        _error = 'No pudimos cargar la meta. Intenta de nuevo.';
        notifyListeners();
      },
    );
  }

  final AportacionRepository _repository;
  final SesionViewModel sesion;
  late final StreamSubscription<List<Aportacion>> _suscripcion;
  late final StreamSubscription<int?> _suscripcionMeta;

  List<Aportacion> _aportaciones = const [];
  bool _cargando = true;
  String? _error;

  int? _meta;

  /// Todas las aportaciones (materiales y económicas).
  List<Aportacion> get aportaciones => _aportaciones;
  List<Aportacion> get materiales => [
    for (final a in _aportaciones)
      if (a.esMaterial) a,
  ];
  List<Aportacion> get economicas => [
    for (final a in _aportaciones)
      if (a.esEconomica) a,
  ];
  bool get cargando => _cargando;
  String? get error => _error;
  bool get vacio => !_cargando && _error == null && _aportaciones.isEmpty;
  bool get vacioMateriales =>
      !_cargando && _error == null && materiales.isEmpty;
  bool get vacioEconomicas =>
      !_cargando && _error == null && economicas.isEmpty;

  /// Conteos de las aportaciones materiales.
  int get listas => materiales.where((a) => a.lista).length;
  int get pendientes => materiales.length - listas;

  /// Meta de recaudación en centavos; `null` si no hay.
  int? get meta => _meta;

  /// Dinero que el organizador ya recibió.
  int get totalRecibido => _suma(recibidas: true);

  /// Dinero registrado (recibido o no).
  int get totalComprometido => _suma(recibidas: false);

  int _suma({required bool recibidas}) => economicas
      .where((a) => !recibidas || a.recibido)
      .fold(0, (t, a) => t + a.montoCentavos);

  /// Avance de lo recibido hacia la meta, de 0 a 1 (0 sin meta).
  double get progreso {
    final m = _meta;
    if (m == null || m <= 0) return 0;
    return (totalRecibido / m).clamp(0.0, 1.0);
  }

  bool get metaAlcanzada {
    final m = _meta;
    return m != null && m > 0 && totalRecibido >= m;
  }

  /// Devuelve `false` y deja [error] si el artículo o la cantidad no son válidos.
  Future<bool> agregar(String articulo, int cantidad) async {
    final limpio = articulo.trim();
    if (limpio.isEmpty) {
      _error = 'El artículo no puede estar vacío.';
      notifyListeners();
      return false;
    }
    if (limpio.length > Limites.articulo) {
      _error = 'El artículo no puede pasar de ${Limites.articulo} caracteres.';
      notifyListeners();
      return false;
    }
    if (cantidad > Limites.cantidadMaxima) {
      _error = 'La cantidad no puede pasar de ${Limites.cantidadMaxima}.';
      notifyListeners();
      return false;
    }
    if (cantidad < 1) {
      _error = 'La cantidad debe ser al menos 1.';
      notifyListeners();
      return false;
    }
    return _ejecutar(() => _repository.agregar(limpio, cantidad), 'agregar');
  }

  /// Valida un monto en centavos; devuelve el mensaje de error o `null`.
  String? _errorMonto(int centavos) {
    if (centavos < LimitesAportaciones.montoMinimoCentavos) {
      return 'El monto debe ser de al menos '
          '${formatoDinero(LimitesAportaciones.montoMinimoCentavos)}.';
    }
    if (centavos > LimitesAportaciones.montoMaximoCentavos) {
      return 'El monto no puede pasar de '
          '${formatoDinero(LimitesAportaciones.montoMaximoCentavos)}.';
    }
    return null;
  }

  /// Registra una aportación económica (sin recibir). Sin [responsableId] es
  /// la de quien tiene la sesión; solo el admin registra para otra persona.
  Future<bool> agregarEconomica(int montoCentavos, {String? responsableId}) {
    final quien = responsableId ?? sesion.uid;
    if (!sesion.esAdmin && quien != sesion.uid) {
      return _rechazar('Solo puedes registrar tus propias aportaciones.');
    }
    final problema = _errorMonto(montoCentavos);
    if (problema != null) return _rechazar(problema);
    return _ejecutar(
      () => _repository.agregarEconomica(quien, montoCentavos),
      'agregar',
    );
  }

  /// El admin edita cualquiera; el responsable, la suya mientras no se recibe.
  bool puedeEditarEconomica(Aportacion a) =>
      a.esEconomica && (sesion.esAdmin || (_esMia(a) && !a.recibido));

  /// Solo el admin marca como recibido.
  bool get puedeMarcarRecibido => sesion.esAdmin;

  /// Eliminar: el admin cualquiera; el responsable su económica no recibida.
  bool puedeEliminarAportacion(Aportacion a) =>
      sesion.esAdmin || (a.esEconomica && _esMia(a) && !a.recibido);

  Future<bool> editarMonto(String id, int montoCentavos) {
    final a = _buscar(id);
    if (a == null || !a.esEconomica) {
      return _rechazar('No encontramos esa aportación.');
    }
    if (!puedeEditarEconomica(a)) {
      return _rechazar(
        a.recibido
            ? 'Esta aportación ya fue recibida; solo el organizador puede '
                  'cambiarla.'
            : 'Solo puedes cambiar tus propias aportaciones.',
      );
    }
    final problema = _errorMonto(montoCentavos);
    if (problema != null) return _rechazar(problema);
    return _ejecutar(
      () => _repository.editarMonto(id, montoCentavos),
      'actualizar',
    );
  }

  Future<bool> marcarRecibido(String id, bool recibido) {
    if (!puedeMarcarRecibido) {
      return _rechazar(
        'Solo el organizador puede marcar aportaciones como recibidas.',
      );
    }
    return _ejecutar(
      () => _repository.marcarRecibido(id, recibido),
      'actualizar',
    );
  }

  /// Guarda la meta en centavos; `null` la quita. Solo el admin.
  Future<bool> guardarMeta(int? centavos) {
    if (!sesion.esAdmin) {
      return _rechazar('Solo el organizador puede cambiar la meta.');
    }
    if (centavos != null && centavos < 0) {
      return _rechazar('La meta no puede ser negativa.');
    }
    return _ejecutar(
      () => _repository.guardarMeta(centavos),
      'guardar la meta de',
    );
  }

  Aportacion? _buscar(String id) {
    for (final a in _aportaciones) {
      if (a.id == id) return a;
    }
    return null;
  }

  bool _esMia(Aportacion a) => a.responsableId == sesion.uid;

  /// El admin cambia el responsable de cualquiera; los demás solo de una
  /// aportación libre o suya (no se le quita a otra persona).
  bool puedeAsignar(Aportacion a) =>
      sesion.esAdmin || a.responsableId == null || _esMia(a);

  /// El admin marca cualquiera; los demás solo las que llevan ellos.
  bool puedeMarcarLista(Aportacion a) => sesion.esAdmin || _esMia(a);

  /// Solo el admin elimina.
  bool get puedeEliminar => sesion.esAdmin;

  /// Participantes que se ofrecen como responsable de [a]: el admin ve a
  /// todos; los demás solo a sí mismos (y al responsable actual, que se
  /// muestra pero no se puede cambiar).
  List<Participante> opcionesResponsable(
    Aportacion a,
    List<Participante> participantes,
  ) {
    if (sesion.esAdmin) return participantes;
    return [
      for (final p in participantes)
        if (p.id == sesion.uid || p.id == a.responsableId) p,
    ];
  }

  Future<bool> asignar(String id, String? responsableId) {
    final a = _buscar(id);
    if (a != null && a.esEconomica) {
      return _rechazar('Una aportación económica no se asigna.');
    }
    final permitido =
        sesion.esAdmin ||
        (a != null &&
            puedeAsignar(a) &&
            (responsableId == null || responsableId == sesion.uid));
    if (!permitido) {
      return _rechazar('Solo puedes asignarte aportaciones a ti mismo.');
    }
    return _ejecutar(() => _repository.asignar(id, responsableId), 'asignar');
  }

  Future<bool> marcarLista(String id, bool lista) {
    final a = _buscar(id);
    if (a != null && a.esEconomica) {
      return _rechazar('Una aportación económica no se marca como lista.');
    }
    if (!sesion.esAdmin && (a == null || !puedeMarcarLista(a))) {
      return _rechazar('Solo puedes marcar como lista lo que tú llevas.');
    }
    return _ejecutar(() => _repository.marcarLista(id, lista), 'actualizar');
  }

  Future<bool> eliminar(String id) {
    final a = _buscar(id);
    final permitido =
        sesion.esAdmin || (a != null && puedeEliminarAportacion(a));
    if (!permitido) {
      return _rechazar(
        a != null && a.esEconomica && a.recibido
            ? 'Esta aportación ya fue recibida; solo el organizador puede '
                  'eliminarla.'
            : 'Solo el organizador puede eliminar aportaciones.',
      );
    }
    return _ejecutar(() => _repository.eliminar(id), 'eliminar');
  }

  Future<bool> _rechazar(String mensaje) async {
    _error = mensaje;
    notifyListeners();
    return false;
  }

  /// Nombre del responsable, o `Sin asignar` si no hay o ya no existe.
  String nombreResponsable(
    Aportacion aportacion,
    List<Participante> participantes,
  ) {
    for (final p in participantes) {
      if (p.id == aportacion.responsableId) return p.nombre;
    }
    return 'Sin asignar';
  }

  Future<bool> _ejecutar(
    Future<void> Function() accion,
    String queHacer,
  ) async {
    try {
      await accion();
    } catch (_) {
      _error = 'No pudimos $queHacer la aportación. Intenta de nuevo.';
      notifyListeners();
      return false;
    }
    _error = null;
    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    _suscripcion.cancel();
    _suscripcionMeta.cancel();
    super.dispose();
  }
}
