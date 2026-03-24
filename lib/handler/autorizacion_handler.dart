// ignore_for_file: deprecated_member_use
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../pdf_generators/autorizacion_pdf.dart';

class AutorizacionHandler {
  static Future<void> handleGenerate({
    required BuildContext context,
    required Map<String, dynamic> cocheData,
    required int cocheId,
    required String initialTransporte,
    required VoidCallback refresh,
  }) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (cocheData['pdf_autorizacion_url'] != null &&
        (cocheData['pdf_autorizacion_url'] as String).isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text("Regenerar autorización"),
          content: const Text(
              "¿Está seguro que desea regenerar el PDF de Autorización?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Cancelar"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text("Sí, continuar",
                  style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    String? selectedTransporte =
        initialTransporte.isNotEmpty ? initialTransporte : null;
    final transporteController = TextEditingController();
    final cifController = TextEditingController();
    final transportes = ['Auto1', 'Manuel', 'Orencio', 'Guadalix', 'Otro'];

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Seleccionar Transporte'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...transportes.map((t) => RadioListTile<String>(
                        title: Text(t),
                        value: t,
                        groupValue: selectedTransporte,
                        onChanged: (v) {
                          setState(() => selectedTransporte = v);
                        },
                      )),
                  if (selectedTransporte == 'Otro') ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: transporteController,
                      decoration: const InputDecoration(
                          labelText: 'Transporte/Empresa'),
                    ),
                    TextField(
                      controller: cifController,
                      decoration: const InputDecoration(labelText: 'CIF/DNI'),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (selectedTransporte == null) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text('Seleccione un transporte')),
                    );
                    return;
                  }
                  String transporteFinal = selectedTransporte!;
                  String cif = '';
                  if (selectedTransporte == 'Otro') {
                    transporteFinal = transporteController.text.trim();
                    cif = cifController.text.trim().toUpperCase();
                    if (transporteFinal.isEmpty || cif.isEmpty) {
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(content: Text('Complete los campos')),
                      );
                      return;
                    }
                  }
                  Navigator.pop(dialogContext,
                      {'transporte': transporteFinal, 'cif': cif});
                },
                child: const Text('Aceptar'),
              ),
            ],
          );
        },
      ),
    );

    if (result == null) return;

    try {
      final pdfBytes = await generateAutorizacionPdf(
        marca: cocheData['marca']?.toString() ?? '',
        modelo: cocheData['modelo']?.toString() ?? '',
        matricula: cocheData['matricula']?.toString() ?? '',
        transporte: result['transporte']!,
        cif: result['cif']!,
      );

      final fileName =
          'autorizacion_${cocheData['id']}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      await Supabase.instance.client.storage
          .from('pdfs')
          .uploadBinary(fileName, pdfBytes);

      final pdfUrl =
          Supabase.instance.client.storage.from('pdfs').getPublicUrl(fileName);

      await Supabase.instance.client.from('coches').update({
        'pdf_autorizacion_url': pdfUrl,
        'transporte': result['transporte'],
      }).eq('id', cocheId);

      refresh();

      if (context.mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
              content: Text('Autorización generada y subida correctamente')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Error al generar/subir: $e')),
        );
      }
    }
  }
}
