import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

class DataEditButton extends StatefulWidget {
  final int id;
  final String matricula;
  final String estadoCoche;

  const DataEditButton({
    super.key,
    required this.id,
    required this.matricula,
    required this.estadoCoche,
  });

  @override
  State<DataEditButton> createState() => _DataEditButtonState();
}

class _DataEditButtonState extends State<DataEditButton> {
  // === USUARIOS AUTORIZADOS PARA EDITAR ===
  static const List<String> _allowedEditors = [
    'ab193932-356f-4753-9f86-f98c2ef5d6c8',
    '0e507c01-505b-430f-963f-4929687cbe47',
  ];

  Map<String, dynamic>? _cocheData;
  bool _isLoading = true;
  String? _error;
  bool _isEditing = false;
  bool _isSaving = false;
  DateTime? _tempFechaItv;
  XFile? _selectedImageFile;

  final TextEditingController _precioController = TextEditingController();
  final FocusNode _precioFocusNode = FocusNode();

  String _tempEstadoPublicacion = '';
  String _tempEstadoDocumentos = '';

  final List<String> _estadosPublicacion = ['Por publicar', 'Publicado'];
  final List<String> _estadosDocumentos = ['Pendiente', 'Recibida'];

  static const TextStyle _editableStyle = TextStyle(
    fontSize: 14,
    color: Color.fromARGB(255, 14, 66, 117),
  );

  // Variable para saber si el usuario actual puede editar
  bool _canEdit = false;

  @override
  void initState() {
    super.initState();
    _checkEditPermission();
    _loadCarData();
  }

  @override
  void dispose() {
    _precioFocusNode.dispose();
    _precioController.dispose();
    super.dispose();
  }

  /// Comprueba si el usuario actual está en la lista de editores permitidos
  void _checkEditPermission() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final userId = currentUser?.id;

