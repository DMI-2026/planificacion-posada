/// Lectura tolerante de valores de RTDB (los números pueden llegar como
/// `int` o `double`).
int leerEntero(Object? valor, [int defecto = 0]) =>
    valor is num ? valor.toInt() : defecto;

String leerTexto(Object? valor, [String defecto = '']) =>
    valor is String ? valor : defecto;
