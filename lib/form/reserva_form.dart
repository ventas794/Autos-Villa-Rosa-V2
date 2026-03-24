import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../pdf_generators/reserva_pdf_generator.dart';
import 'dart:developer';

String capitalizeEachWord(String text) {
  if (text.isEmpty) return text;
  return text.split(' ').map((word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}

class CapitalizeEachWordFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    String newText = capitalizeEachWord(newValue.text);
    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

class ReservaForm extends StatefulWidget {
  final int cocheId;
  final Map<String, dynamic> cocheData;
  final VoidCallback? onSuccess;

  const ReservaForm({
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
                'No se puede generar la reserva: actualice la ubicación del coche.')),
      );
      return;
    }

    bool shouldProceed = true;
    if (cocheData['pdf_reserva_url'] != null &&
        (cocheData['pdf_reserva_url'] as String).isNotEmpty) {
      shouldProceed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Regenerar reserva'),
              content: const Text(
                  '¿Está seguro que desea regenerar el PDF de Reserva?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Sí, continuar'),
                ),
              ],
            ),
          ) ??
          false;
    }

    if (!shouldProceed || !context.mounted) return;

    await showDialog(
      context: context,
      builder: (_) => ReservaForm(
        cocheId: cocheId,
        cocheData: cocheData,
        onSuccess: refresh,
      ),
    );
  }

  @override
  State<ReservaForm> createState() => _ReservaFormState();
}

class _ReservaFormState extends State<ReservaForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreController;
  late TextEditingController _dniController;
  late TextEditingController _telefonoController;
  late TextEditingController _precioFinalController;
  late TextEditingController _abonoController;
  String? _medioDePagoSeleccionado;
  final List<String> _mediosDePago = ['Transf', 'Efectivo', 'Tarjeta'];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController();
    _dniController = TextEditingController();
    _telefonoController = TextEditingController();
    _precioFinalController = TextEditingController();
    _abonoController = TextEditingController();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('coches')
          .select('nombre, dni, telefono, precio_final, abono, medio_de_pago')
          .eq('id', widget.cocheId)
          .maybeSingle();

      if (data != null && mounted) {
        _nombreController.text = capitalizeEachWord(data['nombre'] ?? '');
        _dniController.text = (data['dni'] ?? '').toUpperCase();
        _telefonoController.text = data['telefono'] ?? '';
        _precioFinalController.text = (data['precio_final'] ?? '').toString();
        _abonoController.text = (data['abono'] ?? '').toString();
        _medioDePagoSeleccionado = data['medio_de_pago'];
      }
    } catch (e) {
      log('Error cargando datos iniciales: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e')),
        );
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
    _precioFinalController.dispose();
    _abonoController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_medioDePagoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione un medio de pago')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final int precioFinal =
          int.tryParse(_precioFinalController.text.trim()) ?? 0;
      final int abono = int.tryParse(_abonoController.text.trim()) ?? 0;

      final updateData = {
        'nombre': capitalizeEachWord(_nombreController.text.trim()),
        'dni': _dniController.text.trim().toUpperCase(),
        'telefono': _telefonoController.text.trim(),
        'precio_final': precioFinal,
        'abono': abono,
        'medio_de_pago': _medioDePagoSeleccionado,
      };

      await Supabase.instance.client
          .from('coches')
          .update(updateData)
          .eq('id', widget.cocheId);

      final coche = await Supabase.instance.client
          .from('coches')
          .select('marca, modelo, matricula')
          .eq('id', widget.cocheId)
          .single();

      final reservaData = {
        ...updateData,
        'marca': coche['marca'] ?? '',
        'modelo': coche['modelo'] ?? '',
        'matricula': coche['matricula'] ?? '',
        'fecha_reserva': DateTime.now().toIso8601String(),
      };

      final pdf = await generateReservaPdf(reservaData: reservaData);
      final bytes = await pdf.save();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final matricula = coche['matricula'] ?? 'sin_matricula';
      final fileName = 'reserva_${matricula}_$timestamp.pdf';

      await Supabase.instance.client.storage
          .from('pdfs')
          .uploadBinary(fileName, bytes);

      final pdfUrl =
          Supabase.instance.client.storage.from('pdfs').getPublicUrl(fileName);

      await Supabase.instance.client.from('coches').update({
        'pdf_reserva_url': pdfUrl,
        'fecha_reserva': reservaData['fecha_reserva'],
        'estado_coche': 'Reservado',
      }).eq('id', widget.cocheId);

      messenger.showSnackBar(
        const SnackBar(content: Text('Reserva y PDF generados exitosamente')),
      );

      widget.onSuccess?.call();
      navigator.pop();
    } catch (e) {
      log('Error en submit reserva: $e');
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context);
      },
      child: AlertDialog(
        backgroundColor: Colors.white,
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        title: const Text(
          'Formulario de Reserva',
          style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 320,
            maxWidth: 360, // ← un poco más flexible
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
                    inputFormatters: [CapitalizeEachWordFormatter()],
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
                    controller: _precioFinalController,
                    decoration:
                        const InputDecoration(labelText: 'Precio Final (€)'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if (v?.trim().isEmpty ?? true) {
                        return 'Ingrese el precio final';
                      }
                      if (int.tryParse(v!) == null) {
                        return 'Número válido';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 8),

                  TextFormField(
                    controller: _abonoController,
                    decoration: const InputDecoration(labelText: 'Abono (€)'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if (v?.trim().isEmpty ?? true) {
                        return 'Ingrese el abono';
                      }
                      if (int.tryParse(v!) == null) {
                        return 'Número válido';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Medio de pago',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),

                  const SizedBox(height: 4),

                  // ── Versión corregida: más compacta y sin overflow ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: _mediosDePago.map((medio) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: _medioDePagoSeleccionado == medio,
                            onChanged: (bool? value) {
                              setState(() {
                                _medioDePagoSeleccionado =
                                    value == true ? medio : null;
                              });
                            },
                            visualDensity: const VisualDensity(
                              horizontal: -4,
                              vertical: -4,
                            ),
                          ),
                          Text(
                            medio,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 8),

                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Center(child: CircularProgressIndicator()),
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
