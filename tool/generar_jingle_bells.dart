// Sintetiza el estribillo de «Jingle Bells» (dominio público) como WAV mono
// de 16 bits a 22050 Hz con timbre de caja de música.
//
// Uso: dart run tool/generar_jingle_bells.dart [ruta_de_salida]
// Salida por defecto: assets/audio/jingle_bells.wav
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const int tasa = 22050;
const double negra = 0.34; // segundos por negra

// Frecuencias (Hz) en Do mayor.
const Map<String, double> notas = {
  'C': 523.25,
  'D': 587.33,
  'E': 659.26,
  'F': 698.46,
  'G': 783.99,
};

// (nota, duración en negras). '-' es silencio.
const List<(String, double)> frase1 = [
  // Jingle bells, jingle bells, jingle all the way
  ('E', 1), ('E', 1), ('E', 2),
  ('E', 1), ('E', 1), ('E', 2),
  ('E', 1), ('G', 1), ('C', 1.5), ('D', 0.5), ('E', 4),
  // Oh what fun it is to ride in a one-horse open sleigh
  ('F', 1), ('F', 1), ('F', 1.5), ('F', 0.5),
  ('F', 1), ('E', 1), ('E', 1), ('E', 0.5), ('E', 0.5),
  ('E', 1), ('D', 1), ('D', 1), ('E', 1), ('D', 2), ('G', 2),
];

const List<(String, double)> frase2 = [
  ('E', 1),
  ('E', 1),
  ('E', 2),
  ('E', 1),
  ('E', 1),
  ('E', 2),
  ('E', 1),
  ('G', 1),
  ('C', 1.5),
  ('D', 0.5),
  ('E', 4),
  ('F', 1),
  ('F', 1),
  ('F', 1.5),
  ('F', 0.5),
  ('F', 1),
  ('E', 1),
  ('E', 1),
  ('E', 0.5),
  ('E', 0.5),
  ('G', 1),
  ('G', 1),
  ('F', 1),
  ('D', 1),
  ('C', 4),
];

/// Armónicos (múltiplo, amplitud, decaimiento por segundo).
const List<(double, double, double)> armonicos = [
  (1, 1.0, 3.0),
  (2, 0.45, 4.5),
  (3, 0.2, 6.5),
  (4.2, 0.08, 9.0),
];

void main(List<String> args) {
  final salida = args.isNotEmpty ? args.first : 'assets/audio/jingle_bells.wav';
  final secuencia = [...frase1, ...frase2];
  final total = secuencia.fold<double>(0, (s, n) => s + n.$2) * negra;
  const cola = 1.2; // resonancia final y silencio para enlazar el loop
  final n = ((total + cola) * tasa).round();
  final mezcla = Float64List(n);

  var t0 = 0.0;
  for (final (nota, dur) in secuencia) {
    final inicio = (t0 * tasa).round();
    t0 += dur * negra;
    final f = notas[nota]!;
    // La nota suena un poco más que su duración (resonancia), con ataque
    // y liberación suaves para evitar chasquidos.
    final largo = ((dur * negra + 0.35) * tasa).round();
    for (var i = 0; i < largo && inicio + i < n; i++) {
      final t = i / tasa;
      var v = 0.0;
      for (final (m, a, d) in armonicos) {
        v += a * math.exp(-d * t) * math.sin(2 * math.pi * f * m * t);
      }
      final ataque = math.min(1.0, t / 0.004);
      final resto = (largo - i) / tasa;
      final liberacion = math.min(1.0, resto / 0.03);
      mezcla[inicio + i] += v * ataque * liberacion;
    }
  }

  var pico = 0.0;
  for (final v in mezcla) {
    pico = math.max(pico, v.abs());
  }
  final ganancia = 0.6 * 32767 / pico;
  final datos = ByteData(44 + n * 2);
  void texto(int o, String s) {
    for (var i = 0; i < s.length; i++) {
      datos.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  texto(0, 'RIFF');
  datos.setUint32(4, 36 + n * 2, Endian.little);
  texto(8, 'WAVE');
  texto(12, 'fmt ');
  datos.setUint32(16, 16, Endian.little);
  datos.setUint16(20, 1, Endian.little); // PCM
  datos.setUint16(22, 1, Endian.little); // mono
  datos.setUint32(24, tasa, Endian.little);
  datos.setUint32(28, tasa * 2, Endian.little);
  datos.setUint16(32, 2, Endian.little);
  datos.setUint16(34, 16, Endian.little);
  texto(36, 'data');
  datos.setUint32(40, n * 2, Endian.little);
  for (var i = 0; i < n; i++) {
    // Fundido final de 0.3 s para que el loop empalme sin clic.
    final resto = (n - i) / tasa;
    final fade = math.min(1.0, resto / 0.3);
    datos.setInt16(
      44 + i * 2,
      (mezcla[i] * ganancia * fade).round().clamp(-32768, 32767),
      Endian.little,
    );
  }
  final archivo = File(salida)..createSync(recursive: true);
  archivo.writeAsBytesSync(datos.buffer.asUint8List());
  stdout.writeln(
    'Escrito $salida: ${archivo.lengthSync()} bytes, '
    '${(n / tasa).toStringAsFixed(2)} s',
  );
}
