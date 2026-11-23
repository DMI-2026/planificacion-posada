/// Voto de una persona (`comida_votos/{uid}`): el id del documento es el uid.
class Voto {
  const Voto({required this.uid, required this.opcionId});

  final String uid;
  final String opcionId;

  Map<String, dynamic> toMap() => {'opcion_id': opcionId};

  factory Voto.fromMap(String uid, Map<String, dynamic> map) =>
      Voto(uid: uid, opcionId: map['opcion_id'] as String? ?? '');
}
