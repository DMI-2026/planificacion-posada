import '../models/tipo_mejora.dart';
import 'reglas_cohetazo.dart';

/// Celda de la cuadrícula `(x, y)`.
typedef Celda = (int, int);

/// Mapa fijo de la arena: muros, cajas iniciales, puntos de aparición y azar
/// determinista.
///
/// El azar usa un hash propio de 32 bits con aritmética enmascarada para que
/// web (dart2js) y Android den exactamente los mismos resultados. No se usa
/// `hashCode` ni `Random`.
abstract final class MapaArena {
  static const int _mascara = 0xFFFFFFFF;

  /// Multiplicación de 32 bits sin salir de 2^53 (segura en JS).
  static int _mul32(int a, int b) {
    final x = a & _mascara;
    final y = b & _mascara;
    final bajo = (x & 0xFFFF) * y;
    final alto = ((x >>> 16) * y) & 0xFFFF;
    return (bajo + alto * 65536) & _mascara;
  }

  /// Hash de 32 bits (sin signo) de una lista de enteros no negativos.
  /// Cada entero aporta sus 32 bits bajos y los altos (hasta 2^53).
  static int hash(List<int> valores) {
    var h = 0x811C9DC5;
    for (final v in valores) {
      final bajo = v & _mascara;
      final alto = (v ~/ 4294967296) & _mascara;
      h = _mul32(h ^ bajo, 0x01000193);
      h = _mul32(h ^ alto, 0x01000193);
    }
    h ^= h >>> 16;
    h = _mul32(h, 0x85EBCA6B);
    h ^= h >>> 13;
    h = _mul32(h, 0xC2B2AE35);
    h ^= h >>> 16;
    return h & _mascara;
  }

  /// Hash de una cadena (unidades de código UTF-16) más enteros.
  static int hashTexto(String texto, List<int> valores) =>
      hash([...texto.codeUnits, texto.length, ...valores]);

  /// Muro fijo: fuera de la cuadrícula, borde, o x e y pares.
  static bool esMuro(int x, int y) {
    if (x <= 0 ||
        y <= 0 ||
        x >= ReglasCohetazo.columnas - 1 ||
        y >= ReglasCohetazo.filas - 1) {
      return true;
    }
    return x.isEven && y.isEven;
  }

  /// 12 puntos de aparición: 4 esquinas interiores y 8 celdas simétricas.
  static const List<Celda> puntosAparicion = [
    (1, 1),
    (19, 1),
    (1, 15),
    (19, 15),
    (5, 1),
    (15, 1),
    (5, 15),
    (15, 15),
    (1, 7),
    (19, 7),
    (1, 9),
    (19, 9),
  ];

  static final Set<Celda> _libresDeCaja = _calcularLibres();

  static Set<Celda> _calcularLibres() {
    final s = <Celda>{};
    for (final (x, y) in puntosAparicion) {
      s.add((x, y));
      s.add((x + 1, y));
      s.add((x - 1, y));
      s.add((x, y + 1));
      s.add((x, y - 1));
    }
    return s;
  }

  /// Si en el estado inicial hay una caja en la celda.
  static bool hayCajaInicial(int x, int y) {
    if (esMuro(x, y) || _libresDeCaja.contains((x, y))) return false;
    return hash([x, y, ReglasCohetazo.semillaArena]) % 100 <
        ReglasCohetazo.probabilidadCaja;
  }

  /// Punto de aparición elegido por hash de uid y número de reapariciones.
  /// Si está en [ocupadas] se prueba el siguiente de la lista.
  static Celda puntoAparicion(
    String uid,
    int reapariciones, {
    Set<Celda> ocupadas = const {},
  }) {
    final n = puntosAparicion.length;
    final inicio = hashTexto(uid, [reapariciones]) % n;
    for (var i = 0; i < n; i++) {
      final p = puntosAparicion[(inicio + i) % n];
      if (!ocupadas.contains(p)) return p;
    }
    return puntosAparicion[inicio];
  }

  /// Mejora que suelta la caja de (x, y) rota en el instante [rota], o null.
  static TipoMejora? mejoraEn(int x, int y, int rota) {
    final h = hash([x, y, rota, ReglasCohetazo.semillaArena + 1]);
    if (h % 100 >= ReglasCohetazo.probabilidadMejora) return null;
    return TipoMejora.values[(h ~/ 100) % TipoMejora.values.length];
  }
}
