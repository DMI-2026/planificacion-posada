import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../efectos/efectos.dart';
import '../theme/app_theme.dart';
import 'destinos.dart';

/// Ancho a partir del cual se usa NavigationRail en vez de NavigationBar.
const double anchoMinimoRail = 720;

/// Destinos que caben en la barra inferior; si hay más, el resto va en «Más».
const int destinosEnBarra = 4;

/// Estructura de la app sobre el fondo «noche mágica»: navegación inferior de
/// cristal en angosto, lateral en ancho, guirnalda de luces arriba y cambio de
/// destino con desvanecido y escala.
class ShellPosada extends StatefulWidget {
  const ShellPosada({super.key, this.onCerrarSesion});

  /// Si se indica, el shell muestra la acción «Cerrar sesión».
  final VoidCallback? onCerrarSesion;

  @override
  State<ShellPosada> createState() => _ShellPosadaState();
}

class _ShellPosadaState extends State<ShellPosada> {
  int _indice = 0;

  /// Abre la hoja de cristal con los destinos que no caben en la barra.
  Future<void> _abrirMas(BuildContext context) async {
    final elegido = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (hoja) => _HojaMas(seleccionado: _indice),
    );
    if (elegido != null && mounted) setState(() => _indice = elegido);
  }

  Widget _contenido(BuildContext context) {
    final reducido = movimientoReducido(context);
    return Column(
      children: [
        const LucesNavidenas(),
        Expanded(
          child: SafeArea(
            top: false,
            child: AnimatedSwitcher(
              duration: reducido
                  ? Duration.zero
                  : const Duration(milliseconds: 380),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (actual, anteriores) => Stack(
                fit: StackFit.expand,
                children: [...anteriores, ?actual],
              ),
              transitionBuilder: (hijo, animacion) => FadeTransition(
                opacity: animacion,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.96, end: 1).animate(animacion),
                  child: hijo,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey(_indice),
                child: destinos[_indice].builder(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cerrar = widget.onCerrarSesion;
    return LayoutBuilder(
      builder: (context, restricciones) {
        final ancho = restricciones.maxWidth >= anchoMinimoRail;
        final contenido = _contenido(context);
        final barraEnMas = destinos.length > destinosEnBarra + 1;
        if (ancho) {
          return FondoNocheMagica(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Row(
                children: [
                  _Cristal(
                    borde: const Border(
                      right: BorderSide(color: Color(0x33FFFFFF)),
                    ),
                    child: LayoutBuilder(
                      builder: (context, caja) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: caja.maxHeight,
                          ),
                          child: IntrinsicHeight(
                            child: NavigationRail(
                              selectedIndex: _indice,
                              labelType: NavigationRailLabelType.all,
                              onDestinationSelected: (i) =>
                                  setState(() => _indice = i),
                              trailing: cerrar == null
                                  ? null
                                  : Expanded(
                                      child: Align(
                                        alignment: Alignment.bottomCenter,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 16,
                                          ),
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
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: contenido),
                ],
              ),
            ),
          );
        }
        return FondoNocheMagica(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            extendBody: true,
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
            body: SafeArea(bottom: false, child: contenido),
            bottomNavigationBar: _Cristal(
              borde: const Border(top: BorderSide(color: Color(0x33FFFFFF))),
              child: NavigationBar(
                selectedIndex: math.min(
                  _indice,
                  barraEnMas ? destinosEnBarra : destinos.length - 1,
                ),
                onDestinationSelected: (i) {
                  if (barraEnMas && i == destinosEnBarra) {
                    _abrirMas(context);
                  } else {
                    setState(() => _indice = i);
                  }
                },
                destinations: [
                  for (final d in destinos.take(
                    barraEnMas ? destinosEnBarra : destinos.length,
                  ))
                    NavigationDestination(
                      icon: Icon(d.icono),
                      selectedIcon: Icon(d.iconoSeleccionado),
                      label: d.etiqueta,
                    ),
                  if (barraEnMas)
                    const NavigationDestination(
                      icon: Icon(Icons.more_horiz),
                      selectedIcon: Icon(Icons.more_horiz),
                      label: 'Más',
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Superficie de cristal para las barras de navegación.
class _Cristal extends StatelessWidget {
  const _Cristal({required this.child, required this.borde});

  final Widget child;
  final Border borde;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(color: AppTheme.cristal, border: borde),
          child: child,
        ),
      ),
    );
  }
}

/// Hoja de cristal con los destinos que no caben en la barra inferior.
class _HojaMas extends StatelessWidget {
  const _HojaMas({required this.seleccionado});

  final int seleccionado;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: _Cristal(
        borde: const Border(top: BorderSide(color: Color(0x33FFFFFF))),
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = destinosEnBarra; i < destinos.length; i++)
                    ListTile(
                      key: ValueKey('mas-${destinos[i].etiqueta}'),
                      leading: Icon(
                        i == seleccionado
                            ? destinos[i].iconoSeleccionado
                            : destinos[i].icono,
                      ),
                      title: Text(destinos[i].etiqueta),
                      selected: i == seleccionado,
                      onTap: () => Navigator.of(context).pop(i),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
