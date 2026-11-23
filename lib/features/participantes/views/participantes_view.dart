import 'package:flutter/material.dart';

import '../../../core/efectos/efectos.dart';
import '../../../core/navegacion/posada_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/estados.dart';
import '../models/participante.dart';
import '../viewmodels/participantes_view_model.dart';

String _etiqueta(Asistencia a) => switch (a) {
  Asistencia.si => 'Sí',
  Asistencia.talVez => 'Tal vez',
  Asistencia.no => 'No',
};

IconData _icono(Asistencia a) => switch (a) {
  Asistencia.si => Icons.celebration,
  Asistencia.talVez => Icons.hourglass_top,
  Asistencia.no => Icons.nights_stay_outlined,
};

Color _acento(Asistencia a) => switch (a) {
  Asistencia.si => AppTheme.auroraTurquesa,
  Asistencia.talVez => AppTheme.oro,
  Asistencia.no => const Color(0xFFFF8A94),
};

const _paresAvatar = <List<Color>>[
  [Color(0xFFFF4FD8), Color(0xFF7C3AED)],
  [Color(0xFF2EE6C8), Color(0xFF2563EB)],
  [Color(0xFFFFC857), Color(0xFFD62839)],
  [Color(0xFF7C8CFF), Color(0xFFFF4FD8)],
  [Color(0xFF2EE6C8), Color(0xFF16A34A)],
  [Color(0xFFFF8A94), Color(0xFFB5179E)],
];

/// Iniciales (hasta dos) de [nombre], en mayúsculas.
String iniciales(String nombre) {
  final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final letras = partes.take(2).map((p) => p.characters.first).join();
  return letras.isEmpty ? '?' : letras.toUpperCase();
}

/// Degradado estable por nombre (mismo nombre, mismo color).
List<Color> degradadoAvatar(String nombre) {
  final hash = nombre.codeUnits.fold<int>(
    7,
    (h, c) => (h * 31 + c) & 0x7fffffff,
  );
  return _paresAvatar[hash % _paresAvatar.length];
}

/// Lista de participantes con su asistencia.
class ParticipantesView extends StatelessWidget {
  const ParticipantesView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = PosadaScope.of(context).participantes;
    return ListenableBuilder(
      listenable: Listenable.merge([vm, vm.sesion]),
      builder: (context, _) => Scaffold(
        backgroundColor: Colors.transparent,
        body: _cuerpo(context, vm),
      ),
    );
  }

  Widget _cuerpo(BuildContext context, ParticipantesViewModel vm) {
    if (vm.cargando) return const EstadoCargando();
    final tema = Theme.of(context);
    final encabezado = <Widget>[
      Text('Participantes', style: tema.textTheme.headlineSmall),
      const SizedBox(height: 4),
      Text(
        'Aquí aparece cada persona que se registró en la app.',
        style: tema.textTheme.bodySmall?.copyWith(
          color: tema.colorScheme.onSurfaceVariant,
        ),
      ),
      if (vm.sesion.esAdmin)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              avatar: Icon(Icons.verified_user, size: 18),
              label: Text('Eres admin'),
            ),
          ),
        ),
      const SizedBox(height: 12),
      Row(
        children: [
          for (final a in Asistencia.values)
            _Conteo(
              etiqueta: _etiqueta(a),
              valor: vm.conteo(a),
              icono: _icono(a),
              acento: _acento(a),
            ),
        ],
      ),
      if (vm.error != null) BannerError(mensaje: vm.error!),
      if (vm.vacio)
        const SizedBox(
          height: 240,
          child: EstadoVacio(
            icono: Icons.group_outlined,
            mensaje: 'Aún no hay participantes registrados.',
          ),
        ),
      const SizedBox(height: 8),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...EntradaEscalonada.lista(encabezado),
        for (var i = 0; i < vm.participantes.length; i++)
          EntradaEscalonada(
            key: ValueKey('participante-${vm.participantes[i].id}'),
            indice: i + encabezado.length,
            child: _TarjetaParticipante(vm: vm, p: vm.participantes[i]),
          ),
      ],
    );
  }
}

