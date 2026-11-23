import 'package:flutter/material.dart';

import 'destinos.dart';

/// Ancho a partir del cual se usa NavigationRail en vez de NavigationBar.
const double anchoMinimoRail = 720;

/// Estructura de la app: navegación inferior en angosto, lateral en ancho.
class ShellPosada extends StatefulWidget {
  const ShellPosada({super.key, this.onCerrarSesion});

  /// Si se indica, el shell muestra la acción «Cerrar sesión».
  final VoidCallback? onCerrarSesion;

  @override
  State<ShellPosada> createState() => _ShellPosadaState();
}

class _ShellPosadaState extends State<ShellPosada> {
  int _indice = 0;

  @override
  Widget build(BuildContext context) {
    final cerrar = widget.onCerrarSesion;
    return LayoutBuilder(
      builder: (context, restricciones) {
        final ancho = restricciones.maxWidth >= anchoMinimoRail;
        final contenido = SafeArea(child: destinos[_indice].builder(context));
        if (ancho) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _indice,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (i) => setState(() => _indice = i),
                  trailing: cerrar == null
                      ? null
                      : Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: IconButton(
                                tooltip: 'Cerrar sesión',
                                icon: const Icon(Icons.logout),
                                onPressed: cerrar,
                              ),
                            ),
                          ),
                        ),
                  destinations: [
                    for (final d in destinos)
                      NavigationRailDestination(
                        icon: Icon(d.icono),
                        selectedIcon: Icon(d.iconoSeleccionado),
                        label: Text(d.etiqueta),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: contenido),
              ],
            ),
          );
        }
        return Scaffold(
          appBar: cerrar == null
              ? null
              : AppBar(
                  title: const Text('Posada de la clase'),
                  actions: [
                    IconButton(
                      tooltip: 'Cerrar sesión',
                      icon: const Icon(Icons.logout),
                      onPressed: cerrar,
                    ),
                  ],
                ),
          body: contenido,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _indice,
            onDestinationSelected: (i) => setState(() => _indice = i),
            destinations: [
              for (final d in destinos)
                NavigationDestination(
                  icon: Icon(d.icono),
                  selectedIcon: Icon(d.iconoSeleccionado),
                  label: d.etiqueta,
                ),
            ],
          ),
        );
      },
    );
  }
}
