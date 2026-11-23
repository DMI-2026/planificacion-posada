/// Quién le regala a quién (`intercambio_asignaciones/{uid}`): el documento
/// es de quien da el regalo y `destinatarioId` es quien lo recibe.
class Asignacion {
  const Asignacion({required this.uid, required this.destinatarioId});

  final String uid;
  final String destinatarioId;

  Map<String, dynamic> toMap() => {'destinatario_id': destinatarioId};

  factory Asignacion.fromMap(String uid, Map<String, dynamic> map) =>
      Asignacion(
        uid: uid,
        destinatarioId: map['destinatario_id'] as String? ?? '',
      );
}
