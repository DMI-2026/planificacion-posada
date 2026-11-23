/// Tipo de aportación: algo que se lleva o dinero.
enum TipoAportacion {
  material('material'),
  economica('economica');

  const TipoAportacion(this.json);

  /// Valor guardado en Firestore.
  final String json;

  /// Un valor ausente o desconocido cuenta como [material] (documentos
  /// anteriores a los tipos).
  static TipoAportacion fromJson(String? valor) =>
      TipoAportacion.values.firstWhere(
        (t) => t.json == valor,
        orElse: () => TipoAportacion.material,
      );
}

/// Una aportación a la posada: un artículo que alguien llevará (material) o
/// una cantidad de dinero (económica).
class Aportacion {
  final String id;
  final TipoAportacion tipo;

  /// Solo material.
  final String articulo;

  /// Solo material.
  final int cantidad;

  /// Id del participante a cargo; `null` si aún no se asigna (siempre hay
  /// uno en una económica).
  final String? responsableId;

  /// Solo material: ya la tiene quien la lleva.
  final bool lista;

  /// Solo económica: monto en centavos.
  final int montoCentavos;

  /// Solo económica: el organizador ya recibió el dinero.
  final bool recibido;

  const Aportacion({
    required this.id,
    required this.articulo,
    required this.cantidad,
    this.responsableId,
    this.lista = false,
  }) : tipo = TipoAportacion.material,
       montoCentavos = 0,
       recibido = false,
       assert(cantidad >= 1, 'La cantidad debe ser al menos 1');

  const Aportacion.economica({
    required this.id,
    required String this.responsableId,
    required this.montoCentavos,
    this.recibido = false,
  }) : tipo = TipoAportacion.economica,
       articulo = '',
       cantidad = 1,
       lista = false,
       assert(montoCentavos >= 1, 'El monto debe ser al menos 1 centavo');

  bool get esMaterial => tipo == TipoAportacion.material;
  bool get esEconomica => tipo == TipoAportacion.economica;

  /// El [id] es el del documento, no un campo del mapa.
  factory Aportacion.fromMap(String id, Map<String, dynamic> map) {
    if (TipoAportacion.fromJson(map['tipo'] as String?) ==
        TipoAportacion.economica) {
      return Aportacion.economica(
        id: id,
        responsableId: map['responsable_id'] as String,
        montoCentavos: (map['monto_centavos'] as num).toInt(),
        recibido: map['recibido'] as bool? ?? false,
      );
    }
    return Aportacion(
      id: id,
      articulo: map['articulo'] as String,
      cantidad: (map['cantidad'] as num).toInt(),
      responsableId: map['responsable_id'] as String?,
      lista: map['lista'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    if (esEconomica) {
      return {
        'tipo': tipo.json,
        'responsable_id': responsableId,
        'monto_centavos': montoCentavos,
        'recibido': recibido,
      };
    }
    return {
      'tipo': tipo.json,
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
    int? montoCentavos,
    bool? recibido,
  }) {
    if (esEconomica) {
      return Aportacion.economica(
        id: id,
        responsableId: responsableId ?? this.responsableId!,
        montoCentavos: montoCentavos ?? this.montoCentavos,
        recibido: recibido ?? this.recibido,
      );
    }
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
