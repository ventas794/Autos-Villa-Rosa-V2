import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class CitasScreen extends StatefulWidget {
  const CitasScreen({super.key});

  @override
  State<CitasScreen> createState() => _CitasScreenState();
}

class _CitasScreenState extends State<CitasScreen> {
  final supabase = Supabase.instance.client;
  String? _matriculaSeleccionada;
  final _clienteController = TextEditingController();
  final _telefonoController = TextEditingController();
  DateTime? _fechaSeleccionada;
  TimeOfDay? _horaSeleccionada;
  final List<int> _horasDisponibles = List.generate(16, (index) => 8 + index);
  List<Map<String, dynamic>> _coches = [];
  List<Map<String, dynamic>> _citas = [];
  bool _loading = true;
  bool _mostrarProximas = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _loading = true);
    try {
      final cochesRes = await supabase
          .from('coches')
          .select('id, matricula, marca, modelo, imagen_url')
          .order('matricula', ascending: true);
      final citasRes = await supabase.from('citas').select('''
            id,
            fecha_cita,
            hora,
            telefono,
            marca,
            modelo,
            matricula,
            cliente,
            coche:coche_id (
              ubicacion,
              imagen_url
            )
          ''').order('fecha_cita', ascending: true);
      if (!mounted) return;
      setState(() {
        _coches = List<Map<String, dynamic>>.from(cochesRes);
        _citas = List<Map<String, dynamic>>.from(citasRes);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar datos: $e')),
      );
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _citasFiltradas {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    return _citas.where((cita) {
      final fechaStr = cita['fecha_cita'] as String?;
      if (fechaStr == null) return false;
      final fecha = DateTime.parse(fechaStr).toLocal();
      final fechaSinHora = DateTime(fecha.year, fecha.month, fecha.day);
      return _mostrarProximas
          ? !fechaSinHora.isBefore(hoy)
          : fechaSinHora.isBefore(hoy);
    }).toList();
  }

  Map<DateTime, List<Map<String, dynamic>>> get _citasAgrupadas {
    final Map<DateTime, List<Map<String, dynamic>>> agrupadas = {};
    for (final cita in _citasFiltradas) {
      final fechaStr = cita['fecha_cita'] as String?;
      if (fechaStr == null) continue;
      final fecha = DateTime.parse(fechaStr).toLocal();
      final fechaSinHora = DateTime(fecha.year, fecha.month, fecha.day);
      agrupadas.putIfAbsent(fechaSinHora, () => []).add(cita);
    }
    final sortedKeys = agrupadas.keys.toList()
      ..sort((a, b) => _mostrarProximas ? a.compareTo(b) : b.compareTo(a));
    final Map<DateTime, List<Map<String, dynamic>>> ordenadas = {};
    for (final key in sortedKeys) {
      agrupadas[key]!.sort((a, b) {
        final hA = a['hora'] as String? ?? '00:00:00';
        final hB = b['hora'] as String? ?? '00:00:00';
        return hA.compareTo(hB);
      });
      ordenadas[key] = agrupadas[key]!;
    }
    return ordenadas;
  }

  Future<void> _mostrarDialogoNuevaCita() async {
    _matriculaSeleccionada = null;
    _clienteController.clear();
    _telefonoController.clear();
    _fechaSeleccionada = null;
    _horaSeleccionada = null;
    await _mostrarDialogoCita(null);
  }

  Future<void> _mostrarDialogoEditarCita(Map<String, dynamic> cita) async {
    _matriculaSeleccionada = cita['matricula'] as String?;
    _clienteController.text = cita['cliente'] as String? ?? '';
    _telefonoController.text = cita['telefono'] as String? ?? '';
    final fecha = DateTime.parse(cita['fecha_cita'] as String).toLocal();
    _fechaSeleccionada = fecha;
    final hora = TimeOfDay.fromDateTime(fecha);
    _horaSeleccionada = _horasDisponibles.contains(hora.hour) ? hora : null;
    await _mostrarDialogoCita(cita);
  }

  Future<void> _mostrarDialogoCita(Map<String, dynamic>? citaExistente) async {
    final esEdicion = citaExistente != null;
    final idCita = citaExistente?['id'] as int?;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(esEdicion ? 'Editar cita' : 'Nueva cita'),
              if (esEdicion)
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 28),
                  tooltip: 'Eliminar cita',
                  onPressed: () async {
                    final confirmar = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Eliminar cita'),
                        content: const Text(
                            '¿Seguro que quieres eliminar esta cita? Esta acción no se puede deshacer.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.red),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Eliminar'),
                          ),
                        ],
                      ),
                    );
                    if (confirmar == true && idCita != null) {
                      await _eliminarCita(idCita, dialogContext);
                    }
                  },
                ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: const EdgeInsets.symmetric(vertical: 2),
                  title: Text(
                    _matriculaSeleccionada != null
                        ? 'Matrícula: $_matriculaSeleccionada'
                        : 'Selecciona matrícula *',
                    style: TextStyle(
                      fontSize: 14.5,
                      color: _matriculaSeleccionada != null ? null : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_drop_down, size: 24),
                  onTap: () async {
                    final selectedMat = await showDialog<String?>(
                      context: context,
                      builder: (context) => PrestadoMatriculaDialog(
                        vehiculos: _coches
                            .map((c) => {
                                  'matricula': (c['matricula'] as String?)
                                          ?.trim()
                                          .toUpperCase() ??
                                      '',
                                  'marca':
                                      (c['marca'] as String?)?.trim() ?? '',
                                  'modelo':
                                      (c['modelo'] as String?)?.trim() ?? '',
                                })
                            .where((v) => v['matricula']!.isNotEmpty)
                            .toList(),
                      ),
                    );
                    if (selectedMat != null && mounted) {
                      setDialogState(() {
                        _matriculaSeleccionada = selectedMat;
                      });
                    }
                  },
                ),
                TextField(
                  controller: _clienteController,
                  decoration: const InputDecoration(
                    labelText: 'Cliente',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  ),
                  style: const TextStyle(fontSize: 14.5),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _telefonoController,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  ),
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 14.5),
                ),
                const SizedBox(height: 10),
                ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: const EdgeInsets.symmetric(vertical: 2),
                  title: Text(
                    _fechaSeleccionada == null
                        ? 'Fecha *'
                        : 'Fecha: ${DateFormat('dd/MM/yyyy').format(_fechaSeleccionada!)}',
                    style: const TextStyle(fontSize: 14.5),
                  ),
                  trailing: const Icon(Icons.calendar_today, size: 22),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _fechaSeleccionada ??
                          DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (date != null && mounted) {
                      setDialogState(() => _fechaSeleccionada = date);
                    }
                  },
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('Hora:', style: TextStyle(fontSize: 14.5)),
                    SizedBox(
                      width: 140,
                      child: DropdownButton<int>(
                        value: _horaSeleccionada?.hour,
                        isDense: true,
                        isExpanded: true,
                        underline:
                            Container(height: 1, color: Colors.grey.shade400),
                        iconSize: 18,
                        menuMaxHeight: 240,
                        dropdownColor: Colors.white,
                        style: const TextStyle(
                            fontSize: 14.5, color: Colors.black87),
                        hint: const Text('Seleccionar',
                            style: TextStyle(fontSize: 13, color: Colors.grey)),
                        items: _horasDisponibles.map((hora) {
                          return DropdownMenuItem<int>(
                            value: hora,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${hora.toString().padLeft(2, '0')}:00',
                              style: const TextStyle(
                                  color: Colors.black87, fontSize: 14),
                            ),
                          );
                        }).toList(),
                        onChanged: (int? nuevaHora) {
                          if (nuevaHora != null) {
                            setDialogState(() {
                              _horaSeleccionada =
                                  TimeOfDay(hour: nuevaHora, minute: 0);
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: _formularioValido
                  ? () => esEdicion
                      ? _actualizarCita(dialogContext, idCita!)
                      : _guardarCita(dialogContext)
                  : null,
              child: Text(esEdicion ? 'Guardar' : 'Crear'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _eliminarCita(int id, BuildContext dialogContext) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(dialogContext);
    try {
      await supabase.from('citas').delete().eq('id', id);
      if (!mounted) return;
      navigator.pop();
      scaffoldMessenger.showSnackBar(
        const SnackBar(
            content: Text('Cita eliminada'), backgroundColor: Colors.red),
      );
      await _cargarDatos();
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  bool get _formularioValido =>
      _matriculaSeleccionada != null &&
      _fechaSeleccionada != null &&
      _horaSeleccionada != null;

  Future<void> _guardarCita(BuildContext dialogContext) async {
    final coche = _coches.firstWhere(
      (c) => c['matricula'] == _matriculaSeleccionada,
      orElse: () => <String, dynamic>{},
    );
    if (coche.isEmpty) return;

    final fechaCita = DateTime(
      _fechaSeleccionada!.year,
      _fechaSeleccionada!.month,
      _fechaSeleccionada!.day,
      _horaSeleccionada!.hour,
      0,
    );
    final horaStr =
        '${_horaSeleccionada!.hour.toString().padLeft(2, '0')}:00:00';

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(dialogContext);

    try {
      await supabase.from('citas').insert({
        'coche_id': coche['id'],
        'usuario_id': null,
        'evento': 'crear_cita',
        'matricula': _matriculaSeleccionada,
        'marca': coche['marca'],
        'modelo': coche['modelo'],
        'cliente': _clienteController.text.trim().isNotEmpty
            ? _clienteController.text.trim()
            : null,
        'telefono': _telefonoController.text.trim().isNotEmpty
            ? _telefonoController.text.trim()
            : null,
        'hora': horaStr,
        'fecha_cita': fechaCita.toUtc().toIso8601String(),
      });
      if (!mounted) return;
      navigator.pop();
      scaffoldMessenger.showSnackBar(
        const SnackBar(
            content: Text('Cita creada'), backgroundColor: Colors.green),
      );
      await _cargarDatos();
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _actualizarCita(BuildContext dialogContext, int id) async {
    final coche = _coches.firstWhere(
      (c) => c['matricula'] == _matriculaSeleccionada,
      orElse: () => <String, dynamic>{},
    );
    if (coche.isEmpty) return;

    final fechaCita = DateTime(
      _fechaSeleccionada!.year,
      _fechaSeleccionada!.month,
      _fechaSeleccionada!.day,
      _horaSeleccionada!.hour,
      0,
    );
    final horaStr =
        '${_horaSeleccionada!.hour.toString().padLeft(2, '0')}:00:00';

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(dialogContext);

    try {
      await supabase.from('citas').update({
        'coche_id': coche['id'],
        'matricula': _matriculaSeleccionada,
        'marca': coche['marca'],
        'modelo': coche['modelo'],
        'cliente': _clienteController.text.trim().isNotEmpty
            ? _clienteController.text.trim()
            : null,
        'telefono': _telefonoController.text.trim().isNotEmpty
            ? _telefonoController.text.trim()
            : null,
        'hora': horaStr,
        'fecha_cita': fechaCita.toUtc().toIso8601String(),
      }).eq('id', id);
      if (!mounted) return;
      navigator.pop();
      scaffoldMessenger.showSnackBar(
        const SnackBar(
            content: Text('Cita actualizada'), backgroundColor: Colors.green),
      );
      await _cargarDatos();
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  String _formatearFechaHeader(DateTime fecha) {
    final hoy = DateTime.now();
    final fechaHoy = DateTime(hoy.year, hoy.month, hoy.day);
    if (fecha.year == fechaHoy.year &&
        fecha.month == fechaHoy.month &&
        fecha.day == fechaHoy.day) {
      return 'Hoy – ${DateFormat('dd MMMM yyyy', 'es').format(fecha)}';
    }
    return DateFormat('EEEE dd MMMM yyyy', 'es').format(fecha);
  }

  String _formatearHora(dynamic hora) {
    if (hora == null) return '--:--';
    return (hora as String).substring(0, 5);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Citas'),
        centerTitle: true,
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 40,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      body: Column(
        children: [
          Container(
            color: theme.scaffoldBackgroundColor,
            padding: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 4.0),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 30.0,
                    child: ChoiceChip(
                      label: Container(
                        width: double.infinity,
                        alignment: Alignment.center,
                        child: const Text(
                          'ANTERIORES',
                          style: TextStyle(
                              fontSize: 12.0, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      selected: !_mostrarProximas,
                      onSelected: (selected) {
                        if (selected) setState(() => _mostrarProximas = false);
                      },
                      labelStyle: TextStyle(
                        color:
                            !_mostrarProximas ? Colors.white : Colors.black87,
                      ),
                      backgroundColor: Colors.grey.shade200,
                      selectedColor: const Color(0xFF0053A0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        side: BorderSide(
                          color: !_mostrarProximas
                              ? const Color(0xFF0053A0)
                              : Colors.grey.shade400,
                          width: 1.0,
                        ),
                      ),
                      showCheckmark: false,
                      padding: EdgeInsets.zero,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                    ),
                  ),
                ),
                const SizedBox(width: 3.0),
                Expanded(
                  child: SizedBox(
                    height: 30.0,
                    child: ChoiceChip(
                      label: Container(
                        width: double.infinity,
                        alignment: Alignment.center,
                        child: const Text(
                          'PROXIMAS',
                          style: TextStyle(
                              fontSize: 12.0, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      selected: _mostrarProximas,
                      onSelected: (selected) {
                        if (selected) setState(() => _mostrarProximas = true);
                      },
                      labelStyle: TextStyle(
                        color: _mostrarProximas ? Colors.white : Colors.black87,
                      ),
                      backgroundColor: Colors.grey.shade200,
                      selectedColor: const Color(0xFF0053A0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        side: BorderSide(
                          color: _mostrarProximas
                              ? const Color(0xFF0053A0)
                              : Colors.grey.shade400,
                          width: 1.0,
                        ),
                      ),
                      showCheckmark: false,
                      padding: EdgeInsets.zero,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _citasAgrupadas.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _mostrarProximas
                                ? 'No hay citas próximas'
                                : 'No hay citas pasadas',
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _cargarDatos,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 0, vertical: 4),
                          itemCount: _citasAgrupadas.length,
                          itemBuilder: (context, index) {
                            final fecha = _citasAgrupadas.keys.elementAt(index);
                            final citasDia = _citasAgrupadas[fecha]!;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(10.5, 4, 4, 0),
                                  child: Text(
                                    _formatearFechaHeader(fecha),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: fecha.day == DateTime.now().day
                                          ? theme.colorScheme.primary
                                          : null,
                                    ),
                                  ),
                                ),
                                ...citasDia.map((cita) {
                                  final horaStr = _formatearHora(cita['hora']);
                                  final marcaModelo =
                                      '${cita['marca'] ?? ''} ${cita['modelo'] ?? ''}'
                                          .trim();
                                  final matricula = cita['matricula'] ?? '—';
                                  final cocheData =
                                      cita['coche'] as Map<String, dynamic>?;
                                  final ubicacion =
                                      cocheData?['ubicacion'] as String?;
                                  final imagenUrl =
                                      cocheData?['imagen_url'] as String?;
                                  final telefono = cita['telefono'] as String?;
                                  final cliente = cita['cliente'] as String?;

                                  return SizedBox(
                                    height: 82.5,
                                    child: Card(
                                      elevation: 4.0,
                                      margin:
                                          const EdgeInsets.fromLTRB(4, 2, 4, 2),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                        // ← Borde gris eliminado aquí
                                      ),
                                      child: InkWell(
                                        onTap: () =>
                                            _mostrarDialogoEditarCita(cita),
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  const BorderRadius.only(
                                                topLeft: Radius.circular(8.0),
                                                bottomLeft:
                                                    Radius.circular(8.0),
                                              ),
                                              child: SizedBox(
                                                width: 110,
                                                height: 82.5,
                                                child: imagenUrl != null &&
                                                        imagenUrl.isNotEmpty
                                                    ? Image.network(
                                                        imagenUrl,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (context,
                                                                error,
                                                                stackTrace) =>
                                                            Container(
                                                          color:
                                                              Colors.grey[300],
                                                          alignment:
                                                              Alignment.center,
                                                          child: const Icon(
                                                              Icons
                                                                  .broken_image,
                                                              size: 40,
                                                              color:
                                                                  Colors.grey),
                                                        ),
                                                        loadingBuilder: (context,
                                                            child,
                                                            loadingProgress) {
                                                          if (loadingProgress ==
                                                              null)
                                                            return child;
                                                          return Container(
                                                            color: Colors
                                                                .grey[200],
                                                            alignment: Alignment
                                                                .center,
                                                            child:
                                                                const SizedBox(
                                                              width: 30,
                                                              height: 30,
                                                              child:
                                                                  CircularProgressIndicator(
                                                                      strokeWidth:
                                                                          2),
                                                            ),
                                                          );
                                                        },
                                                      )
                                                    : Container(
                                                        color: Colors.grey[300],
                                                        alignment:
                                                            Alignment.center,
                                                        child: const Icon(
                                                            Icons
                                                                .directions_car,
                                                            size: 50,
                                                            color: Colors.grey),
                                                      ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                        8, 6, 8, 6),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      marcaModelo.isEmpty
                                                          ? '—'
                                                          : marcaModelo,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 13,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      matricula +
                                                          (ubicacion != null &&
                                                                  ubicacion
                                                                      .isNotEmpty
                                                              ? ' • $ubicacion'
                                                              : ''),
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: Colors.grey[700],
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 1.5),
                                                    if (telefono != null ||
                                                        cliente != null)
                                                      Text(
                                                        [
                                                          if (telefono != null)
                                                            telefono,
                                                          if (cliente != null)
                                                            cliente,
                                                        ].join(' • '),
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color:
                                                              Colors.grey[600],
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10.0),
                                              child: Center(
                                                child: Text(
                                                  horaStr,
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                    color: theme
                                                        .colorScheme.primary,
                                                    letterSpacing: 0.8,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarDialogoNuevaCita,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        elevation: 6.0,
        highlightElevation: 12.0,
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    _clienteController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }
}

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
                                    fontSize: 15.5),
                              ),
                              if (marcaModelo.isNotEmpty) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    marcaModelo,
                                    style: TextStyle(
                                        fontSize: 13, color: Colors.grey[700]),
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
