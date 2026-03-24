// lib/handler/speech_handler.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../pdf_generators/speech_pdf_generator.dart';
import '../services/groq_service.dart';

class SpeechHandler {
  static Future<void> handleGenerate({
    required BuildContext context,
    required Map<String, dynamic> cocheData,
    required int cocheId,
    required VoidCallback refresh,
  }) async {
    // 1. Confirmar regeneración si ya existe PDF
    if (cocheData['pdf_speech_url'] != null &&
        (cocheData['pdf_speech_url'] as String).isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text("Regenerar Speech"),
          content: const Text("¿Desea regenerar el PDF del anuncio (speech)?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Cancelar"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text("Sí, regenerar",
                  style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (!context.mounted) return;
      if (confirmed != true) return;
    }

    // Lista de características comunes
    final List<String> caracteristicasComunes = [
      'Climatizador automático',
      'Aire acondicionado',
      'Llantas de aleación',
      'Sensores de aparcamiento',
      'Cámara de aparcamiento',
      'Navegador GPS',
      'Asientos calefactables',
      'Asientos eléctricos',
      'Asientos abatibles',
      'Acabados en madera',
      'Techo solar',
      'Luces Xenon',
      'Control de crucero',
      'Volante multifunción',
      'Pantalla central',
      'Start & Stop',
      'Bola de remolque',
      '7 plazas',
      'Descapotable',
      'Tracción total',
      'Android Auto / Apple CarPlay',
    ];

    List<String> seleccionadas = [];

    // 2. Diálogo SOLO con checkboxes
    final bool? proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Características destacadas'),
              content: SizedBox(
                width: double.maxFinite,
                height: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selecciona las características que aplican al vehículo:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      ...caracteristicasComunes.map((carac) {
                        return CheckboxListTile(
                          title: Text(
                            carac,
                            style: const TextStyle(fontSize: 14),
                          ),
                          value: seleccionadas.contains(carac),
                          onChanged: (bool? value) {
                            setStateDialog(() {
                              if (value == true) {
                                seleccionadas.add(carac);
                              } else {
                                seleccionadas.remove(carac);
                              }
                            });
                          },
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 0),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Generar PDF'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!context.mounted) return;
    if (proceed != true) return;

    // 3. Características = solo las seleccionadas
    List<String> todasCaracteristicas = List.from(seleccionadas);

    // 4. Generar párrafo con IA
    String parrafoIA = '';
    try {
      parrafoIA = await GroqService.generarParrafoIA({
        ...cocheData,
        'caracteristicas': todasCaracteristicas,
      });
    } catch (e) {
      debugPrint('Error generando párrafo IA: $e');
      parrafoIA = GroqService.fallbackParrafo();
    }

    // 5. Generar y subir PDF
    try {
      final pdfBytes = await generateSpeechPdf(
        marca: cocheData['marca']?.toString() ?? '',
        modelo: cocheData['modelo']?.toString() ?? '',
        precio: cocheData['precio']?.toString() ?? '0',
        matricula: cocheData['matricula']?.toString() ?? '',
        fechaMatriculacion: cocheData['fecha_matriculacion']?.toString() ?? '',
        km: cocheData['km']?.toString() ?? '0',
        bastidor: cocheData['bastidor']?.toString() ?? '',
        tipoCombustible: cocheData['combustible']?.toString() ?? '',
        cc: cocheData['cc']?.toString() ?? '',
        cv: cocheData['cv']?.toString() ?? '',
        transmision: cocheData['transmision']?.toString() ?? '',
        fechaItv: cocheData['fecha_itv']?.toString(),
        caracteristicasAdicionales: todasCaracteristicas,
        parrafoIA: parrafoIA,
      );

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final matricula = cocheData['matricula']?.toString() ?? 'sin_matricula';
      final fileName = 'speech_${matricula}_$timestamp.pdf';

      await Supabase.instance.client.storage
          .from('pdfs')
          .uploadBinary(fileName, pdfBytes);

      final pdfUrl =
          Supabase.instance.client.storage.from('pdfs').getPublicUrl(fileName);

      await Supabase.instance.client.from('coches').update({
        'pdf_speech_url': pdfUrl,
      }).eq('id', cocheId);

      refresh();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Speech (anuncio) generado correctamente'),
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al generar el speech: $e')),
      );
    }
  }
}
