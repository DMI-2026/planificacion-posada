/// El evento de la posada de la clase.
///
/// `fecha` viaja como [DateTime]; el repositorio de Firestore la convierte
/// desde/hacia `Timestamp`, así el modelo no depende de `cloud_firestore`.
class Evento {
  final String nombre;
  final DateTime fecha;
  final String lugar;
  final String notas;

  const Evento({
    required this.nombre,
    required this.fecha,
    this.lugar = '',
    this.notas = '',
  });

  factory Evento.fromMap(Map<String, dynamic> map) {
    return Evento(
      nombre: map['nombre'] as String,
      fecha: map['fecha'] as DateTime,
      lugar: map['lugar'] as String? ?? '',
      notas: map['notas'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'nombre': nombre, 'fecha': fecha, 'lugar': lugar, 'notas': notas};
  }
}
