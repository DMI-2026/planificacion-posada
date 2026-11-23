/// Platillo propuesto para la comida de la posada (`comida_opciones/{id}`).
class ComidaOpcion {
  const ComidaOpcion({
    required this.id,
    required this.nombre,
    this.descripcion = '',
    required this.propuestaPor,
    this.creada,
  });

  final String id;
  final String nombre;
  final String descripcion;
  final String propuestaPor;
  final DateTime? creada;

  /// La fecha `creada` la pone el servidor al guardar (ver el repositorio de
  /// Firestore); aquí solo se refleja lo que haya en memoria.
  Map<String, dynamic> toMap() => {
    'nombre': nombre,
    'descripcion': descripcion,
    'propuesta_por': propuestaPor,
    'creada': creada,
  };

  factory ComidaOpcion.fromMap(String id, Map<String, dynamic> map) {
    final c = map['creada'];
    DateTime? creada;
    if (c is DateTime) {
      creada = c;
    } else if (c != null) {
      try {
        // Timestamp de Firestore (evita depender del plugin en el modelo).
        creada = (c as dynamic).toDate() as DateTime;
      } catch (_) {
        creada = null;
      }
    }
    return ComidaOpcion(
      id: id,
      nombre: map['nombre'] as String? ?? '',
      descripcion: map['descripcion'] as String? ?? '',
      propuestaPor: map['propuesta_por'] as String? ?? '',
      creada: creada,
    );
  }
}
