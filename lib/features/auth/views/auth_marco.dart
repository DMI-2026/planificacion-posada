import 'package:flutter/material.dart';

import '../../../core/efectos/efectos.dart';

/// Marco compartido de login y registro: cielo animado (opcional), luces,
/// título mágico y la tarjeta de cristal donde vive el formulario.
class MarcoAuth extends StatelessWidget {
  const MarcoAuth({
    super.key,
    required this.subtitulo,
    required this.child,
    this.conFondo = true,
  });

  /// Frase bajo el título que dice en qué paso está la persona.
  final String subtitulo;
  final Widget child;

  /// Si es `false`, el cielo lo pinta quien aloja la vista (p. ej. la puerta
  /// de sesión, para no reiniciarlo al cambiar entre login y registro).
  final bool conFondo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final contenido = Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: EntradaEscalonada.lista([
                  const LucesNavidenas(),
                  const SizedBox(height: 8),
                  TituloMagico(
                    'Posada de la clase',
                    textAlign: TextAlign.center,
                    estilo: tema.textTheme.displaySmall?.copyWith(
                      fontSize: 38,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitulo,
                    textAlign: TextAlign.center,
                    style: tema.textTheme.bodyLarge?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TarjetaCristal(
                    padding: const EdgeInsets.all(24),
                    inclinacion: false,
                    child: child,
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
    return conFondo ? FondoNocheMagica(child: contenido) : contenido;
  }
}

/// Mensaje de error del formulario que aparece y desaparece con suavidad.
class ErrorAuth extends StatelessWidget {
  const ErrorAuth({super.key, required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    final contenido = mensaje.isEmpty
        ? const SizedBox(width: double.infinity)
        : Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(mensaje, style: TextStyle(color: color)),
                ),
              ],
            ),
          );
    if (movimientoReducido(context)) return contenido;
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: contenido,
    );
  }
}
