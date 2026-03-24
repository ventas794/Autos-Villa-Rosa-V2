import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../pdf_generators/venta_con_garantia_pdf.dart';
import '../pdf_generators/venta_sin_garantia_pdf.dart';
import 'package:intl/intl.dart';
import 'dart:developer';

String capitalizeWords(String text) {
  if (text.isEmpty) return text;
  return text
      .split(' ')
      .map((word) => word.isNotEmpty
          ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
          : word)
      .join(' ');
}

String capitalizeFirstLetter(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1).toLowerCase();
}

class VentaForm extends StatefulWidget {
  final int cocheId;
  final Map<String, dynamic> cocheData;
  final VoidCallback? onSuccess;

  const VentaForm({
    super.key,
    required this.cocheId,
    required this.cocheData,
    this.onSuccess,
  });

  static Future<void> show({
    required BuildContext context,
    required Map<String, dynamic> cocheData,
    required int cocheId,
    required VoidCallback refresh,
  }) async {
    final estadoCoche = cocheData['estado_coche']?.toString() ?? '';
    if (estadoCoche == 'Vendido') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No se puede generar: el coche ya está vendido.')),
      );
      return;
    }
    if (estadoCoche == 'Por llegar') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'No se puede generar la venta: actualice la ubicación del coche.')),
      );
      return;
    }

    bool shouldProceed = true;
    if (cocheData['pdf_venta_url'] != null &&
        (cocheData['pdf_venta_url'] as String).isNotEmpty) {
      shouldProceed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Regenerar venta'),
              content: const Text(
                  '¿Está seguro que desea regenerar el contrato de venta?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar')),
                ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Sí, continuar')),
              ],
            ),
          ) ??
          false;
    }

    if (!shouldProceed || !context.mounted) return;

    await showDialog(
      context: context,
      builder: (_) => VentaForm(
        cocheId: cocheId,
        cocheData: cocheData,
        onSuccess: refresh,
      ),
    );
  }

  @override
  State<VentaForm> createState() => _VentaFormState();
}

