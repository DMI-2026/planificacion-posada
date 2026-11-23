import 'dart:math';

/// Sorteo del amigo secreto: un desarreglo con un solo ciclo (algoritmo de
/// Sattolo). Nadie se toca a sí mismo, todos dan y reciben exactamente una
/// vez, y la cadena es un único círculo (A→B→C→A).
///
/// Devuelve `quienDa -> quienRecibe`. Requiere al menos 2 ids distintos.
/// Los ids se ordenan antes de barajar: con la misma semilla el resultado es
/// reproducible.
Map<String, String> sortearParejas(Iterable<String> ids, Random random) {
  final lista = ids.toList()..sort();
  if (lista.toSet().length != lista.length) {
    throw ArgumentError.value(ids, 'ids', 'Hay ids repetidos.');
  }
  final n = lista.length;
  if (n < 2) {
    throw ArgumentError.value(ids, 'ids', 'Se necesitan al menos 2 ids.');
  }
  final p = List<int>.generate(n, (i) => i);
  for (var i = n - 1; i >= 1; i--) {
    final j = random.nextInt(i); // 0..i-1: nunca i, de ahí el único ciclo
    final t = p[i];
    p[i] = p[j];
    p[j] = t;
  }
  return {for (var i = 0; i < n; i++) lista[i]: lista[p[i]]};
}
