/// Respuesta de un participante a la invitación.
enum Asistencia {
  si('si'),
  no('no'),
  talVez('tal_vez');

  const Asistencia(this.json);

  /// Valor guardado en Firestore.
  final String json;

  /// Un valor desconocido o ausente cuenta como [talVez].
  static Asistencia fromJson(String? valor) {
    return Asistencia.values.firstWhere(
      (a) => a.json == valor,
      orElse: () => Asistencia.talVez,
    );
  }
}

/// Una persona invitada a la posada.
class Participante {
  final String id;
  final String nombre;
  final Asistencia asistencia;

  const Participante({
    required this.id,
    required this.nombre,
    this.asistencia = Asistencia.talVez,
  });

  /// El [id] es el del documento, no un campo del mapa.
  factory Participante.fromMap(String id, Map<String, dynamic> map) {
    return Participante(
      id: id,
      nombre: map['nombre'] as String,
      asistencia: Asistencia.fromJson(map['asistencia'] as String?),
    );
  }

  Map<String, dynamic> toMap() {
    return {'nombre': nombre, 'asistencia': asistencia.json};
  }

  Participante copyWith({String? nombre, Asistencia? asistencia}) {
    return Participante(
      id: id,
      nombre: nombre ?? this.nombre,
      asistencia: asistencia ?? this.asistencia,
    );
  }
}
