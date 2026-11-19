import 'package:flutter_test/flutter_test.dart';

import '../integration_test/estado_web_ensayo.dart';

void main() {
  test('reconoce el estado del template anterior', () {
    expect(
      contieneEstadoNotaWeb(
        '<dt>Estado</dt><dd>Cerrada</dd>',
        'cerrada',
        'Cerrada',
      ),
      isTrue,
    );
  });
  test('reconoce data-state aunque cambien clases y texto visual', () {
    expect(
      contieneEstadoNotaWeb(
        '<span class="estado" data-state="en_atencion">En atención</span>',
        'en_atencion',
        'En atención',
      ),
      isTrue,
    );
  });
  test('un estado incorrecto no pasa por otro texto de la página', () {
    expect(
      contieneEstadoNotaWeb(
        '<span data-state="recibida">Recibida</span><dd>Cerrada</dd>',
        'cerrada',
        'Cerrada',
      ),
      isFalse,
    );
  });
  test('acepta atributos con espacios y comillas simples', () {
    expect(
      contieneEstadoNotaWeb(
        "<span data-state = 'CERRADA'>Cerrada</span>",
        'cerrada',
        'Cerrada',
      ),
      isTrue,
    );
  });
}
