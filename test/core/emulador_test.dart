import 'package:flutter_test/flutter_test.dart';
import 'package:planificacion_posada/core/config/emulador.dart';

void main() {
  group('hostEmulador', () {
    test('usa el host definido cuando no está vacío', () {
      expect(
        hostEmulador(esWeb: false, esAndroid: true, definido: '192.168.1.20'),
        '192.168.1.20',
      );
      expect(
        hostEmulador(esWeb: true, esAndroid: false, definido: 'mi-compu'),
        'mi-compu',
      );
    });

    test('Android (no web) usa 10.0.2.2', () {
      expect(hostEmulador(esWeb: false, esAndroid: true), '10.0.2.2');
    });

    test('web usa localhost aunque la plataforma sea Android', () {
      expect(hostEmulador(esWeb: true, esAndroid: true), 'localhost');
    });

    test('otras plataformas usan localhost', () {
      expect(hostEmulador(esWeb: false, esAndroid: false), 'localhost');
    });
  });
}
