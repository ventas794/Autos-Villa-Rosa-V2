import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PrestadoMatriculaDialog extends StatefulWidget {
  final List<Map<String, String>> vehiculos;

  const PrestadoMatriculaDialog({
    super.key,
    required this.vehiculos,
  });

  @override
  State<PrestadoMatriculaDialog> createState() =>
      _PrestadoMatriculaDialogState();
}

class _PrestadoMatriculaDialogState extends State<PrestadoMatriculaDialog> {
  final TextEditingController _searchController = TextEditingController();
  late List<Map<String, String>> _filteredVehiculos;

  @override
  void initState() {
    super.initState();
    _filteredVehiculos = List.from(widget.vehiculos);
    _searchController.addListener(_filtrar);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filtrar);
    _searchController.dispose();
    super.dispose();
  }

  void _filtrar() {
    final query = _searchController.text.trim().toUpperCase();
    setState(() {
      if (query.isEmpty) {
        _filteredVehiculos = List.from(widget.vehiculos);
      } else {
        _filteredVehiculos = widget.vehiculos.where((veh) {
          final matricula = veh['matricula']!.toUpperCase();
          final marca = (veh['marca'] ?? '').toUpperCase();
          final modelo = (veh['modelo'] ?? '').toUpperCase();
          return matricula.contains(query) ||
              marca.contains(query) ||
              modelo.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 24.0, vertical: 80.0),
      contentPadding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(
        width: 360,
        height: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Buscar matrícula, marca o modelo...',
                labelStyle: const TextStyle(fontSize: 14),
                prefixIcon: const Icon(Icons.search, size: 20),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              style: const TextStyle(fontSize: 14.5),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _filteredVehiculos.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay coincidencias',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredVehiculos.length,
                      itemBuilder: (context, index) {
                        final veh = _filteredVehiculos[index];
                        final matricula = veh['matricula']!;
                        final marcaModelo =
                            '${veh['marca'] ?? ''} ${veh['modelo'] ?? ''}'
                                .trim();
                        return ListTile(
                          dense: true,
                          visualDensity: const VisualDensity(vertical: -3),
                          minVerticalPadding: 0,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 2),
                          title: Row(
                            children: [
                              Text(
                                matricula,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15.5,
                                ),
                              ),
                              if (marcaModelo.isNotEmpty) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    marcaModelo,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: Colors.grey[700],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          onTap: () => Navigator.pop(context, matricula),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(fontSize: 14)),
        ),
      ],
      actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
    );
  }
}

class UbicacionEditButton extends StatefulWidget {
  final String? cocheId;
  final String? currentUbicacion;

  const UbicacionEditButton({
    super.key,
    this.cocheId,
    this.currentUbicacion,
  });

  @override
  State<UbicacionEditButton> createState() => _UbicacionEditButtonState();
}

class _UbicacionEditButtonState extends State<UbicacionEditButton> {
  String? _selectedUbicacion;
  String _customUbicacion = '';
  bool _isPrestadoSelected = false;
  final TextEditingController _customController = TextEditingController();

  final Map<String, List<String>> _ubicaciones = {
    'Málaga': [
      'CURVA',
      'LINEA',
      'PALENQUE',
      'DECATHLON',
      'ESCUELA',
      'IGLESIA',
      'GUITARRERO',
      'AV. VILLA ROSA',
    ],
    'Algarrobo': [
      'POLÍGONO',
      'EXPLANADA',
      'MEZQUITILLA',
      'CHILCHES',
    ],
  };

  List<Map<String, String>> _vehiculos = [];

  @override
  void initState() {
    super.initState();
    final current = widget.currentUbicacion?.trim();
    if (current != null && current.isNotEmpty) {
      final upper = current.toUpperCase();
      if (upper.startsWith('PRESTADO - ')) {
        _isPrestadoSelected = true;
        _selectedUbicacion = current;
      } else {
        bool encontrado = false;
        for (final list in _ubicaciones.values) {
          for (final ubic in list) {
            if (ubic.toUpperCase() == upper) {
              _selectedUbicacion = ubic;
              encontrado = true;
              break;
            }
          }
          if (encontrado) break;
        }
        if (!encontrado) {
          _customUbicacion = current;
          _customController.text = current;
          _customController.selection = TextSelection.fromPosition(
            TextPosition(offset: _customController.text.length),
          );
        }
      }
    }
    _cargarVehiculos();
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  String _extractMatricula(String? ubicacion) {
    if (ubicacion == null) return '';
    if (ubicacion.toUpperCase().startsWith('PRESTADO - ')) {
      return ubicacion.substring('Prestado - '.length).trim();
    }
    return ubicacion;
  }

  Future<void> _cargarVehiculos() async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase
          .from('coches')
          .select('matricula, marca, modelo')
          .not('matricula', 'is', null)
          .neq('matricula', '')
          .order('matricula');

      if (!mounted) return;

      setState(() {
        _vehiculos = response
            .map((row) {
              return {
                'matricula':
                    (row['matricula'] as String?)?.trim().toUpperCase() ?? '',
                'marca': (row['marca'] as String?)?.trim() ?? '',
                'modelo': (row['modelo'] as String?)?.trim() ?? '',
              };
            })
            .where((veh) => veh['matricula']!.isNotEmpty)
            .toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando vehículos: $e')),
        );
      }
    }
  }

  Future<void> _mostrarSelectorPrestado() async {
    final selectedMat = await showDialog<String?>(
      context: context,
      builder: (context) => PrestadoMatriculaDialog(
        vehiculos: _vehiculos,
      ),
    );

    if (selectedMat != null && mounted) {
      setState(() {
        _selectedUbicacion = 'Prestado - $selectedMat';
        _customUbicacion = '';
        _customController.clear();
        _isPrestadoSelected = true;
      });
    }
  }

  Future<void> _guardarUbicacion() async {
    String? nuevaUbicacion = _isPrestadoSelected &&
            _selectedUbicacion != null &&
            _selectedUbicacion!.toUpperCase().startsWith('PRESTADO - ')
        ? _selectedUbicacion
        : (_selectedUbicacion ?? _customUbicacion.trim());

    if (nuevaUbicacion == null || nuevaUbicacion.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona o escribe una ubicación'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final ubicacionFinal =
        nuevaUbicacion.toUpperCase().startsWith('PRESTADO - ')
            ? nuevaUbicacion
            : nuevaUbicacion[0].toUpperCase() +
                nuevaUbicacion.substring(1).toLowerCase().trim();

    final idStr = widget.cocheId;
    if (idStr == null || idStr.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se puede guardar: ID del vehículo no disponible'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final id = int.tryParse(idStr);
    if (id == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ID del vehículo inválido'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final supabase = Supabase.instance.client;

    try {
      final currentData = await supabase
          .from('coches')
          .select('ubicacion, estado_coche')
          .eq('id', id)
          .maybeSingle();

      if (currentData == null) {
        throw Exception('No se encontró el coche');
      }

      final currentUbicacionDB =
          (currentData['ubicacion'] as String?)?.trim() ?? '';

      bool debeCambiarEstado = false;
      String? nuevoEstado;

      if (currentUbicacionDB.toUpperCase() == 'POR LLEGAR' &&
          ubicacionFinal.toUpperCase() != 'POR LLEGAR') {
        debeCambiarEstado = true;
        nuevoEstado = 'Disponible';
      }

      bool confirmado = true;

      if (debeCambiarEstado) {
        if (!mounted) return;

        final result = await showDialog<bool?>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Cambio de estado automático'),
            content: const Text(
              'Al cambiar la ubicación, el estado del coche pasará automáticamente de "Por llegar" a "Disponible".\n\n¿Deseas continuar?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Sí, guardar'),
              ),
            ],
          ),
        );

        confirmado = result == true;
      }

      if (!confirmado) return;

      final updateData = <String, dynamic>{
        'ubicacion': ubicacionFinal,
        'ubicacion_update': DateTime.now().toUtc().toIso8601String(),
      };

      if (debeCambiarEstado && nuevoEstado != null) {
        updateData['estado_coche'] = nuevoEstado;
      }

      await supabase.from('coches').update(updateData).eq('id', id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            debeCambiarEstado
                ? 'Ubicación y estado actualizados correctamente'
                : 'Ubicación actualizada correctamente',
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );

      Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error inesperado: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    const verdeSeleccionado = Color.fromARGB(255, 0, 114, 15);

    return AlertDialog(
      title: const Text('Editar ubicación'),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      content: ConstrainedBox(
        constraints:
            const BoxConstraints(minWidth: 320, maxWidth: 320, maxHeight: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ... (el resto del build es exactamente igual al que tenías, no lo cambio)
              // Ubicaciones fijas
              ..._ubicaciones.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const spacing = 6.0;
                        final buttonWidth =
                            (constraints.maxWidth - spacing) / 2;
                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing - 2,
                          children: entry.value.map((ubic) {
                            final selected = _selectedUbicacion == ubic &&
                                !_isPrestadoSelected;
                            return SizedBox(
                              width: buttonWidth,
                              height: 36,
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedUbicacion = ubic;
                                    _customUbicacion = '';
                                    _customController.clear();
                                    _isPrestadoSelected = false;
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: selected
                                      ? verdeSeleccionado
                                      : Colors.white,
                                  foregroundColor: selected
                                      ? Colors.white
                                      : colorScheme.onSurface.withAlpha(153),
                                  side: BorderSide(
                                    color: selected
                                        ? verdeSeleccionado
                                        : colorScheme.outline,
                                    width: 1.2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 0),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  minimumSize: Size.zero,
                                ),
                                child: Text(
                                  ubic,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.15,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 6),
                  ],
                );
              }),

              const Divider(height: 20, thickness: 1),

              // Prestado
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 6),
                child: Text(
                  'Prestado',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: GestureDetector(
                  onTap: _mostrarSelectorPrestado,
                  child: AbsorbPointer(
                    child: Container(
                      decoration: BoxDecoration(
                        color: _isPrestadoSelected
                            ? verdeSeleccionado
                            : Colors.white,
                        border: Border.all(
                          color: _isPrestadoSelected
                              ? verdeSeleccionado
                              : colorScheme.outline,
                          width: 1.2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _isPrestadoSelected && _selectedUbicacion != null
                            ? _extractMatricula(_selectedUbicacion)
                            : 'Seleccionar matrícula',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: _isPrestadoSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: _isPrestadoSelected
                              ? Colors.white
                              : Colors.grey[800],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Otra ubicación
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Otra ubicación',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              ),
              TextField(
                controller: _customController,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                onChanged: (value) {
                  setState(() {
                    _customUbicacion = value.trim();
                    if (value.trim().isNotEmpty) {
                      _selectedUbicacion = null;
                      _isPrestadoSelected = false;
                    }
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Ej: Chapa, Taller, Particular...',
                  hintStyle: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: colorScheme.outline, width: 1.2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: colorScheme.outline, width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: verdeSeleccionado, width: 2),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _guardarUbicacion,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
