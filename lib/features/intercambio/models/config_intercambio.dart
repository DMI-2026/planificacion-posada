import 'package:cloud_firestore/cloud_firestore.dart';

/// Configuración del intercambio (`config/intercambio`).
class ConfigIntercambio {
  const ConfigIntercambio({
    this.inscripcionAbierta = false,
    this.sorteado = false,
    this.revelado = false,
    this.presupuestoCentavos = 0,
    this.fecha,
  });

  final bool inscripcionAbierta;
  final bool sorteado;
  final bool revelado;
  final int presupuestoCentavos;
  final DateTime? fecha;

  ConfigIntercambio copyWith({
    bool? inscripcionAbierta,
    bool? sorteado,
    bool? revelado,
    int? presupuestoCentavos,
    DateTime? fecha,
    bool quitarFecha = false,
  }) => ConfigIntercambio(
    inscripcionAbierta: inscripcionAbierta ?? this.inscripcionAbierta,
    sorteado: sorteado ?? this.sorteado,
    revelado: revelado ?? this.revelado,
    presupuestoCentavos: presupuestoCentavos ?? this.presupuestoCentavos,
    fecha: quitarFecha ? null : (fecha ?? this.fecha),
  );

  /// Siempre escribe las cinco claves (las reglas exigen el documento completo).
  Map<String, dynamic> toMap() => {
    'inscripcion_abierta': inscripcionAbierta,
    'sorteado': sorteado,
    'revelado': revelado,
    'presupuesto_centavos': presupuestoCentavos,
    'fecha': fecha == null ? null : Timestamp.fromDate(fecha!),
  };

  factory ConfigIntercambio.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ConfigIntercambio();
    final f = map['fecha'];
    return ConfigIntercambio(
      inscripcionAbierta: map['inscripcion_abierta'] == true,
      sorteado: map['sorteado'] == true,
      revelado: map['revelado'] == true,
      presupuestoCentavos: (map['presupuesto_centavos'] as num?)?.toInt() ?? 0,
      fecha: f is Timestamp ? f.toDate() : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ConfigIntercambio &&
      other.inscripcionAbierta == inscripcionAbierta &&
      other.sorteado == sorteado &&
      other.revelado == revelado &&
      other.presupuestoCentavos == presupuestoCentavos &&
      other.fecha == fecha;

  @override
  int get hashCode => Object.hash(
    inscripcionAbierta,
    sorteado,
    revelado,
    presupuestoCentavos,
    fecha,
  );
}
