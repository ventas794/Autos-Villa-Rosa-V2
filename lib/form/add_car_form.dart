import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddCarForm extends StatefulWidget {
  const AddCarForm({super.key});

  @override
  State<AddCarForm> createState() => _AddCarFormState();
}

class _AddCarFormState extends State<AddCarForm> {
  final _formKey = GlobalKey<FormState>();
  final _fechaAltaController = TextEditingController();
  final _fechaMatriculacionController = TextEditingController();
  final _matriculaController = TextEditingController();
  final _marcaController = TextEditingController();
  final _modeloController = TextEditingController();
  final _bastidorController = TextEditingController();
  final _cvController = TextEditingController();
  final _ccController = TextEditingController();
  final _kmController = TextEditingController();
  final _precioController = TextEditingController();
  final _fechaItvController = TextEditingController();

  String? _transmision;
  String? _combustible;

  bool _isLoading = false;
  String _statusMessage = '';

  // Para mostrar errores en transmisión y combustible
  bool _transmisionError = false;
  bool _combustibleError = false;

  static const Color verdeSeleccionado = Color.fromARGB(255, 0, 114, 15);
  static const double fieldHeight = 34.0;
  static const double spacingHorizontal = 12.0;
  static const double sectionSpacing = 2.0;
  static const double textFieldSpacing = 4.0;
  static const double buttonRadius = 8.0;