    if (userId != null && _allowedEditors.contains(userId)) {
      _canEdit = true;
    } else {
      _canEdit = false;
    }
  }

  Future<void> _loadCarData() async {
    try {
      final response = await Supabase.instance.client.from('coches').select('''
        fecha_alta, fecha_matriculacion, matricula, marca, modelo,
        bastidor, cv, cc, km, transmision, combustible, precio,
        fecha_itv, estado_documentos, estado_publicacion, ubicacion,
        ubicacion_update, estado_coche, nombre, dni, telefono,
        direccion, ciudad, cp, provincia, correo, precio_final,
        abono, medio_de_pago, garantia, fecha_reserva, fecha_venta,
        imagen_url
      ''').eq('id', widget.id).single();

      if (!mounted) return;

      setState(() {
        _cocheData = response;
        _tempFechaItv = response['fecha_itv'] != null
            ? DateTime.tryParse(response['fecha_itv'].toString())
            : null;
        _precioController.text =
            (response['precio'] as num?)?.toString() ?? '0';
        _tempEstadoPublicacion =
            response['estado_publicacion']?.toString() ?? 'Por publicar';
        _tempEstadoDocumentos =
            response['estado_documentos']?.toString() ?? 'Pendiente';
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _seleccionarFechaITV() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tempFechaItv ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2035),
      locale: const Locale('es', 'ES'),
    );
    if (picked != null && mounted) {
      setState(() => _tempFechaItv = picked);
    }
  }

  Future<void> _seleccionarImagen() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      setState(() => _selectedImageFile = image);
    }
  }

  Future<String?> _subirNuevaImagen() async {
    if (_selectedImageFile == null) return null;
    try {
      final extension = _selectedImageFile!.name.split('.').last;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'edit_${widget.matricula}_$timestamp.$extension';
      final fileBytes = await _selectedImageFile!.readAsBytes();

      await Supabase.instance.client.storage.from('imagenes').uploadBinary(
            fileName,
            fileBytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      final publicUrl = Supabase.instance.client.storage
          .from('imagenes')
          .getPublicUrl(fileName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Imagen actualizada'),
              backgroundColor: Colors.green),
        );
      }
      return publicUrl;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al subir imagen: $e'),
              backgroundColor: Colors.red),
        );
      }
      return null;
    }
  }

  Future<void> _guardarCambios() async {
    setState(() => _isSaving = true);
    try {
      final updates = <String, dynamic>{};

      final newItv = _tempFechaItv != null
          ? DateFormat('yyyy-MM-dd').format(_tempFechaItv!)
          : null;
      if (newItv != _cocheData?['fecha_itv']) {
        updates['fecha_itv'] = newItv;
      }

      final cleaned = _precioController.text
          .trim()
          .replaceAll(RegExp(r'[^\d.,]'), '')
          .replaceAll(',', '.');
      final precio = double.tryParse(cleaned);
      if (precio != null) {
        final newPrecio = precio.round();
        if (newPrecio != (_cocheData?['precio'] as num?)?.toInt()) {
          updates['precio'] = newPrecio;
        }
      }

      if (_tempEstadoPublicacion !=
          (_cocheData?['estado_publicacion']?.toString() ?? 'Por publicar')) {
        updates['estado_publicacion'] = _tempEstadoPublicacion;
      }

      if (_tempEstadoDocumentos !=
          (_cocheData?['estado_documentos']?.toString() ?? 'Pendiente')) {
        updates['estado_documentos'] = _tempEstadoDocumentos;
      }

      if (_selectedImageFile != null) {
        final url = await _subirNuevaImagen();
        if (url != null) {
          updates['imagen_url'] = url;
        }
      }

      if (updates.isNotEmpty) {
        await Supabase.instance.client
            .from('coches')
            .update(updates)
            .eq('id', widget.id);

        setState(() {
          updates.forEach((k, v) => _cocheData?[k] = v);
          _selectedImageFile = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Cambios guardados'),
                backgroundColor: Colors.green),
          );
        }
      }

      if (mounted) Navigator.pop(context, _cocheData);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al guardar: $e'),
              backgroundColor: Colors.red),
        );
        Navigator.pop(context, null);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _iniciarEdicion() => setState(() => _isEditing = true);

  void _cancelarEdicion() {
    setState(() {
      _isEditing = false;
      _selectedImageFile = null;
      _precioController.text =
          (_cocheData?['precio'] as num?)?.toString() ?? '0';
      _tempFechaItv = _cocheData?['fecha_itv'] != null
          ? DateTime.tryParse(_cocheData!['fecha_itv'].toString())
          : null;
      _tempEstadoPublicacion =
          _cocheData?['estado_publicacion']?.toString() ?? 'Por publicar';
      _tempEstadoDocumentos =
          _cocheData?['estado_documentos']?.toString() ?? 'Pendiente';
    });
  }

  String _formatDate(dynamic v, {String fallback = '—'}) {
    if (v == null || (v is String && v.trim().isEmpty)) return fallback;
    try {
      return DateFormat('dd/MM/yyyy')
          .format(DateTime.parse(v.toString()).toLocal());
    } catch (_) {
      return v.toString().trim();
    }
  }

  String _formatPrice(dynamic v, {String fallback = '—'}) {
    if (v == null) return fallback;
    final n = num.tryParse(v.toString());
    if (n == null) return v.toString();
    return NumberFormat.currency(locale: 'es_ES', symbol: '€', decimalDigits: 0)
        .format(n);
  }

  String _formatNumber(dynamic v) {
    if (v == null) return '—';
    final n = num.tryParse(v.toString());
    if (n == null) return v.toString();
    return NumberFormat.decimalPattern('es_ES').format(n);
  }

  bool get _showClientSaleSection {
    final estado = widget.estadoCoche.trim().toUpperCase();
    return estado == 'RESERVADO' || estado == 'VENDIDO';
  }

  Widget _editableWrapper(Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(6),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      titlePadding: EdgeInsets.zero,
      title: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
        child: Text(
          'Información',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
      contentPadding: EdgeInsets.zero,
      content: _isLoading
          ? const SizedBox(
              height: 200, child: Center(child: CircularProgressIndicator()))
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('Error al cargar:\n$_error'))
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildReadOnlyRow(
                            'Alta', _formatDate(_cocheData?['fecha_alta'])),
                        _buildReadOnlyRow('Matriculación',
                            _formatDate(_cocheData?['fecha_matriculacion'])),
                        _buildReadOnlyRow(
                            'Matrícula', _cocheData?['matricula'] ?? '—'),
                        _buildReadOnlyRow('Marca', _cocheData?['marca'] ?? '—'),
                        _buildReadOnlyRow(
                            'Modelo', _cocheData?['modelo'] ?? '—'),
                        _buildReadOnlyRow(
                            'Bastidor', _cocheData?['bastidor'] ?? '—'),
                        _buildReadOnlyRow(
                            'CV', _cocheData?['cv']?.toString() ?? '—'),
                        _buildReadOnlyRow(
                            'CC', _cocheData?['cc']?.toString() ?? '—'),
                        _buildReadOnlyRow(
                            'Kilómetros', _formatNumber(_cocheData?['km'])),
                        _buildReadOnlyRow(
                            'Transmisión', _cocheData?['transmision'] ?? '—'),
                        _buildReadOnlyRow(
                            'Combustible', _cocheData?['combustible'] ?? '—'),
                        _buildReadOnlyRow(
                            'Ubicación', _cocheData?['ubicacion'] ?? '—'),
                        _buildReadOnlyRow('Actualización',
                            _formatDate(_cocheData?['ubicacion_update'])),

                        // Campos editables (solo se muestran en modo edición)
                        _buildCompactEditableRow(
                          label: 'Fecha ITV',
                          displayValue: _isEditing
                              ? (_tempFechaItv != null
                                  ? DateFormat('dd/MM/yyyy')
                                      .format(_tempFechaItv!)
                                  : 'No establecida')
                              : _formatDate(_cocheData?['fecha_itv']),
                          editChild: _editableWrapper(
                            InkWell(
                              onTap: _seleccionarFechaITV,
                              borderRadius: BorderRadius.circular(6),
                              child: SizedBox(
                                height: 28,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 2),
                                        child: Text(
                                          _tempFechaItv != null
                                              ? DateFormat('dd/MM/yyyy')
                                                  .format(_tempFechaItv!)
                                              : 'No establecida',
                                          style: _editableStyle,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    const Icon(Icons.calendar_today,
                                        size: 20,
                                        color: Color.fromARGB(255, 67, 67, 67)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        _buildCompactEditableRow(
                          label: 'Precio',
                          displayValue: _isEditing
                              ? _precioController.text
                              : _formatPrice(_cocheData?['precio']),
                          editChild: _editableWrapper(
                            SizedBox(
                              height: 28,
                              child: Stack(
                                alignment: Alignment.centerRight,
                                children: [
                                  TextField(
                                    focusNode: _precioFocusNode,
                                    controller: _precioController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    textAlign: TextAlign.left,
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      disabledBorder: InputBorder.none,
                                      contentPadding:
                                          EdgeInsets.only(left: 4, right: 50),
                                      isDense: true,
                                      hintText: 'Ej: 24990',
                                    ),
                                    style: _editableStyle,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'^\d*([.,]?\d{0,2})?$')),
                                    ],
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.only(right: 8),
                                    child: Text(
                                      '€',
                                      style: TextStyle(
                                          fontSize: 15,
                                          color:
                                              Color.fromARGB(255, 66, 66, 66),
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        _buildCompactEditableRow(
                          label: 'Publicación',
                          displayValue: _isEditing
                              ? _tempEstadoPublicacion
                              : (_cocheData?['estado_publicacion']
                                      ?.toString() ??
                                  '—'),
                          editChild: _editableWrapper(
                            SizedBox(
                              height: 28,
                              child: DropdownButton<String>(
                                value: _tempEstadoPublicacion.isEmpty
                                    ? null
                                    : _tempEstadoPublicacion,
                                isDense: true,
                                isExpanded: true,
                                alignment: Alignment.centerLeft,
                                padding: EdgeInsets.zero,
                                underline: const SizedBox(),
                                icon: const Icon(Icons.arrow_drop_down,
                                    size: 20,
                                    color: Color.fromARGB(255, 66, 66, 66)),
                                style: _editableStyle,
                                dropdownColor: Colors.white,
                                elevation: 3,
                                borderRadius: BorderRadius.circular(6),
                                items: _estadosPublicacion
                                    .map((e) => DropdownMenuItem(
                                        value: e,
                                        child: Text(e, style: _editableStyle)))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() => _tempEstadoPublicacion = v);
                                  }
                                },
                              ),
                            ),
                          ),
                        ),

                        _buildCompactEditableRow(
                          label: 'Documentación',
                          displayValue: _isEditing
                              ? _tempEstadoDocumentos
                              : (_cocheData?['estado_documentos']?.toString() ??
                                  '—'),
                          editChild: _editableWrapper(
                            SizedBox(
                              height: 28,
                              child: DropdownButton<String>(
                                value: _tempEstadoDocumentos.isEmpty
                                    ? null
                                    : _tempEstadoDocumentos,
                                isDense: true,
                                isExpanded: true,
                                alignment: Alignment.centerLeft,
                                padding: EdgeInsets.zero,
                                underline: const SizedBox(),
                                icon: const Icon(Icons.arrow_drop_down,
                                    size: 20,
                                    color: Color.fromARGB(255, 66, 66, 66)),
                                style: _editableStyle,
                                dropdownColor: Colors.white,
                                elevation: 3,
                                borderRadius: BorderRadius.circular(6),
                                items: _estadosDocumentos
                                    .map((e) => DropdownMenuItem(
                                        value: e,
                                        child: Text(e, style: _editableStyle)))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() => _tempEstadoDocumentos = v);
                                  }
                                },
                              ),
                            ),
                          ),
                        ),

                        _buildCompactEditableRow(
                          label: 'Imagen',
                          displayValue: _isEditing
                              ? (_selectedImageFile != null
                                  ? 'Nueva imagen seleccionada'
                                  : 'Existente')
                              : (_cocheData?['imagen_url']
                                          ?.toString()
                                          .isNotEmpty ==
                                      true
                                  ? 'Existente'
                                  : 'Sin imagen'),
                          editChild: _editableWrapper(
                            InkWell(
                              onTap: _seleccionarImagen,
                              borderRadius: BorderRadius.circular(6),
                              child: SizedBox(
                                height: 28,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 0),
                                        child: Text(
                                          _selectedImageFile != null
                                              ? 'Nueva imagen seleccionada'
                                              : 'Subir imagen',
                                          style: _selectedImageFile != null
                                              ? const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.green)
                                              : _editableStyle,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.only(right: 0),
                                      child: Icon(
                                          Icons.add_photo_alternate_rounded,
                                          size: 20,
                                          color: Colors.blueGrey),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        if (_showClientSaleSection) ...[
                          const Divider(height: 24),
                          ExpansionTile(
                            title: const Text(
                              'Datos de cliente y venta',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            initiallyExpanded: true,
                            childrenPadding:
                                const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            children: [
                              _buildReadOnlyRow('Nombre cliente',
                                  _cocheData?['nombre'] ?? '—'),
                              _buildReadOnlyRow(
                                  'DNI / NIE', _cocheData?['dni'] ?? '—'),
                              _buildReadOnlyRow(
                                  'Teléfono', _cocheData?['telefono'] ?? '—'),
                              _buildReadOnlyRow(
                                  'Dirección', _cocheData?['direccion'] ?? '—'),
                              _buildReadOnlyRow(
                                  'Ciudad', _cocheData?['ciudad'] ?? '—'),
                              _buildReadOnlyRow(
                                'C.P.',
                                (_cocheData?['cp'] as num?)?.toString() ?? '—',
                              ),
                              _buildReadOnlyRow(
                                  'Provincia', _cocheData?['provincia'] ?? '—'),
                              _buildReadOnlyRow(
                                  'Correo', _cocheData?['correo'] ?? '—'),
                              _buildReadOnlyRow(
                                  'Abono', _formatPrice(_cocheData?['abono'])),
                              _buildReadOnlyRow('Precio final',
                                  _formatPrice(_cocheData?['precio_final'])),
                              _buildReadOnlyRow('Medio de pago',
                                  _cocheData?['medio_de_pago'] ?? '—'),
                              _buildReadOnlyRow(
                                  'Garantía', _cocheData?['garantia'] ?? '—'),
                              _buildReadOnlyRow('Fecha reserva',
                                  _formatDate(_cocheData?['fecha_reserva'])),
                              _buildReadOnlyRow('Fecha venta',
                                  _formatDate(_cocheData?['fecha_venta'])),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        if (_isEditing) ...[
          TextButton(
            onPressed: _isSaving ? null : _cancelarEdicion,
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _guardarCambios,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save, size: 18),
            label: Text(_isSaving ? 'Guardando...' : 'Guardar'),
          ),
        ] else ...[
          TextButton(
            onPressed: () => Navigator.pop(context, _cocheData),
            child: const Text('Cerrar'),
          ),
          // Solo mostramos el botón "Editar" si el usuario está autorizado
          if (!_isLoading && _error == null && _canEdit)
            TextButton.icon(
              onPressed: _iniciarEdicion,
              icon:
                  Icon(Icons.edit, size: 16, color: theme.colorScheme.primary),
              label: const Text('Editar',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary),
            ),
        ],
      ],
    );
  }

  Widget _buildReadOnlyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF616161),
                  fontSize: 14),
            ),
          ),
          Expanded(
              child:
                  SelectableText(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildCompactEditableRow({
    required String label,
    required String displayValue,
    required Widget editChild,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF616161),
                  fontSize: 14),
            ),
          ),
          Expanded(
            child: _isEditing
                ? editChild
                : SelectableText(displayValue,
                    style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
