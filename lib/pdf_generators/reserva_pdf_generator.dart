// lib/pdf_generators/reserva_pdf_generator.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<pw.Document> generateReservaPdf({
  required Map<String, dynamic> reservaData,
}) async {
  // Inicializar formato de fecha en español
  await initializeDateFormatting('es_ES', null);

  final pdf = pw.Document();

  // Cargar fuentes con validación
  pw.Font regularFont;
  try {
    final fontData =
        await rootBundle.load('assets/fonts/LiberationSans-Regular.ttf');
    if (fontData.lengthInBytes == 0) throw Exception('Fuente Regular vacía');
    regularFont = pw.Font.ttf(fontData);
  } catch (e) {
    debugPrint('Error cargando LiberationSans-Regular: $e → usando Times');
    regularFont = pw.Font.times();
  }

  pw.Font boldFont;
  try {
    final boldFontData =
        await rootBundle.load('assets/fonts/LiberationSans-Bold.ttf');
    if (boldFontData.lengthInBytes == 0) throw Exception('Fuente Bold vacía');
    boldFont = pw.Font.ttf(boldFontData);
  } catch (e) {
    debugPrint('Error cargando LiberationSans-Bold: $e → usando Times Bold');
    boldFont = pw.Font.timesBold();
  }

  // Fallback para símbolo euro si falla el renderizado
  String euroSymbol = '€';
  try {
    final testDoc = pw.Document();
    testDoc.addPage(pw.Page(
        build: (_) => pw.Text('€', style: pw.TextStyle(font: regularFont))));
    await testDoc.save();
  } catch (e) {
    euroSymbol = '\u20AC';
    debugPrint('Fallback euro: $e');
  }

  const String bullet = '\u2022';

  // Extraer datos (con valores por defecto seguros)
  final String nombre = reservaData['nombre']?.toString() ?? 'N/D';
  final String dni = reservaData['dni']?.toString() ?? 'N/D';
  final String telefono = reservaData['telefono']?.toString() ?? 'N/D';
  final String medioPago = reservaData['medio_de_pago']?.toString() ?? 'N/D';
  final String marca = reservaData['marca']?.toString() ?? '';
  final String modelo = reservaData['modelo']?.toString() ?? '';
  final String matricula = reservaData['matricula']?.toString() ?? '';
  final int precioFinal =
      int.tryParse(reservaData['precio_final']?.toString() ?? '0') ?? 0;
  final int abono = int.tryParse(reservaData['abono']?.toString() ?? '0') ?? 0;
  final int saldoPendiente = precioFinal - abono;

  final DateTime fechaReserva = DateTime.parse(
    reservaData['fecha_reserva']?.toString() ??
        DateTime.now().toIso8601String(),
  );
  final DateTime fechaVencimiento = DateTime(
    fechaReserva.year,
    fechaReserva.month + 1,
    fechaReserva.day,
  );

  final DateFormat fechaFmt = DateFormat('dd MMMM yyyy', 'es_ES');
  final DateFormat horaFmt = DateFormat('HH:mm');

  final String fechaReservaTexto = fechaFmt.format(fechaReserva);
  final String horaReservaTexto = horaFmt.format(fechaReserva);
  final String fechaVencimientoTexto = fechaFmt.format(fechaVencimiento);

  // Estilos
  final regularStyle = pw.TextStyle(fontSize: 11, font: regularFont);
  final boldStyle = pw.TextStyle(
      fontSize: 13, fontWeight: pw.FontWeight.bold, font: boldFont);
  final sectionTitleStyle = pw.TextStyle(
      fontSize: 12, fontWeight: pw.FontWeight.bold, font: boldFont);

  // Tema de página con borde
  final pageTheme = pw.PageTheme(
    pageFormat: PdfPageFormat.a4,
    margin: pw.EdgeInsets.only(
      top: 25 * PdfPageFormat.mm,
      bottom: 25 * PdfPageFormat.mm,
      left: 30 * PdfPageFormat.mm,
      right: 30 * PdfPageFormat.mm,
    ),
    buildBackground: (context) => pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1),
      ),
      margin: pw.EdgeInsets.all(-10 * PdfPageFormat.mm),
    ),
  );

  // Función auxiliar para añadir página con pie de página
  void addPage(pw.Widget content) {
    pdf.addPage(
      pw.Page(
        pageTheme: pageTheme,
        build: (context) => pw.Stack(
          children: [
            content,
            pw.Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: pw.Align(
                alignment: pw.Alignment.bottomCenter,
                child: pw.Text(
                  'Página ${context.pageNumber}/${context.pagesCount}',
                  style: pw.TextStyle(fontSize: 10, font: regularFont),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Contenido del PDF (exactamente como en la referencia)
  addPage(
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(
          child: pw.Text(
            'DOCUMENTO DE SEÑAL',
            style: boldStyle,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'En Málaga, a las $horaReservaTexto horas del día $fechaReservaTexto.',
          style: regularStyle,
        ),
        pw.SizedBox(height: 10),
        pw.Text('DE UNA PARTE', style: sectionTitleStyle),
        pw.Text(
          'AVENIDA ALCORTA, S.L., con domicilio en Av. Brisa del mar, N.º 4, casa 33, 29790 Chilches Costa (Málaga), CIF B93299725, en calidad de VENDEDOR.',
          style: regularStyle,
        ),
        pw.SizedBox(height: 10),
        pw.Text('RECIBE', style: sectionTitleStyle),
        pw.Text(
          'De $nombre, con NIF/DNI $dni, teléfono $telefono, en adelante el COMPRADOR, '
          'la cantidad de $abono $euroSymbol en $medioPago, en concepto de reserva y arras penitencial por '
          'la compra del siguiente vehículo:',
          style: regularStyle,
        ),
        pw.SizedBox(height: 10),
        pw.Text('$bullet Marca: $marca', style: regularStyle),
        pw.Text('$bullet Modelo: $modelo', style: regularStyle),
        pw.Text('$bullet Matrícula: $matricula', style: regularStyle),
        pw.Text('$bullet Precio: $precioFinal $euroSymbol',
            style: regularStyle),
        pw.Text('$bullet Saldo pendiente: $saldoPendiente $euroSymbol',
            style: regularStyle),
        pw.SizedBox(height: 10),
        pw.Text(
          'La entrega por el comprador de la cantidad expresada se realiza por voluntad de ambas partes, en el concepto y función de reserva y señal durante un plazo que finalizará el día $fechaVencimientoTexto, por lo que, dentro del plazo expresado, podrá el comprador desistir libremente y separarse del contrato con pérdida de la cantidad entregada en este acto.',
          style: regularStyle,
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'Por su parte, el VENDEDOR no podrá vender el vehículo de referencia a ninguna otra persona, física o jurídica, hasta el vencimiento del presente contrato. Si por alguna razón ajena a la voluntad del VENDEDOR (robo, destrucción, desastre natural, etc.), éste no pudiere entregar el bien reservado, deberá devolver ipso facto al COMPRADOR la cantidad recibida en concepto de reserva y señal.',
          style: regularStyle,
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'Para que el desistimiento por parte del COMPRADOR se tenga por válido bastará con que notifique al VENDEDOR en cualquier forma, considerándose también producido tácitamente por el hecho de no concurrir dentro del plazo convenido a finalizar el proceso de compra.',
          style: regularStyle,
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'En tales supuestos de desistimiento, a partir de la indicada fecha el VENDEDOR podrá disponer libremente del vehículo.',
          style: regularStyle,
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'De mutua conformidad se firman dos ejemplares:',
          style: regularStyle,
        ),
        pw.SizedBox(height: 158), // Espacio para firmas
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
          children: [
            pw.Column(
              children: [
                pw.Text('_______________________', style: regularStyle),
                pw.Text('COMPRADOR', style: regularStyle),
                pw.Text(nombre, style: regularStyle),
                pw.Text(dni, style: regularStyle),
              ],
            ),
            pw.Column(
              children: [
                pw.Text('_______________________', style: regularStyle),
                pw.Text('VENDEDOR', style: regularStyle),
                pw.Text('Avenida Alcorta SL', style: regularStyle),
                pw.Text('CIF: B93299725', style: regularStyle),
              ],
            ),
          ],
        ),
      ],
    ),
  );

  return pdf;
}
