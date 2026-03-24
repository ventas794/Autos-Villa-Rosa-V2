// lib/pdf_generators/autorizacion_pdf.dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import 'dart:typed_data';

Future<Uint8List> generateAutorizacionPdf({
  required String marca,
  required String modelo,
  required String matricula,
  required String transporte,
  required String cif,
}) async {
  final pdf = pw.Document();

  // Datos predefinidos de transportes (igual que en referencia)
  final transportesData = {
    'Auto1': {'empresa': 'NO APLICA', 'cif': 'NO APLICA'},
    'Manuel': {'empresa': 'Manuel Campos Fitz', 'cif': '28648766N'},
    'Orencio': {
      'empresa': 'Transporte de vehículos Orencio SL',
      'cif': 'B73301004'
    },
    'Guadalix': {'empresa': 'Autologísca Guadalix SL', 'cif': 'B84913763'},
  };

  final empresa = transportesData[transporte]?['empresa'] ??
      (transporte.isNotEmpty ? transporte : 'No especificado');
  final cifFinal = transportesData[transporte]?['cif'] ??
      (cif.isNotEmpty ? cif : 'No especificado');

  // Carga logo y firma (ajusta los paths a tus assets)
  final logoBytes = await rootBundle.load('assets/images/logo_auto1.png');
  final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

  final signatureBytes = await rootBundle.load('assets/images/firma.png');
  final signatureImage = pw.MemoryImage(signatureBytes.buffer.asUint8List());

  final boldStyle = pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14);
  final normalStyle = pw.TextStyle(fontSize: 12);

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
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Comprador / Company Name: ', style: normalStyle),
                  pw.Text('Avenida Alcorta SL', style: boldStyle),
                ],
              ),
              pw.Image(logoImage,
                  width: 144, height: 36, fit: pw.BoxFit.contain),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text('Sr. D. / Company Representative: ', style: normalStyle),
          pw.Text('Alejandro F. Gallego Montero', style: boldStyle),
          pw.SizedBox(height: 10),
          pw.Text('Con DNI / With ID / Passport number: ', style: normalStyle),
          pw.Text('50335399Z', style: boldStyle),
          pw.SizedBox(height: 10),
          pw.Text('Autorizo a la empresa/persona: ', style: normalStyle),
          pw.Text(empresa, style: boldStyle),
          pw.SizedBox(height: 10),
          pw.Text('Con DNI-CIF: ', style: normalStyle),
          pw.Text(cifFinal, style: boldStyle),
          pw.SizedBox(height: 10),
          pw.Text(
              'Para que efectúe en mi nombre la recogida del vehículo matrícula',
              style: normalStyle),
          pw.SizedBox(height: 10),
          pw.Divider(),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                  child: pw.Text('$marca $modelo',
                      style: boldStyle, textAlign: pw.TextAlign.center)),
              pw.SizedBox(width: 20),
              pw.Expanded(
                  child: pw.Text(matricula,
                      style: boldStyle, textAlign: pw.TextAlign.center)),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text('Firma / Sello del comprador', style: normalStyle),
          pw.Align(
              alignment: pw.Alignment.center,
              child: pw.Image(signatureImage, width: 200, height: 100)),
          pw.SizedBox(height: 10),
          pw.Text('A este impreso se adjuntará DNI de la persona autorizante.',
              style: normalStyle),
        ],
      ),
    ),
  );

  return pdf.save();
}
