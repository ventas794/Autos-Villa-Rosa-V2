// lib/pdf_generators/speech_pdf_generator.dart
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';

Future<Uint8List> generateSpeechPdf({
  required String marca,
  required String modelo,
  required String precio,
  required String matricula,
  required String fechaMatriculacion,
  required String km,
  required String bastidor,
  required String tipoCombustible,
  required String cc,
  required String cv,
  required String transmision,
  String? fechaItv,
  List<String> caracteristicasAdicionales = const [],
  String? parrafoIA,
}) async {
  final pdf = pw.Document();

  pw.Font font;
  try {
    final fontData =
        await rootBundle.load('assets/fonts/LiberationSans-Regular.ttf');
    font = pw.Font.ttf(fontData);
  } catch (e) {
    font = pw.Font.times();
  }

  String euro = '€';

  String formatFecha(String fecha) {
    if (fecha.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(fecha);
      final meses = [
        'enero',
        'febrero',
        'marzo',
        'abril',
        'mayo',
        'junio',
        'julio',
        'agosto',
        'septiembre',
        'octubre',
        'noviembre',
        'diciembre'
      ];
      return 'del ${date.day} de ${meses[date.month - 1]} del ${date.year}';
    } catch (_) {
      return fecha;
    }
  }

  final fechaMat = formatFecha(fechaMatriculacion);

  String? itvStr;
  if (fechaItv != null && fechaItv.isNotEmpty) {
    try {
      final itvDate = DateTime.parse(fechaItv);
      final now = DateTime.now();
      if (itvDate.isAfter(now)) {
        itvStr = DateFormat('dd/MM/yyyy').format(itvDate);
      }
    } catch (_) {}
  }

  String caracteristicas = caracteristicasAdicionales.isNotEmpty
      ? '${caracteristicasAdicionales.join(', ')}, '
      : '';

  final precioText = '$marca $modelo. $precio $euro';
  final estadoText = itvStr != null
      ? 'Muy buen estado general. Fecha ITV $itvStr.'
      : 'Muy buen estado general.';

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.only(
        top: 25 * PdfPageFormat.mm,
        bottom: 25 * PdfPageFormat.mm,
        left: 30 * PdfPageFormat.mm,
        right: 30 * PdfPageFormat.mm,
      ),
      build: (pw.Context context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Paragraph(
            text:
                '$precioText\n$estadoText\nMatrícula: $matricula, $fechaMat, $km km.\n'
                'N° bastidor: $bastidor.',
            style: pw.TextStyle(fontSize: 12, font: font, lineSpacing: 2),
          ),
          pw.Paragraph(
            text:
                'Motor $tipoCombustible de $cc CC, $cv CV. Cambio $transmision, '
                '${caracteristicas}retrovisores y elevalunas eléctricos, ABS, ESP, etc.',
            style: pw.TextStyle(fontSize: 12, font: font, lineSpacing: 2),
          ),
          if (parrafoIA != null && parrafoIA.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Paragraph(
              text: parrafoIA,
              style: pw.TextStyle(fontSize: 12, font: font, lineSpacing: 2),
            ),
            pw.SizedBox(height: 8),
          ],
          pw.Paragraph(
            text:
                'IMPRESCINDIBLE CITA PREVIA. Atendemos de lunes a viernes de 9:30 a 20:00 hrs, sábados de 10:00 a 20:00 hrs, y domingos de 10:00 a 14:00 hrs, en Málaga Capital, próximo a Leroy Merlín. Precio de contado con transferencia incluida. Puedes reservar y pagar con tarjeta de crédito. \n\n'
                'We speak English. Send us a message and we will call in your language. Este anuncio no es vinculante, puede contener errores, se muestra a título informativo y no contractual. \n\n'
                'Ver más coches en venta visitando www.autosvillarosa.com gran variedad de vehículos a excelentes precios en Málaga. Contacto: 645349995 - 635314627 ',
            style: pw.TextStyle(
                fontSize: 12,
                font: font,
                lineSpacing: 2), // ← Cambiado a 12 + lineSpacing
          ),
        ],
      ),
    ),
  );

  return pdf.save();
}
