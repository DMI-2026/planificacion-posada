import 'package:flutter_test/flutter_test.dart';
import 'package:planificacion_posada/features/auth/models/usuario.dart';
import 'package:planificacion_posada/features/auth/viewmodels/sesion_view_model.dart';

void main() {
  group('Límites de participantes (iguales a firestore.rules)', () {
    test('acepta nombre de 100 caracteres', () {
      final u = Usuario(id: 'u', correo: 'a@b.mx', nombre: 'n' * 100);
      expect(SesionViewModel.nombreParaParticipante(u), 'n' * 100);
    });

    test('recorta un nombre de más de 100 para que lo acepten las reglas', () {
      final u = Usuario(id: 'u', correo: 'a@b.mx', nombre: 'n' * 101);
      expect(SesionViewModel.nombreParaParticipante(u).length, 100);
    });
  });
}
