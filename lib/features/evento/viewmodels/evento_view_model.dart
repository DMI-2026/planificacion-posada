import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/validacion/limites.dart';
import '../../auth/viewmodels/sesion_view_model.dart';
import '../models/evento.dart';
import '../repositories/evento_repository.dart';

/// Estado de la pantalla del evento (patrón Observer).
class EventoViewModel extends ChangeNotifier {
  EventoViewModel(this._repository, {required this.sesion}) {
    _suscripcion = _repository.evento.listen(
      (evento) {
        _evento = evento;
        _cargando = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object _) {
        _cargando = false;
        _error = 'No pudimos cargar el evento. Intenta de nuevo.';
        notifyListeners();
      },
    );
  }

  final EventoRepository _repository;
  final SesionViewModel sesion;
  late final StreamSubscription<Evento?> _suscripcion;

  Evento? _evento;
  bool _cargando = true;
  String? _error;

  Evento? get evento => _evento;
  bool get cargando => _cargando;
  String? get error => _error;

  /// Solo el admin crea o edita el evento.
  bool get puedeEditar => sesion.esAdmin;

  /// Guarda el evento. Devuelve `false` y deja [error] si no es válido.
  Future<bool> guardar({
    required String nombre,
    required DateTime fecha,
    String lugar = '',
    String notas = '',
  }) async {
    if (!puedeEditar) {
      _error = 'Solo el organizador puede editar el evento.';
      notifyListeners();
      return false;
    }
    final nombreLimpio = nombre.trim();
    if (nombreLimpio.isEmpty) {
      _error = 'El nombre del evento no puede estar vacío.';
      notifyListeners();
      return false;
    }
    final limites = [
      (
        nombreLimpio.length,
        Limites.nombreEvento,
        'El nombre no puede pasar de ${Limites.nombreEvento} caracteres.',
      ),
      (
        lugar.trim().length,
        Limites.lugarEvento,
        'El lugar no puede pasar de ${Limites.lugarEvento} caracteres.',
      ),
      (
        notas.trim().length,
        Limites.notasEvento,
        'Las notas no pueden pasar de ${Limites.notasEvento} caracteres.',
      ),
    ];
    for (final (largo, maximo, mensaje) in limites) {
      if (largo > maximo) {
        _error = mensaje;
        notifyListeners();
        return false;
      }
    }
    try {
      await _repository.guardar(
        Evento(
          nombre: nombreLimpio,
          fecha: fecha,
          lugar: lugar.trim(),
          notas: notas.trim(),
        ),
      );
    } catch (_) {
      _error = 'No pudimos guardar el evento. Intenta de nuevo.';
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
    super.dispose();
  }
}
