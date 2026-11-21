// Opt-in: combina la prueba local pedida por Russel con el recorrido real.
// Requiere exclusivamente cuentas y expedientes ficticios, fuera de Git.
import 'acceso_recepcion_local_test.dart' as acceso;
import 'notas_camunda_real_test.dart' as recorrido;

void main() {
  acceso.main();
  recorrido.main();
}
