import 'package:flutter/material.dart';

import '../../compartido/diseno/institucional.dart';
import 'nota_interna.dart';
import 'seguimiento_nota.dart';

class DocumentoNota extends StatelessWidget {
  const DocumentoNota({super.key, required this.nota});
  final NotaInterna nota;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: Institucional.borde),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('NOTA INTERNA', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        DatoInstitucional('CITE', nota.cite),
        DatoInstitucional('DE', nota.emisor),
        DatoInstitucional('A', nota.destinataria),
        DatoInstitucional('Asunto', nota.asunto),
        if (nota.datos['referencia'] case final String referencia)
          DatoInstitucional('Referencia', referencia),
        const Divider(height: 28),
        SelectableText(
          nota.cuerpo ?? 'El contenido no está disponible.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        if (nota.constancias.isNotEmpty) ...[
          const SizedBox(height: 24),
          ConstanciasNota(constancias: nota.constancias),
        ],
      ],
    ),
  );
}

class VistaPreviaNota extends StatelessWidget {
  const VistaPreviaNota({super.key, required this.nota});
  final NotaInterna nota;
  @override
  Widget build(BuildContext context) => InterfazInstitucional(
    builder: (_) => Scaffold(
      appBar: const CabeceraInstitucional(titulo: 'Vista previa'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: DocumentoNota(nota: nota),
      ),
    ),
  );
}
