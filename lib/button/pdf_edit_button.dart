import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Directory, Platform;
import 'package:open_file/open_file.dart';
import 'package:http/http.dart' as http;
import 'package:universal_html/html.dart' as html;
import 'package:intl/intl.dart';
import '../handler/autorizacion_handler.dart';
import '../handler/speech_handler.dart';
import '../form/reserva_form.dart';
import '../form/venta_form.dart';

class PdfEditButton extends StatefulWidget {
  final Map<String, dynamic> cocheData;
  const PdfEditButton({
    super.key,
    required this.cocheData,
  });

  @override
  State<PdfEditButton> createState() => _PdfEditButtonState();
}

class _PdfEditButtonState extends State<PdfEditButton> {
  late Map<String, dynamic> _coche;

  @override
  void initState() {
    super.initState();
    _coche = Map<String, dynamic>.from(widget.cocheData);
  }

  Future<void> _refreshData() async {
    try {
      final updated = await Supabase.instance.client
          .from('coches')
          .select()
          .eq('id', _coche['id'])
          .single();
      if (mounted) setState(() => _coche = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al refrescar: $e')),
        );
      }
    }
  }

  String _getSubtitleAutorizacion() {
    final transporte = _coche['transporte']?.toString().trim() ?? '';
    return transporte.isNotEmpty ? 'Solicitado a $transporte' : 'Por solicitar';
  }

  String _getSubtitleSpeech() {
    final url = _coche['pdf_speech_url']?.toString() ?? '';
    if (url.isEmpty) return 'Pendiente';
    return 'Speech creado';
  }

  String _getSubtitleReserva() {
    final url = _coche['pdf_reserva_url']?.toString() ?? '';
    if (url.isEmpty) return 'Pendiente';
    final fecha = _coche['fecha_reserva']?.toString();
    if (fecha != null && fecha.isNotEmpty) {
      try {
        final date = DateTime.parse(fecha);
        return 'Reservado el ${DateFormat('dd/MM/yyyy HH:mm').format(date)}';
      } catch (_) {}
    }
    return 'Reservado';
  }

  String _getSubtitleVenta() {
    final url = _coche['pdf_venta_url']?.toString() ?? '';
    if (url.isEmpty) return 'Pendiente';
    final fecha = _coche['fecha_venta']?.toString();
    if (fecha != null && fecha.isNotEmpty) {
      try {
        final date = DateTime.parse(fecha);
        return 'Vendido el ${DateFormat('dd/MM/yyyy HH:mm').format(date)}';
      } catch (_) {}
    }
    return 'Vendido';
  }

  Future<void> _openPdf(String url) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final pdfUrl =
        url.endsWith('.pdf') ? '$url?t=$timestamp' : '$url.pdf?t=$timestamp';

    if (kIsWeb) {
      final viewUri = Uri.parse(pdfUrl);
      if (await canLaunchUrl(viewUri)) {
        await launchUrl(viewUri,
            mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir el PDF')));
      }
    } else {
      try {
        final dio = Dio();
        final tempDir = await getTemporaryDirectory();
        final tempPath = '${tempDir.path}/temp_pdf_$timestamp.pdf';
        await dio.download(pdfUrl, tempPath);
        final result = await OpenFile.open(tempPath);
        if (result.type != ResultType.done && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('No se pudo abrir: ${result.message}')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error al abrir PDF: $e')));
        }
      }
    }
  }

  Future<void> _downloadPdf(String url) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final matricula = _coche['matricula']?.toString() ?? 'vehiculo';
      final fileName = 'documento_${matricula}_$timestamp.pdf';

      if (kIsWeb) {
        String pdfUrl = url;
        if (!pdfUrl.contains('?')) {
          pdfUrl += '?t=$timestamp';
        } else {
          pdfUrl += '&t=$timestamp';
        }
        final response = await http.get(Uri.parse(pdfUrl));
        if (response.statusCode != 200) {
          throw Exception('Error HTTP: ${response.statusCode}');
        }
        final bytes = response.bodyBytes;
        final blob = html.Blob([bytes], 'application/pdf');
        final blobUrl = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: blobUrl)
          ..setAttribute('download', fileName)
          ..style.display = 'none';
        html.document.body?.append(anchor);
        anchor.click();
        anchor.remove();
        html.Url.revokeObjectUrl(blobUrl);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Descarga iniciada — revisa tu carpeta de descargas'),
                duration: Duration(seconds: 5)),
          );
        }
      } else {
        final dio = Dio();
        Directory? dir;
        if (Platform.isAndroid) {
          dir = Directory('/storage/emulated/0/Download');
          if (!await dir.exists()) dir = await getExternalStorageDirectory();
        } else {
          dir = await getApplicationDocumentsDirectory();
        }
        final savePath = '${dir!.path}/$fileName';
        await dio.download(url, savePath);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('PDF guardado en Descargas'),
                duration: const Duration(seconds: 4)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al descargar: $e')));
      }
    }
  }

  Future<void> _eliminarReserva() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar reserva'),
        content: const Text(
            '¿Está seguro? Se eliminará el contrato y todos los datos asociados.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await Supabase.instance.client.from('coches').update({
        'pdf_reserva_url': null,
        'fecha_reserva': null,
        'nombre': null,
        'dni': null,
        'telefono': null,
        'precio_final': null,
        'abono': null,
        'medio_de_pago': null,
        'estado_coche': 'Disponible',
      }).eq('id', _coche['id']);

      if (mounted) {
        setState(() {
          _coche['pdf_reserva_url'] = null;
          _coche['fecha_reserva'] = null;
          _coche['nombre'] = null;
          _coche['dni'] = null;
          _coche['telefono'] = null;
          _coche['precio_final'] = null;
          _coche['abono'] = null;
          _coche['medio_de_pago'] = null;
          _coche['estado_coche'] = 'Disponible';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Contrato de reserva y datos asociados eliminados correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar reserva: $e')),
        );
      }
    }
  }

  Future<void> _eliminarVenta() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar venta'),
        content: const Text(
            '¿Está seguro? Se eliminará el contrato y todos los datos asociados.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await Supabase.instance.client.from('coches').update({
        'pdf_venta_url': null,
        'fecha_venta': null,
        'pdf_reserva_url': null, // ← AÑADIDO: limpia también reserva
        'fecha_reserva': null, // ← AÑADIDO: limpia también reserva
        'nombre': null,
        'dni': null,
        'telefono': null,
        'direccion': null,
        'ciudad': null,
        'cp': null,
        'provincia': null,
        'correo': null,
        'precio_final': null,
        'garantia': null,
        'abono': null,
        'medio_de_pago': null,
        'estado_coche': 'Disponible',
      }).eq('id', _coche['id']);

      if (mounted) {
        setState(() {
          _coche['pdf_venta_url'] = null;
          _coche['fecha_venta'] = null;
          _coche['pdf_reserva_url'] = null; // ← AÑADIDO
          _coche['fecha_reserva'] = null; // ← AÑADIDO
          _coche['nombre'] = null;
          _coche['dni'] = null;
          _coche['telefono'] = null;
          _coche['direccion'] = null;
          _coche['ciudad'] = null;
          _coche['cp'] = null;
          _coche['provincia'] = null;
          _coche['correo'] = null;
          _coche['precio_final'] = null;
          _coche['garantia'] = null;
          _coche['abono'] = null;
          _coche['medio_de_pago'] = null;
          _coche['estado_coche'] = 'Disponible';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Contrato de venta y datos asociados eliminados correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar venta: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const double dialogWidth = 380;

    final hasAutorizacion = _coche['pdf_autorizacion_url'] != null &&
        (_coche['pdf_autorizacion_url'] as String).isNotEmpty &&
        (_coche['pdf_autorizacion_url'] as String).startsWith('http');

    final hasSpeech = _coche['pdf_speech_url'] != null &&
        (_coche['pdf_speech_url'] as String).isNotEmpty &&
        (_coche['pdf_speech_url'] as String).startsWith('http');

    final hasReserva = _coche['pdf_reserva_url'] != null &&
        (_coche['pdf_reserva_url'] as String).isNotEmpty &&
        (_coche['pdf_reserva_url'] as String).startsWith('http');

    final hasVenta = _coche['pdf_venta_url'] != null &&
        (_coche['pdf_venta_url'] as String).isNotEmpty &&
        (_coche['pdf_venta_url'] as String).startsWith('http');

    final isVendido = _coche['estado_coche'] == 'Vendido';

    return AlertDialog(
      backgroundColor: Colors.white,
      title: const Text('Documentos PDF'),
      contentPadding: EdgeInsets.zero,
      content: ConstrainedBox(
        constraints: const BoxConstraints(
            minWidth: dialogWidth, maxWidth: dialogWidth, maxHeight: 520),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Autorización
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side:
                          const BorderSide(color: Color(0xFF0053A0), width: 1)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text('Autorización',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87)),
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                        hasAutorizacion
                                            ? Icons.edit
                                            : Icons.add_circle,
                                        color: hasAutorizacion
                                            ? Colors.orange
                                            : Colors.purple,
                                        size: 22),
                                    tooltip: hasAutorizacion
                                        ? 'Regenerar Autorización'
                                        : 'Generar Autorización',
                                    onPressed: () {
                                      AutorizacionHandler.handleGenerate(
                                        context: context,
                                        cocheData: _coche,
                                        cocheId: _coche['id'] as int,
                                        initialTransporte:
                                            _coche['transporte']?.toString() ??
                                                '',
                                        refresh: _refreshData,
                                      );
                                    },
                                  ),
                                  if (hasAutorizacion) ...[
                                    IconButton(
                                        icon: const Icon(Icons.visibility,
                                            color: Colors.blue, size: 20),
                                        tooltip: 'Ver PDF',
                                        onPressed: () => _openPdf(
                                            _coche['pdf_autorizacion_url']
                                                as String)),
                                    IconButton(
                                        icon: const Icon(Icons.download,
                                            color: Colors.green, size: 20),
                                        tooltip: 'Descargar PDF',
                                        onPressed: () => _downloadPdf(
                                            _coche['pdf_autorizacion_url']
                                                as String)),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(_getSubtitleAutorizacion(),
                            style: const TextStyle(
                                fontSize: 14, color: Colors.black54)),
                      ],
                    ),
                  ),
                ),

                // Speech
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side:
                          const BorderSide(color: Color(0xFF0053A0), width: 1)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text('Speech',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87)),
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                        hasSpeech
                                            ? Icons.edit
                                            : Icons.add_circle,
                                        color: hasSpeech
                                            ? Colors.orange
                                            : Colors.purple,
                                        size: 22),
                                    tooltip: hasSpeech
                                        ? 'Regenerar Speech'
                                        : 'Generar Speech',
                                    onPressed: () {
                                      SpeechHandler.handleGenerate(
                                        context: context,
                                        cocheData: _coche,
                                        cocheId: _coche['id'] as int,
                                        refresh: _refreshData,
                                      );
                                    },
                                  ),
                                  if (hasSpeech) ...[
                                    IconButton(
                                        icon: const Icon(Icons.visibility,
                                            color: Colors.blue, size: 20),
                                        tooltip: 'Ver PDF',
                                        onPressed: () => _openPdf(
                                            _coche['pdf_speech_url']
                                                as String)),
                                    IconButton(
                                        icon: const Icon(Icons.download,
                                            color: Colors.green, size: 20),
                                        tooltip: 'Descargar PDF',
                                        onPressed: () => _downloadPdf(
                                            _coche['pdf_speech_url']
                                                as String)),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(_getSubtitleSpeech(),
                            style: const TextStyle(
                                fontSize: 14, color: Colors.black54)),
                      ],
                    ),
                  ),
                ),

                // Reserva
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side:
                          const BorderSide(color: Color(0xFF0053A0), width: 1)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text('Reserva',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87)),
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (!hasReserva)
                                    IconButton(
                                      icon: Icon(
                                        Icons.add_circle,
                                        color: isVendido
                                            ? Colors.grey
                                            : Colors.purple,
                                        size: 22,
                                      ),
                                      tooltip: isVendido
                                          ? 'No disponible (coche vendido)'
                                          : 'Generar Reserva',
                                      onPressed: isVendido
                                          ? null
                                          : () {
                                              ReservaForm.show(
                                                context: context,
                                                cocheData: _coche,
                                                cocheId: _coche['id'] as int,
                                                refresh: _refreshData,
                                              );
                                            },
                                    ),
                                  if (hasReserva)
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_forever,
                                        color: isVendido
                                            ? Colors.grey
                                            : Colors.red,
                                        size: 22,
                                      ),
                                      tooltip: isVendido
                                          ? 'No disponible (coche vendido)'
                                          : 'Eliminar Reserva (y datos asociados)',
                                      onPressed:
                                          isVendido ? null : _eliminarReserva,
                                    ),
                                  if (hasReserva) ...[
                                    IconButton(
                                      icon: const Icon(Icons.visibility,
                                          color: Colors.blue, size: 20),
                                      tooltip: 'Ver PDF',
                                      onPressed: () => _openPdf(
                                          _coche['pdf_reserva_url'] as String),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.download,
                                          color: Colors.green, size: 20),
                                      tooltip: 'Descargar PDF',
                                      onPressed: () => _downloadPdf(
                                          _coche['pdf_reserva_url'] as String),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(_getSubtitleReserva(),
                            style: const TextStyle(
                                fontSize: 14, color: Colors.black54)),
                      ],
                    ),
                  ),
                ),

                // Venta
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side:
                          const BorderSide(color: Color(0xFF0053A0), width: 1)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text('Venta',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87)),
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (!hasVenta)
                                    IconButton(
                                      icon: Icon(
                                        Icons.add_circle,
                                        color: isVendido
                                            ? Colors.grey
                                            : Colors.purple,
                                        size: 22,
                                      ),
                                      tooltip: isVendido
                                          ? 'No disponible (coche vendido)'
                                          : 'Generar Venta',
                                      onPressed: isVendido
                                          ? null
                                          : () {
                                              VentaForm.show(
                                                context: context,
                                                cocheData: _coche,
                                                cocheId: _coche['id'] as int,
                                                refresh: _refreshData,
                                              );
                                            },
                                    ),
                                  if (hasVenta)
                                    IconButton(
                                      icon: const Icon(Icons.delete_forever,
                                          color: Colors.red, size: 22),
                                      tooltip:
                                          'Eliminar Venta (y datos asociados)',
                                      onPressed: _eliminarVenta,
                                    ),
                                  if (hasVenta) ...[
                                    IconButton(
                                      icon: const Icon(Icons.visibility,
                                          color: Colors.blue, size: 20),
                                      tooltip: 'Ver PDF',
                                      onPressed: () => _openPdf(
                                          _coche['pdf_venta_url'] as String),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.download,
                                          color: Colors.green, size: 20),
                                      tooltip: 'Descargar PDF',
                                      onPressed: () => _downloadPdf(
                                          _coche['pdf_venta_url'] as String),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(_getSubtitleVenta(),
                            style: const TextStyle(
                                fontSize: 14, color: Colors.black54)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar')),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
