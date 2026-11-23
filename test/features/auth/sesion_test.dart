import 'package:flutter_test/flutter_test.dart';
import 'package:planificacion_posada/features/auth/models/usuario.dart';
import 'package:planificacion_posada/features/auth/repositories/fake_admin_repository.dart';
import 'package:planificacion_posada/features/auth/viewmodels/sesion_view_model.dart';
import 'package:planificacion_posada/features/participantes/models/participante.dart';
import 'package:planificacion_posada/features/participantes/repositories/fake_participante_repository.dart';

Future<void> _pausa() => Future<void>.delayed(Duration.zero);

const _ana = Usuario(id: 'u-1', correo: 'ana@posada.mx', nombre: 'Ana');

Future<List<Participante>> _lista(FakeParticipanteRepository repo) =>
    repo.participantes.first;

void main() {
  group('asegurar (participantes/{uid})', () {
    test('crea el documento con id = uid, talVez y el nombre', () async {
      final repo = FakeParticipanteRepository();
      await repo.asegurar('u-1', 'Ana');
      final lista = await _lista(repo);
      expect(lista, hasLength(1));
      expect(lista.single.id, 'u-1');
      expect(lista.single.nombre, 'Ana');
      expect(lista.single.asistencia, Asistencia.talVez);
    });

    test(
      'no sobrescribe asistencia ni nombre de un documento existente',
      () async {
        final repo = FakeParticipanteRepository(
          inicial: const [
            Participante(id: 'u-1', nombre: 'Ana', asistencia: Asistencia.si),
          ],
        );
        await repo.asegurar('u-1', 'Otro nombre');
        await repo.asegurar('u-1', 'Ana');
        final lista = await _lista(repo);
        expect(lista, hasLength(1));
        expect(lista.single.asistencia, Asistencia.si);
        expect(lista.single.nombre, 'Ana');
      },
    );

    test('llamarlo dos veces no duplica', () async {
      final repo = FakeParticipanteRepository();
      await repo.asegurar('u-1', 'Ana');
      await repo.asegurar('u-1', 'Ana');
      expect(await _lista(repo), hasLength(1));
    });
  });

  group('SesionViewModel', () {
    test('al iniciar sesión crea su participante y no es admin', () async {
      final repo = FakeParticipanteRepository();
      final sesion = SesionViewModel(
        usuario: _ana,
        admins: FakeAdminRepository(),
        participantes: repo,
      );
      expect(sesion.resolviendo, isTrue);
      await _pausa();
      expect(sesion.resolviendo, isFalse);
      expect(sesion.esAdmin, isFalse);
      expect((await _lista(repo)).single.id, 'u-1');
      sesion.dispose();
    });

    test('esAdmin es true si existe admins/{uid}', () async {
      final sesion = SesionViewModel(
        usuario: _ana,
        admins: FakeAdminRepository(admins: {'u-1'}),
        participantes: FakeParticipanteRepository(),
      );
      await _pausa();
      expect(sesion.esAdmin, isTrue);
      sesion.dispose();
    });

    test('un error al leer admins cuenta como no admin y no truena', () async {
      final sesion = SesionViewModel(
        usuario: _ana,
        admins: FakeAdminRepository(admins: {'u-1'}, falla: true),
        participantes: FakeParticipanteRepository(),
      );
      await _pausa();
      expect(sesion.esAdmin, isFalse);
      expect(sesion.resolviendo, isFalse);
      sesion.dispose();
    });

    test(
      'una cuenta antigua conserva su asistencia al volver a entrar',
      () async {
        final repo = FakeParticipanteRepository(
          inicial: const [
            Participante(id: 'u-1', nombre: 'Ana', asistencia: Asistencia.no),
          ],
        );
        final sesion = SesionViewModel(
          usuario: _ana,
          admins: FakeAdminRepository(),
          participantes: repo,
        );
        await _pausa();
        expect((await _lista(repo)).single.asistencia, Asistencia.no);
        sesion.dispose();
      },
    );

    test(
      'nombre: displayName, luego parte local del correo, luego genérico',
      () {
        expect(SesionViewModel.nombreParaParticipante(_ana), 'Ana');
        expect(
          SesionViewModel.nombreParaParticipante(
            const Usuario(id: 'x', correo: 'maxi@correo.com', nombre: ''),
          ),
          'maxi',
        );
        expect(
          SesionViewModel.nombreParaParticipante(
            const Usuario(id: 'x', correo: '', nombre: ' '),
          ),
          'Participante',
        );
        expect(
          SesionViewModel.nombreParaParticipante(
            Usuario(id: 'x', correo: 'a@b.mx', nombre: 'n' * 101),
          ),
          'n' * 100,
        );
      },
    );
  });
}
