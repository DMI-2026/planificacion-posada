import 'package:flutter/material.dart';

/// Indicador de carga centrado.
class EstadoCargando extends StatelessWidget {
  const EstadoCargando({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

/// Estado vacío con icono y mensaje.
class EstadoVacio extends StatelessWidget {
  const EstadoVacio({super.key, required this.icono, required this.mensaje});

  final IconData icono;
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Banner de error en línea (no oculta el contenido).
class BannerError extends StatelessWidget {
  const BannerError({super.key, required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Card(
      color: esquema.errorContainer,
      child: ListTile(
        leading: Icon(Icons.error_outline, color: esquema.onErrorContainer),
        title: Text(mensaje, style: TextStyle(color: esquema.onErrorContainer)),
      ),
    );
  }
}

/// Chip con un contador, p. ej. `Sí: 2`.
class ChipConteo extends StatelessWidget {
  const ChipConteo({super.key, required this.etiqueta, required this.valor});

  final String etiqueta;
  final int valor;

  @override
  Widget build(BuildContext context) => Chip(label: Text('$etiqueta: $valor'));
}

/// Diálogo de confirmación; devuelve `true` si el usuario confirma.
Future<bool> confirmarEliminar(BuildContext context, String que) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Eliminar'),
      content: Text('¿Eliminar $que?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  return r ?? false;
}