class _Conteo extends StatelessWidget {
  const _Conteo({
    required this.etiqueta,
    required this.valor,
    required this.icono,
    required this.acento,
  });

  final String etiqueta;
  final int valor;
  final IconData icono;
  final Color acento;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: acento.withValues(alpha: 0.14),
            border: Border.all(color: acento.withValues(alpha: 0.55)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icono, size: 16, color: acento),
                const SizedBox(width: 4),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ContadorAnimado(
                      valor: valor,
                      duracion: const Duration(milliseconds: 700),
                      formato: (v) => '$etiqueta: $v',
                      estilo: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TarjetaParticipante extends StatelessWidget {
  const _TarjetaParticipante({required this.vm, required this.p});

  final ParticipantesViewModel vm;
  final Participante p;

  Future<void> _quitar(BuildContext context) async {
    if (await _confirmarQuitar(context, p.nombre)) await vm.eliminar(p.id);
  }

  void _cambiar(BuildContext context, Asistencia nueva) {
    final alConfirmar =
        vm.esYo(p.id) && nueva == Asistencia.si && p.asistencia != nueva;
    vm.cambiarAsistencia(p.id, nueva);
    if (alConfirmar) lanzarConfeti(context);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final yo = vm.esYo(p.id);
    final colores = degradadoAvatar(p.nombre);
    Widget tarjeta = TarjetaCristal(
      acento: yo ? AppTheme.oro : colores.first,
      radio: 22,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(nombre: p.nombre, colores: colores, destacado: yo),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  yo ? '${p.nombre} (Tú)' : p.nombre,
                  style: tema.textTheme.titleMedium?.copyWith(
                    color: yo ? AppTheme.oro : null,
                  ),
                ),
              ),
              if (vm.puedeEliminar)
                IconButton(
                  tooltip: 'Quitar a ${p.nombre} de la lista',
                  icon: const Icon(Icons.person_remove_outlined),
                  color: tema.colorScheme.error,
                  onPressed: () => _quitar(context),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<Asistencia>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: _acento(p.asistencia)
                  .withValues(alpha: 0.30),
              selectedForegroundColor: _acento(p.asistencia),
              visualDensity: VisualDensity.comfortable,
            ),
            segments: [
              for (final a in Asistencia.values)
                ButtonSegment(
                  value: a,
                  icon: Icon(_icono(a), size: 18),
                  label: Text(_etiqueta(a)),
                ),
            ],
            selected: {p.asistencia},
            onSelectionChanged: vm.puedeCambiarAsistencia(p.id)
                ? (s) => _cambiar(context, s.first)
                : null,
          ),
        ],
      ),
    );
    if (yo) {
      tarjeta = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppTheme.oro.withValues(alpha: 0.35),
              blurRadius: 22,
              spreadRadius: 1,
            ),
          ],
        ),
        child: tarjeta,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: tarjeta,
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.nombre,
    required this.colores,
    required this.destacado,
  });

  final String nombre;
  final List<Color> colores;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colores,
        ),
        border: Border.all(
          color: destacado ? AppTheme.oro : const Color(0x66FFFFFF),
          width: destacado ? 2.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colores.first.withValues(alpha: 0.45),
            blurRadius: 12,
          ),
        ],
      ),
      child: ExcludeSemantics(
        child: Text(
          iniciales(nombre),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            shadows: [Shadow(color: Color(0x99000000), blurRadius: 4)],
          ),
        ),
      ),
    );
  }
}

/// Confirmación con el estilo de la noche antes de quitar a alguien.
Future<bool> _confirmarQuitar(BuildContext context, String nombre) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(
        Icons.person_remove_outlined,
        size: 36,
        color: Theme.of(ctx).colorScheme.error,
      ),
      title: const Text('Eliminar'),
      content: Text('¿Eliminar $nombre?'),
      actionsAlignment: MainAxisAlignment.center,
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
