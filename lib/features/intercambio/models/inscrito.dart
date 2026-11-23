/// Inscripción de una persona (`intercambio_inscritos/{uid}`) con sus deseos.
class Inscrito {
  const Inscrito({required this.uid, this.deseos = const []});

  final String uid;
  final List<String> deseos;

  Map<String, dynamic> toMap() => {'deseos': List<String>.of(deseos)};

  factory Inscrito.fromMap(String uid, Map<String, dynamic> map) => Inscrito(
    uid: uid,
    deseos: [
      for (final d in (map['deseos'] as List?) ?? const [])
        if (d is String) d,
    ],
  );
}
