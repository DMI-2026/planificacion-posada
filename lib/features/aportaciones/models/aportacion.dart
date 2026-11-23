/// Un artículo que alguien llevará a la posada.
class Aportacion {
  final String id;
  final String articulo;
  final int cantidad;

  /// Id del participante a cargo; `null` si aún no se asigna.
  final String? responsableId;
  final bool lista;

  const Aportacion({
    required this.id,
    required this.articulo,
    required this.cantidad,
    this.responsableId,
    this.lista = false,
  }) : assert(cantidad >= 1, 'La cantidad debe ser al menos 1');

  /// El [id] es el del documento, no un campo del mapa.
  factory Aportacion.fromMap(String id, Map<String, dynamic> map) {
    return Aportacion(
      id: id,
      articulo: map['articulo'] as String,
      cantidad: (map['cantidad'] as num).toInt(),
      responsableId: map['responsable_id'] as String?,
      lista: map['lista'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'articulo': articulo,
      'cantidad': cantidad,
      'responsable_id': responsableId,
      'lista': lista,
    };
  }

  /// Para quitar el responsable usa [sinResponsable].
  Aportacion copyWith({
    String? responsableId,
    bool sinResponsable = false,
    bool? lista,
  }) {
    return Aportacion(
      id: id,
      articulo: articulo,
      cantidad: cantidad,
      responsableId: sinResponsable
          ? null
          : (responsableId ?? this.responsableId),
      lista: lista ?? this.lista,
    );
  }
}