class _VentaFormState extends State<VentaForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreController;
  late TextEditingController _dniController;
  late TextEditingController _telefonoController;
  late TextEditingController _direccionController;
  late TextEditingController _ciudadController;
  late TextEditingController _cpController;
  late TextEditingController _provinciaController;
  late TextEditingController _correoController;
  late TextEditingController _precioFinalController;
  bool? _garantia;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController();
    _dniController = TextEditingController();
    _telefonoController = TextEditingController();
    _direccionController = TextEditingController();
    _ciudadController = TextEditingController();
    _cpController = TextEditingController();
    _provinciaController = TextEditingController();
    _correoController = TextEditingController();
    _precioFinalController = TextEditingController();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('coches')
          .select(
              'nombre, dni, telefono, direccion, ciudad, cp, provincia, correo, precio_final, garantia')
          .eq('id', widget.cocheId)
          .single();

      if (mounted) {
        _nombreController.text = capitalizeWords(data['nombre'] ?? '');
        _dniController.text = (data['dni'] ?? '').toUpperCase();
        _telefonoController.text = data['telefono'] ?? '';
        _direccionController.text = data['direccion'] ?? '';
        _ciudadController.text = data['ciudad'] ?? '';
        _cpController.text = data['cp']?.toString() ?? '';
        _provinciaController.text = data['provincia'] ?? '';
        _correoController.text = data['correo'] ?? '';
        _precioFinalController.text = data['precio_final']?.toString() ?? '';
        _garantia = data['garantia'] == 'Sí'
            ? true
            : data['garantia'] == 'No'
                ? false
                : null;
      }
    } catch (e) {
      log('Error cargando datos venta: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al cargar datos: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _dniController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    _ciudadController.dispose();
    _cpController.dispose();
    _provinciaController.dispose();
    _correoController.dispose();
    _precioFinalController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate() || _garantia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Complete todos los campos y seleccione garantía')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final precioFinal = int.tryParse(_precioFinalController.text.trim()) ?? 0;
      final garantiaStr = _garantia! ? 'Sí' : 'No';
      final fechaVenta = DateTime.now();
      final fechaVentaStr = DateFormat('yyyy-MM-dd').format(fechaVenta);
      final horaVentaStr = DateFormat('HH:mm').format(fechaVenta);

      // 1. Guardar todos los datos del formulario
      final updateData = {
        'nombre': capitalizeWords(_nombreController.text.trim()),
        'dni': _dniController.text.trim().toUpperCase(),
        'telefono': _telefonoController.text.trim(),
        'direccion': capitalizeFirstLetter(_direccionController.text.trim()),
        'ciudad': capitalizeFirstLetter(_ciudadController.text.trim()),
        'cp': int.tryParse(_cpController.text.trim()),
        'provincia': capitalizeFirstLetter(_provinciaController.text.trim()),
        'correo': _correoController.text.trim(),
        'precio_final': precioFinal,
        'garantia': garantiaStr,
      };

      await Supabase.instance.client
          .from('coches')
          .update(updateData)
          .eq('id', widget.cocheId);

      // 2. Leer datos completos y actualizados para generar el PDF
      final cocheData = await Supabase.instance.client.from('coches').select('''
            marca, modelo, matricula, bastidor, fecha_itv, km, fecha_matriculacion,
            nombre, dni, telefono, direccion, cp, ciudad, provincia, correo
          ''').eq('id', widget.cocheId).single();

      Uint8List pdfBytes;

      if (_garantia!) {
        pdfBytes = await generateVentaConGarantiaPdf(
          fechaVenta: fechaVentaStr,
          nombre: cocheData['nombre'] ?? '',
          dni: (cocheData['dni'] ?? '').toUpperCase(),
          direccion: cocheData['direccion'] ?? '',
          cp: cocheData['cp']?.toString() ?? '',
          ciudad: cocheData['ciudad'] ?? '',
          provincia: cocheData['provincia'] ?? '',
          telefono: cocheData['telefono'] ?? '',
          precio: precioFinal,
          marca: cocheData['marca'] ?? '',
          modelo: cocheData['modelo'] ?? '',
          matricula: cocheData['matricula'] ?? '',
          bastidor: cocheData['bastidor'] ?? '',
          fechaItv: cocheData['fecha_itv'] ?? '',
          km: cocheData['km']?.toString() ?? '',
          fechaMatriculacion: cocheData['fecha_matriculacion'] ?? '',
          horaVenta: horaVentaStr,
        );
      } else {
        pdfBytes = await generateVentaSinGarantiaPdf(
          fechaVenta: fechaVentaStr,
          nombre: cocheData['nombre'] ?? '',
          dni: (cocheData['dni'] ?? '').toUpperCase(),
          direccion: cocheData['direccion'] ?? '',
          cp: cocheData['cp']?.toString() ?? '',
          ciudad: cocheData['ciudad'] ?? '',
          provincia: cocheData['provincia'] ?? '',
          precio: precioFinal,
          marca: cocheData['marca'] ?? '',
          modelo: cocheData['modelo'] ?? '',
          matricula: cocheData['matricula'] ?? '',
          bastidor: cocheData['bastidor'] ?? '',
          km: cocheData['km']?.toString() ?? '',
          fechaMatriculacion: cocheData['fecha_matriculacion'] ?? '',
          correo: cocheData['correo'] ?? '',
          telefono: cocheData['telefono'] ?? '',
          horaVenta: horaVentaStr,
        );
      }

      // 3. Subir PDF
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final matricula = cocheData['matricula'] ?? 'sin_matricula';
      final fileName = 'venta_${matricula}_$timestamp.pdf';

      await Supabase.instance.client.storage
          .from('pdfs')
          .uploadBinary(fileName, pdfBytes);

      final pdfUrl =
          Supabase.instance.client.storage.from('pdfs').getPublicUrl(fileName);

      // 4. Actualizar URL y estado final
      await Supabase.instance.client.from('coches').update({
        'pdf_venta_url': pdfUrl,
        'estado_coche': 'Vendido',
        'fecha_venta': fechaVenta.toIso8601String(),
      }).eq('id', widget.cocheId);

      messenger.showSnackBar(
          const SnackBar(content: Text('Venta registrada y PDF generado')));
      widget.onSuccess?.call();
      navigator.pop();
    } catch (e) {
      log('Error en venta: $e');
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context);
      },
      child: AlertDialog(
        backgroundColor: Colors.white,
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        title: const Text(
          'Formulario de Venta',
          style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 320,
            maxWidth: 360,
            maxHeight: 620,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nombreController,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]'))
                    ],
                    validator: (v) =>
                        v?.trim().isEmpty ?? true ? 'Ingrese el nombre' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _dniController,
                    decoration: const InputDecoration(labelText: 'DNI'),
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) =>
                        v?.trim().isEmpty ?? true ? 'Ingrese el DNI' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _telefonoController,
                    decoration: const InputDecoration(labelText: 'Teléfono'),
                    keyboardType: TextInputType.phone,
                    validator: (v) => v?.trim().isEmpty ?? true
                        ? 'Ingrese el teléfono'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _direccionController,
                    decoration: const InputDecoration(labelText: 'Dirección'),
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) => v?.trim().isEmpty ?? true
                        ? 'Ingrese la dirección'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _correoController,
                    decoration: const InputDecoration(labelText: 'Correo'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                        v?.trim().isEmpty ?? true ? 'Ingrese el correo' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _ciudadController,
                    decoration: const InputDecoration(labelText: 'Ciudad'),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        v?.trim().isEmpty ?? true ? 'Ingrese la ciudad' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _cpController,
                    decoration:
                        const InputDecoration(labelText: 'Código Postal'),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        v?.trim().isEmpty ?? true ? 'Ingrese el CP' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _provinciaController,
                    decoration: const InputDecoration(labelText: 'Provincia'),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => v?.trim().isEmpty ?? true
                        ? 'Ingrese la provincia'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _precioFinalController,
                    decoration:
                        const InputDecoration(labelText: 'Precio Final (€)'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v?.trim().isEmpty ?? true) return 'Ingrese el precio';
                      if (int.tryParse(v!) == null) return 'Número válido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        '¿Garantía? ',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: _garantia == true,
                            onChanged: (v) => setState(() => _garantia = true),
                            visualDensity: VisualDensity.compact,
                          ),
                          const Text('Sí', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 16),
                          Checkbox(
                            value: _garantia == false,
                            onChanged: (v) => setState(() => _garantia = false),
                            visualDensity: VisualDensity.compact,
                          ),
                          const Text('No', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: _submitForm,
            child: const Text('Guardar'),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      ),
    );
  }
}
