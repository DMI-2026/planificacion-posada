import '../models/tipo_mejora.dart';
import 'mapa_arena.dart';

/// Celda en llamas durante un intervalo, con su responsable.
class FuegoCelda {
  const FuegoCelda({
    required this.x,
    required this.y,
    required this.uid,
    required this.idCohete,
    required this.inicio,
    required this.fin,
  });

  final int x;
  final int y;

  /// Dueño del cohete que causó el fuego (autor de las eliminaciones).
  final String uid;
  final String idCohete;

  /// Activo en `[inicio, fin)` (ms, hora del servidor).
  final int inicio;
  final int fin;

  bool activaEn(int ahora) => ahora >= inicio && ahora < fin;
}

/// Resultado determinista de la explosión de un cohete.
class Explosion {
  const Explosion({
    required this.idCohete,
    required this.uid,
    required this.x,
    required this.y,
    required this.inicio,
    required this.fin,
    required this.celdas,
    required this.cajasRotas,
  });

  final String idCohete;
  final String uid;
  final int x;
  final int y;
  final int inicio;
  final int fin;

  /// Celdas en llamas (incluye el centro y la caja destruida).
  final List<Celda> celdas;

  /// Cajas destruidas por esta explosión.
  final List<Celda> cajasRotas;

  List<FuegoCelda> get fuego => [
    for (final (cx, cy) in celdas)
      FuegoCelda(
        x: cx,
        y: cy,
        uid: uid,
        idCohete: idCohete,
        inicio: inicio,
        fin: fin,
      ),
  ];
}

/// Mejora suelta en el suelo, esperando a que alguien la reclame.
class MejoraSuelta {
  const MejoraSuelta({
    required this.x,
    required this.y,
    required this.rota,
    required this.tipo,
    required this.clave,
  });

  final int x;
  final int y;
  final int rota;
  final TipoMejora tipo;

  /// Clave `x_y_rota` en `/cohetazo/mejoras`.
  final String clave;
}
