/// Tipos de adorno que se cuelgan del árbol.
enum TipoAdorno {
  esfera,
  regalo;

  /// Valor guardado en Firestore (`tipo`).
  String get clave => name;

  static TipoAdorno desdeClave(Object? valor) {
    for (final t in values) {
      if (t.name == valor) return t;
    }
    throw FormatException('Tipo de adorno desconocido: $valor');
  }
}

/// Dibujo de una esfera.
enum PatronEsfera {
  liso,
  rayas,
  puntos,
  estrellas;

  String get clave => name;

  static PatronEsfera desdeClave(Object? valor) {
    for (final p in values) {
      if (p.name == valor) return p;
    }
    throw FormatException('Patrón desconocido: $valor');
  }
}

/// Límites del árbol. IMPORTANTE: deben coincidir con `arbol.rules`.
abstract final class LimitesArbol {
  /// Adornos por persona (un slot 0..9 por adorno).
  static const int maxAdornos = 10;
  static const int maxMensaje = 60;

  /// Cada cuánto se escribe la posición mientras se arrastra.
  static const Duration intervaloMovimiento = Duration(milliseconds: 250);
}

/// Colores permitidos (`#RRGGBB` en mayúsculas). IMPORTANTE: es la misma lista
/// que `arbolPaleta()` en `arbol.rules`.
abstract final class PaletaArbol {
  static const List<String> colores = [
    '#D62839', // rojo festivo
    '#FFC857', // oro
    '#2EE6C8', // turquesa
    '#FF4FD8', // magenta
    '#4F7CFF', // azul
    '#2FBF71', // verde
    '#F4F0FF', // perla
    '#8E5BFF', // violeta
    '#FF8A3D', // naranja
    '#C9CEE8', // plata
  ];

  static bool esValido(String? color) =>
      color != null && colores.contains(color);
}

/// Un adorno colgado del árbol: esfera o regalo.
///
/// Documento `arbol_adornos/{uid}_{slot}`. La posición [x], [y] es normalizada
/// (0..1) respecto al área del árbol.
class Adorno {
  const Adorno({
    required this.id,
    required this.tipo,
    required this.autorId,
    required this.color,
    this.patron,
    this.colorMono,
    this.mensaje = '',
    required this.x,
    required this.y,
    this.creado,
    this.actualizado,
  }) : assert(
         tipo == TipoAdorno.esfera
             ? patron != null && colorMono == null
             : colorMono != null && patron == null,
         'La esfera lleva patrón; el regalo lleva color_mono',
       );

  final String id;
  final TipoAdorno tipo;
  final String autorId;

  /// Color de la esfera o de la caja del regalo (`#RRGGBB` de la paleta).
  final String color;

  /// Solo esferas.
  final PatronEsfera? patron;

  /// Solo regalos: color del listón.
  final String? colorMono;
  final String mensaje;
  final double x;
  final double y;
  final DateTime? creado;
  final DateTime? actualizado;

  /// Id del documento de [uid] en el [slot] (0..9).
  static String idDe(String uid, int slot) => '${uid}_$slot';

  /// Slot (0..9) que indica el id, o `null` si no tiene la forma `{uid}_{n}`.
  int? get slot {
    final i = id.lastIndexOf('_');
    return i < 0 ? null : int.tryParse(id.substring(i + 1));
  }

  /// El [id] es el del documento. Lanza [FormatException] si faltan datos.
  factory Adorno.fromMap(
    String id,
    Map<String, dynamic> map, {
    DateTime? creado,
    DateTime? actualizado,
  }) {
    final tipo = TipoAdorno.desdeClave(map['tipo']);
    final x = map['x'];
    final y = map['y'];
    final autor = map['autor_id'];
    final color = map['color'];
    if (x is! num || y is! num || autor is! String || color is! String) {
      throw const FormatException('Adorno incompleto');
    }
    return Adorno(
      id: id,
      tipo: tipo,
      autorId: autor,
      color: color,
      patron: tipo == TipoAdorno.esfera
          ? PatronEsfera.desdeClave(map['patron'])
          : null,
      colorMono: tipo == TipoAdorno.regalo ? map['color_mono'] as String : null,
      mensaje: map['mensaje'] as String? ?? '',
      x: x.toDouble(),
      y: y.toDouble(),
      creado: creado,
      actualizado: actualizado,
    );
  }

  /// Datos del documento SIN las marcas de tiempo (`creado`, `actualizado`):
  /// las pone el servidor. Las claves dependen del tipo.
  Map<String, dynamic> toMap() {
    return {
      'tipo': tipo.clave,
      'autor_id': autorId,
      'color': color,
      if (tipo == TipoAdorno.esfera) 'patron': patron!.clave,
      if (tipo == TipoAdorno.regalo) 'color_mono': colorMono,
      'mensaje': mensaje,
      'x': x,
      'y': y,
    };
  }

  Adorno copyWith({
    String? color,
    PatronEsfera? patron,
    String? colorMono,
    String? mensaje,
    double? x,
    double? y,
  }) {
    return Adorno(
      id: id,
      tipo: tipo,
      autorId: autorId,
      color: color ?? this.color,
      patron: tipo == TipoAdorno.esfera ? (patron ?? this.patron) : null,
      colorMono: tipo == TipoAdorno.regalo
          ? (colorMono ?? this.colorMono)
          : null,
      mensaje: mensaje ?? this.mensaje,
      x: x ?? this.x,
      y: y ?? this.y,
      creado: creado,
      actualizado: actualizado,
    );
  }
}