  String? _requiredValidator(String? value) {
    return (value?.trim().isEmpty ?? true) ? 'Requerido' : null;
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime(2030),
    );
    if (picked != null && mounted) {
      controller.text = DateFormat('dd/MM/yyyy').format(picked);
    }
  }

  String _toIsoDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateFormat('dd/MM/yyyy').parse(dateStr);
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (_) {
      return '';
    }
  }

  Widget _dateField(TextEditingController controller, String label) {
    return SizedBox(
      height: fieldHeight,
      child: TextFormField(
        controller: controller,
        readOnly: true,
        onTap: () => _pickDate(controller),
        decoration: InputDecoration(
          labelText: label,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          isDense: true,
        ),
        style: const TextStyle(fontSize: 14),
        validator: _requiredValidator,
      ),
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label, {
    String? suffixText,
  }) {
    return SizedBox(
      height: fieldHeight,
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffixText,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          isDense: true,
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(fontSize: 14),
        validator: _requiredValidator,
      ),
    );
  }

  void _resetForm() {
    _fechaAltaController.clear();
    _fechaMatriculacionController.clear();
    _matriculaController.clear();
    _marcaController.clear();
    _modeloController.clear();
    _bastidorController.clear();
    _cvController.clear();
    _ccController.clear();
    _kmController.clear();
    _precioController.clear();
    _fechaItvController.clear();

    setState(() {
      _transmision = null;
      _combustible = null;
      _transmisionError = false;
      _combustibleError = false;
    });

    _formKey.currentState?.reset();
  }

  Future<void> _guardarCoche() async {
    setState(() {
      _transmisionError = _transmision == null;
      _combustibleError = _combustible == null;
    });

    if (!_formKey.currentState!.validate() ||
        _transmision == null ||
        _combustible == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      await Supabase.instance.client.from('coches').insert({
        'fecha_alta': _toIsoDate(_fechaAltaController.text),
        'fecha_matriculacion': _toIsoDate(_fechaMatriculacionController.text),
        'matricula': _matriculaController.text.trim().toUpperCase(),
        'marca': _marcaController.text.trim(),
        'modelo': _modeloController.text.trim(),
        'bastidor': _bastidorController.text.trim().toUpperCase(),
        'cv': int.tryParse(_cvController.text.trim()),
        'cc': int.tryParse(_ccController.text.trim()),
        'km': int.tryParse(_kmController.text.trim()),
        'precio': int.tryParse(_precioController.text.trim()),
        'transmision': _transmision,
        'combustible': _combustible,
        'fecha_itv': _toIsoDate(_fechaItvController.text),
        'fecha_creacion': DateTime.now().toIso8601String(),
      }).select();

      setState(() {
        _statusMessage = '¡Coche agregado con éxito!';
      });

      _resetForm();

      await Future.delayed(const Duration(milliseconds: 1400));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _statusMessage = 'Error al guardar: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _fechaAltaController.dispose();
    _fechaMatriculacionController.dispose();
    _matriculaController.dispose();
    _marcaController.dispose();
    _modeloController.dispose();
    _bastidorController.dispose();
    _cvController.dispose();
    _ccController.dispose();
    _kmController.dispose();
    _precioController.dispose();
    _fechaItvController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      titlePadding: EdgeInsets.zero,
      title: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        child: Text(
          'Nuevo Vehículo',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
      contentPadding: EdgeInsets.zero,
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 324),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dateField(_fechaAltaController, 'Fecha Alta'),
                  const SizedBox(height: textFieldSpacing),
                  _dateField(
                      _fechaMatriculacionController, 'Fecha Matriculación'),
                  const SizedBox(height: textFieldSpacing),

                  // Matrícula
                  SizedBox(
                    height: fieldHeight,
                    child: TextFormField(
                      controller: _matriculaController,
                      decoration: InputDecoration(
                        labelText: 'Matrícula',
                        hintText: 'Ej: 1234ABC',
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        isDense: true,
                      ),
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]'))
                      ],
                      style: const TextStyle(fontSize: 14),
                      validator: _requiredValidator,
                    ),
                  ),
                  const SizedBox(height: textFieldSpacing),

                  // Marca
                  SizedBox(
                    height: fieldHeight,
                    child: TextFormField(
                      controller: _marcaController,
                      decoration: InputDecoration(
                        labelText: 'Marca',
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        isDense: true,
                      ),
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(fontSize: 14),
                      validator: _requiredValidator,
                    ),
                  ),
                  const SizedBox(height: textFieldSpacing),

                  // Modelo
                  SizedBox(
                    height: fieldHeight,
                    child: TextFormField(
                      controller: _modeloController,
                      decoration: InputDecoration(
                        labelText: 'Modelo',
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        isDense: true,
                      ),
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(fontSize: 14),
                      validator: _requiredValidator,
                    ),
                  ),
                  const SizedBox(height: textFieldSpacing),

                  // Bastidor
                  SizedBox(
                    height: fieldHeight,
                    child: TextFormField(
                      controller: _bastidorController,
                      decoration: InputDecoration(
                        labelText: 'Bastidor (VIN)',
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        isDense: true,
                      ),
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(fontSize: 14),
                      validator: _requiredValidator,
                    ),
                  ),
                  const SizedBox(height: textFieldSpacing),

                  _numberField(_cvController, 'CV'),
                  const SizedBox(height: textFieldSpacing),
                  _numberField(_ccController, 'CC'),
                  const SizedBox(height: textFieldSpacing),
                  _numberField(_kmController, 'Kilómetros'),
                  const SizedBox(height: textFieldSpacing),
                  _numberField(_precioController, 'Precio', suffixText: '(€)'),
                  const SizedBox(height: textFieldSpacing),
                  _dateField(_fechaItvController, 'Fecha ITV'),
                  const SizedBox(height: sectionSpacing),

                  // Transmisión
                  const Text('Transmisión *',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: sectionSpacing),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: fieldHeight,
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _transmision =
                                    _transmision == 'Manual' ? null : 'Manual';
                                _transmisionError = false;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              backgroundColor: _transmision == 'Manual'
                                  ? verdeSeleccionado
                                  : Colors.white,
                              foregroundColor: _transmision == 'Manual'
                                  ? Colors.white
                                  : colorScheme.onSurface
                                      .withAlpha(153), // ≈ 0.6 opacity
                              side: BorderSide(
                                color: _transmision == 'Manual'
                                    ? verdeSeleccionado
                                    : (_transmisionError
                                        ? Colors.red
                                        : colorScheme.outline),
                                width: _transmisionError ? 1.5 : 1.0,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(buttonRadius),
                              ),
                            ),
                            child: const Text('Manual'),
                          ),
                        ),
                      ),
                      const SizedBox(width: spacingHorizontal),
                      Expanded(
                        child: SizedBox(
                          height: fieldHeight,
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _transmision = _transmision == 'Automático'
                                    ? null
                                    : 'Automático';
                                _transmisionError = false;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              backgroundColor: _transmision == 'Automático'
                                  ? verdeSeleccionado
                                  : Colors.white,
                              foregroundColor: _transmision == 'Automático'
                                  ? Colors.white
                                  : colorScheme.onSurface
                                      .withAlpha(153), // ≈ 0.6 opacity
                              side: BorderSide(
                                color: _transmision == 'Automático'
                                    ? verdeSeleccionado
                                    : (_transmisionError
                                        ? Colors.red
                                        : colorScheme.outline),
                                width: _transmisionError ? 1.5 : 1.0,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(buttonRadius),
                              ),
                            ),
                            child: const Text('Automático'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_transmisionError)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0, left: 12.0),
                      child: Text(
                        'Selecciona una transmisión',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),

                  const SizedBox(height: sectionSpacing),

                  // Combustible
                  const Text('Combustible *',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: sectionSpacing),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: fieldHeight,
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _combustible =
                                    _combustible == 'Diésel' ? null : 'Diésel';
                                _combustibleError = false;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              backgroundColor: _combustible == 'Diésel'
                                  ? verdeSeleccionado
                                  : Colors.white,
                              foregroundColor: _combustible == 'Diésel'
                                  ? Colors.white
                                  : colorScheme.onSurface
                                      .withAlpha(153), // ≈ 0.6 opacity
                              side: BorderSide(
                                color: _combustible == 'Diésel'
                                    ? verdeSeleccionado
                                    : (_combustibleError
                                        ? Colors.red
                                        : colorScheme.outline),
                                width: _combustibleError ? 1.5 : 1.0,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(buttonRadius),
                              ),
                            ),
                            child: const Text('Diésel'),
                          ),
                        ),
                      ),
                      const SizedBox(width: spacingHorizontal),
                      Expanded(
                        child: SizedBox(
                          height: fieldHeight,
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _combustible = _combustible == 'Gasolina'
                                    ? null
                                    : 'Gasolina';
                                _combustibleError = false;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              backgroundColor: _combustible == 'Gasolina'
                                  ? verdeSeleccionado
                                  : Colors.white,
                              foregroundColor: _combustible == 'Gasolina'
                                  ? Colors.white
                                  : colorScheme.onSurface
                                      .withAlpha(153), // ≈ 0.6 opacity
                              side: BorderSide(
                                color: _combustible == 'Gasolina'
                                    ? verdeSeleccionado
                                    : (_combustibleError
                                        ? Colors.red
                                        : colorScheme.outline),
                                width: _combustibleError ? 1.5 : 1.0,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(buttonRadius),
                              ),
                            ),
                            child: const Text('Gasolina'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_combustibleError)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0, left: 12.0),
                      child: Text(
                        'Selecciona un combustible',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),

                  if (_statusMessage.isNotEmpty) ...[
                    const SizedBox(height: sectionSpacing),
                    Center(
                      child: Text(
                        _statusMessage,
                        style: TextStyle(
                          color: _statusMessage.contains('Error')
                              ? Colors.red
                              : verdeSeleccionado,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 3),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _guardarCoche,
          icon: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.add),
          label: Text(_isLoading ? 'Añadiendo...' : 'Añadir'),
        ),
      ],
    );
  }
}
