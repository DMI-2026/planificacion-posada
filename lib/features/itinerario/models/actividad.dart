/// Límites de captura del itinerario.
///
/// IMPORTANTE: deben coincidir con `lib/features/itinerario/itinerario.rules`
/// y con `test/firestore_rules/itinerario_rules_test.js`.
abstract final class LimitesItinerario {
  static const int tituloMin = 1;
  static const int tituloMax = 80;
  static const int descripcionMax = 500;
  static const int duracionMinima = 5;
  static const int duracionMaxima = 600;
}

/// Una actividad del programa de la posada (`itinerario/{id}`).
class Actividad {
  const Actividad({
    required this.id,
    required this.titulo,
    this.descripcion = '',
    required this.inicio,
    required this.duracionMin,
    this.responsableId,
  });

  final String id;
  final String titulo;
  final String descripcion;
  final DateTime inicio;
  final int duracionMin;
  final String? responsableId;

  DateTime get fin => inicio.add(Duration(minutes: duracionMin));

  /// Claves exactas del documento (sin el id). `inicio` queda como DateTime;
  /// el repositorio de Firestore lo convierte a Timestamp.
  Map<String, Object?> toMap() => {
    'titulo': titulo,
    'descripcion': descripcion,
    'inicio': inicio,
    'duracion_min': duracionMin,
    'responsable_id': responsableId,
  };

  /// Lee un mapa con `inicio` como DateTime.
  factory Actividad.fromMap(String id, Map<String, Object?> mapa) => Actividad(
    id: id,
    titulo: (mapa['titulo'] as String?) ?? '',
    descripcion: (mapa['descripcion'] as String?) ?? '',
    inicio: mapa['inicio'] as DateTime,
    duracionMin: (mapa['duracion_min'] as num?)?.toInt() ?? 0,
    responsableId: mapa['responsable_id'] as String?,
  );

  Actividad copyWith({
    String? titulo,
    String? descripcion,
    DateTime? inicio,
    int? duracionMin,
    String? responsableId,
    bool sinResponsable = false,
  }) => Actividad(
    id: id,
    titulo: titulo ?? this.titulo,
    descripcion: descripcion ?? this.descripcion,
    inicio: inicio ?? this.inicio,
    duracionMin: duracionMin ?? this.duracionMin,
    responsableId: sinResponsable
        ? null
        : (responsableId ?? this.responsableId),
  );

  @override
  bool operator ==(Object other) =>
      other is Actividad &&
      other.id == id &&
      other.titulo == titulo &&
      other.descripcion == descripcion &&
      other.inicio == inicio &&
      other.duracionMin == duracionMin &&
      other.responsableId == responsableId;

  @override
  int get hashCode =>
      Object.hash(id, titulo, descripcion, inicio, duracionMin, responsableId);
}
