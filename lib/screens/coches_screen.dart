import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';
import '../form/add_car_form.dart';
import 'filtros_adicionales_screen.dart';
import '../button/pdf_edit_button.dart';
import '../button/ubicacion_edit_button.dart';
import '../button/data_edit_button.dart';

class CochesScreen extends StatefulWidget {
  const CochesScreen({super.key});
  @override
  State<CochesScreen> createState() => _CochesScreenState();
}

class _CochesScreenState extends State<CochesScreen> {
  List<Map<String, dynamic>> _coches = [];
  List<Map<String, dynamic>> _cochesFiltrados = [];
  bool _isLoading = true;
  Map<String, dynamic> _filtrosActivos = {};
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String? _selectedEstadoCoche;
  final ScrollController _scrollController = ScrollController();
  @override
  void initState() {
    super.initState();
    _loadCoches();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _aplicarFiltrosYBusqueda();
    });
  }

  Future<void> _loadCoches() async {
    try {
      final response = await Supabase.instance.client.from('coches').select('''
            id, matricula, marca, modelo, estado_coche, precio,
            fecha_matriculacion, fecha_itv, ubicacion, ubicacion_update,
            km, imagen_url, combustible, transmision, estado_documentos,
            estado_publicacion, cv, cc, bastidor, fecha_alta
          ''').order('id', ascending: false);
      if (mounted) {
        setState(() {
          _coches = List<Map<String, dynamic>>.from(response);
          _cochesFiltrados = List.from(_coches);
          _isLoading = false;
        });
        _aplicarFiltrosYBusqueda();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar coches: $e')),
        );
      }
    }
  }

  void _aplicarFiltrosYBusqueda() {
    List<Map<String, dynamic>> filtrados = List.from(_coches);
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtrados = filtrados.where((c) {
        final marca = (c['marca'] as String?)?.toLowerCase() ?? '';
        final matricula = (c['matricula'] as String?)?.toLowerCase() ?? '';
        final modelo = (c['modelo'] as String?)?.toLowerCase() ?? '';
        return marca.contains(query) ||
            matricula.contains(query) ||
            modelo.contains(query);
      }).toList();
    }
    if (_selectedEstadoCoche != null) {
      filtrados = filtrados.where((c) {
        final estado = (c['estado_coche'] as String?)?.toLowerCase() ?? '';
        return estado == _selectedEstadoCoche!.toLowerCase();
      }).toList();
    }
    if (_filtrosActivos.isNotEmpty) {
      final precioMin = _filtrosActivos['precioMin'] as int?;
      final precioMax = _filtrosActivos['precioMax'] as int?;
      if (precioMin != null && precioMin > 0) {
        filtrados = filtrados.where((c) {
          final p = c['precio'] as num?;
          return p != null && p >= precioMin;
        }).toList();
      }
      if (precioMax != null && precioMax < 20000) {
        filtrados = filtrados.where((c) {
          final p = c['precio'] as num?;
          return p != null && p <= precioMax;
        }).toList();
      }
      final combustible = _filtrosActivos['combustible'] as String?;
      if (combustible != null && combustible.isNotEmpty) {
        filtrados =
            filtrados.where((c) => c['combustible'] == combustible).toList();
      }
      final transmision = _filtrosActivos['transmision'] as String?;
      if (transmision != null && transmision.isNotEmpty) {
        filtrados =
            filtrados.where((c) => c['transmision'] == transmision).toList();
      }
      final estadoDocs =
          (_filtrosActivos['estadoDocumentos'] as String?)?.toLowerCase();
      if (estadoDocs != null && estadoDocs.isNotEmpty) {
        filtrados = filtrados.where((c) {
          final valor = (c['estado_documentos'] as String?)?.toLowerCase();
          return valor == estadoDocs;
        }).toList();
      }
      final estadoPub =
          (_filtrosActivos['estadoPublicacion'] as String?)?.toLowerCase();
      if (estadoPub != null && estadoPub.isNotEmpty) {
        filtrados = filtrados.where((c) {
          final valor = (c['estado_publicacion'] as String?)?.toLowerCase();
          return valor == estadoPub;
        }).toList();
      }
      final itvEstado = _filtrosActivos['itvEstado'] as String?;
      if (itvEstado != null && itvEstado.isNotEmpty) {
        final hoy = DateTime.now();
        filtrados = filtrados.where((c) {
          final fechaItvStr = c['fecha_itv'] as String?;
          if (fechaItvStr == null) return false;
          try {
            final fechaItv = DateTime.parse(fechaItvStr);
            if (itvEstado == 'VIGENTE') {
              return fechaItv.isAfter(hoy) || fechaItv.isAtSameMomentAs(hoy);
            } else if (itvEstado == 'VENCIDA') {
              return fechaItv.isBefore(hoy);
            }
          } catch (_) {}
          return false;
        }).toList();
      }
    }
    setState(() => _cochesFiltrados = filtrados);
  }

  Future<void> _abrirFiltros() async {
    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => FiltrosAdicionalesDialog(
        initialPrecioMin: _filtrosActivos['precioMin'] as int?,
        initialPrecioMax: _filtrosActivos['precioMax'] as int?,
        initialCombustible: _filtrosActivos['combustible'] as String?,
        initialTransmision: _filtrosActivos['transmision'] as String?,
        initialItvEstado: _filtrosActivos['itvEstado'] as String?,
        initialEstadoDocumentos: _filtrosActivos['estadoDocumentos'] as String?,
        initialEstadoPublicacion:
            _filtrosActivos['estadoPublicacion'] as String?,
      ),
    );
    if (resultado != null && mounted) {
      setState(() => _filtrosActivos = resultado);
      _aplicarFiltrosYBusqueda();
    }
  }

  Future<void> _refreshWithoutScrollLoss() async {
    if (!mounted || !_scrollController.hasClients) return;
    final double currentOffset = _scrollController.offset;
    setState(() => _isLoading = true);
    await _loadCoches();
    setState(() => _isLoading = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(currentOffset);
      }
    });
  }

  Future<void> _refreshSingleCar(int carId) async {
    try {
      final updated = await Supabase.instance.client
          .from('coches')
          .select()
          .eq('id', carId)
          .single();
      if (!mounted) return;
      final indexFull = _coches.indexWhere((c) => c['id'] == carId);
      if (indexFull != -1) _coches[indexFull] = updated;
      final indexFiltered =
          _cochesFiltrados.indexWhere((c) => c['id'] == carId);
      if (indexFiltered != -1) _cochesFiltrados[indexFiltered] = updated;
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al refrescar coche: $e')),
        );
      }
    }
  }

  Widget _buildFilterButton(String label) {
    final isSelected = _selectedEstadoCoche == label;
    return Expanded(
      child: SizedBox(
        height: 30.0,
        child: ChoiceChip(
          label: Container(
            width: double.infinity,
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          selected: isSelected,
          onSelected: (selected) {
            setState(() => _selectedEstadoCoche = selected ? label : null);
            _aplicarFiltrosYBusqueda();
          },
          backgroundColor:
              isSelected ? const Color(0xFF0053A0) : Colors.grey.shade200,
          selectedColor: const Color(0xFF0053A0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
            side: BorderSide(
              color:
                  isSelected ? const Color(0xFF0053A0) : Colors.grey.shade400,
              width: 1.0,
            ),
          ),
          showCheckmark: false,
          padding: EdgeInsets.zero,
          labelPadding: const EdgeInsets.symmetric(horizontal: 4.0),
        ),
      ),
    );
  }

  Widget _buildRoundButton(
    BuildContext context,
    IconData icon,
    VoidCallback? onPressed, {
    Widget? child,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        shape: const CircleBorder(
            side: BorderSide(color: Color(0xFF0053A0), width: 1.0)),
        padding: const EdgeInsets.all(4.0),
        minimumSize: Size(kIsWeb ? 36.0 : 36.0, kIsWeb ? 36.0 : 36.0),
        backgroundColor: const Color(0xFF1A6BB8),
      ),
      child:
          child ?? Icon(icon, size: kIsWeb ? 18.0 : 18.0, color: Colors.white),
    );
  }

  // ==================== TARJETA PARA WEB (MEJOR ESPACIADO VERTICAL) ====================
  Widget _buildWebCarCard(BuildContext context, int index) {
    final coche = _cochesFiltrados[index];
    final matricula = coche['matricula']?.toString() ?? '—';
    final marca = coche['marca']?.toString() ?? '—';
    final modelo = coche['modelo']?.toString() ?? '—';
    final estado = coche['estado_coche']?.toString() ?? '—';
    final precio = coche['precio']?.toString() ?? '—';
    final fechaMat = coche['fecha_matriculacion']?.toString() ?? '—';
    final fechaItvRaw = coche['fecha_itv']?.toString() ?? '—';
    final ubicacion = coche['ubicacion']?.toString() ?? '—';
    final ubicacionUpdate = coche['ubicacion_update']?.toString();
    final km = coche['km']?.toString() ?? '—';
    final imagenUrl = coche['imagen_url']?.toString();
    String ubicacionDisplay = ubicacion == '—' ? '—' : ubicacion;
    if (!ubicacion.toLowerCase().trim().startsWith('prestado') &&
        ubicacionUpdate != null &&
        ubicacionUpdate.isNotEmpty) {
      try {
        final updateDate = DateTime.parse(ubicacionUpdate).toLocal();
        ubicacionDisplay += ' ${DateFormat('dd-MMM').format(updateDate)}';
      } catch (_) {}
    }
    String anoMat = '—';
    if (fechaMat != '—' && fechaMat.isNotEmpty) {
      try {
        anoMat = DateFormat('yyyy').format(DateTime.parse(fechaMat));
      } catch (_) {
        anoMat = fechaMat;
      }
    }
    String fechaItv = '—';
    if (fechaItvRaw != '—' && fechaItvRaw.isNotEmpty) {
      try {
        fechaItv = DateFormat('dd/MM/yy').format(DateTime.parse(fechaItvRaw));
      } catch (_) {
        fechaItv = fechaItvRaw;
      }
    }
    Color estadoColor = Colors.black;
    switch (estado.toLowerCase()) {
      case 'por llegar':
        estadoColor = const Color(0xFF0053A0);
        break;
      case 'disponible':
        estadoColor = Colors.green.shade600;
        break;
      case 'reservado':
        estadoColor = Colors.amber.shade700;
        break;
      case 'vendido':
        estadoColor = Colors.red.shade600;
        break;
    }
    EdgeInsets cardMargin;
    const double baseMargin = 1.0;
    const double extraEdgeMargin = 4.0;
    if (index % 4 == 0) {
      cardMargin = const EdgeInsets.fromLTRB(
          baseMargin + extraEdgeMargin, 1.0, baseMargin, 1.0);
    } else if (index % 4 == 3) {
      cardMargin = const EdgeInsets.fromLTRB(
          baseMargin, 1.0, baseMargin + extraEdgeMargin, 1.0);
    } else {
      cardMargin = const EdgeInsets.fromLTRB(baseMargin, 1.0, baseMargin, 1.0);
    }
    return GestureDetector(
      onTap: () async {
        final updatedCoche = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (context) => DataEditButton(
              id: coche['id'] as int,
              matricula: matricula,
              estadoCoche: estado),
        );
        if (updatedCoche != null && mounted) {
          final indexFull = _coches.indexWhere((c) => c['id'] == coche['id']);
          if (indexFull != -1)
            _coches[indexFull] = {..._coches[indexFull], ...updatedCoche};
          final indexFiltered =
              _cochesFiltrados.indexWhere((c) => c['id'] == coche['id']);
          if (indexFiltered != -1) {
            _cochesFiltrados[indexFiltered] = {
              ..._cochesFiltrados[indexFiltered],
              ...updatedCoche
            };
          }
          setState(() {});
        }
      },
      child: Card(
        elevation: 4.0,
        margin: cardMargin,
        color: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
          side: BorderSide(color: Colors.grey, width: 1.0),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isVeryNarrow = constraints.maxWidth < 260;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 6, // Mejor equilibrio con el contenido inferior
                  child: Container(
                    color: Colors.grey.shade200,
                    child: Center(
                      child: FractionallySizedBox(
                        widthFactor: 0.81,
                        child: imagenUrl != null && imagenUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: imagenUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                placeholder: (_, __) => const Icon(
                                    Icons.car_rental,
                                    size: 80,
                                    color: Colors.grey),
                                errorWidget: (_, __, ___) => const Icon(
                                    Icons.broken_image,
                                    size: 80,
                                    color: Colors.grey),
                              )
                            : const Icon(Icons.directions_car,
                                size: 80, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8.0, 8.0, 5.0, 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment
                                .spaceBetween, // ← Distribución vertical mejorada
                            children: [
                              Text(
                                matricula,
                                style: const TextStyle(
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              Row(
                                children: [
                                  Text(
                                    marca,
                                    style: const TextStyle(
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      modelo,
                                      style: const TextStyle(fontSize: 14.0),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Flexible(
                                      flex: 1,
                                      child: Text(anoMat,
                                          style: TextStyle(
                                              fontSize:
                                                  isVeryNarrow ? 10.5 : 11.5),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1)),
                                  const Text(" • ",
                                      style: TextStyle(
                                          fontSize: 11, color: Colors.grey)),
                                  Flexible(
                                      flex: 2,
                                      child: Text(
                                          fechaItv == '—'
                                              ? 'ITV —'
                                              : 'ITV $fechaItv',
                                          style: TextStyle(
                                              fontSize:
                                                  isVeryNarrow ? 10.5 : 11.5),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1)),
                                  const Text(" • ",
                                      style: TextStyle(
                                          fontSize: 11, color: Colors.grey)),
                                  Flexible(
                                      flex: 1,
                                      child: Text(
                                          precio == '—' ? '—' : '€ $precio',
                                          style: TextStyle(
                                              fontSize:
                                                  isVeryNarrow ? 10.5 : 11.5,
                                              color: const Color(0xFF0053A0),
                                              fontWeight: FontWeight.w500),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1)),
                                  const Text(" • ",
                                      style: TextStyle(
                                          fontSize: 11, color: Colors.grey)),
                                  Flexible(
                                      flex: 2,
                                      child: Text(km == '—' ? '—' : 'KM $km',
                                          style: TextStyle(
                                              fontSize:
                                                  isVeryNarrow ? 10.5 : 11.5),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1)),
                                ],
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.location_on,
                                      size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      ubicacionDisplay,
                                      style: const TextStyle(fontSize: 12.0),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              Center(
                                child: Text(
                                  estado,
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: estadoColor),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            StreamBuilder<Map<String, dynamic>?>(
                              stream: Stream.fromFuture(
                                Supabase.instance.client
                                    .from('coches')
                                    .select()
                                    .eq('id', coche['id'])
                                    .single()
                                    .then((data) => data)
                                    .catchError((e) {
                                  debugPrint(
                                      'Error cargando datos para PDF: $e');
                                  return <String, dynamic>{};
                                }),
                              ),
                              builder: (context, snapshot) {
                                final isLoading =
                                    !snapshot.hasData && !snapshot.hasError;
                                final hasError = snapshot.hasError;
                                return _buildRoundButton(
                                  context,
                                  Icons.picture_as_pdf,
                                  isLoading || hasError
                                      ? null
                                      : () async {
                                          final data = snapshot.data ?? coche;
                                          await showDialog(
                                              context: context,
                                              builder: (context) =>
                                                  PdfEditButton(
                                                      cocheData: data));
                                          if (mounted)
                                            await _refreshSingleCar(
                                                coche['id'] as int);
                                        },
                                  child: isLoading
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.white)))
                                      : null,
                                );
                              },
                            ),
                            const SizedBox(height: 6.0),
                            _buildRoundButton(
                              context,
                              Icons.location_on,
                              () async {
                                final exito = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => UbicacionEditButton(
                                    cocheId: coche['id']?.toString(),
                                    currentUbicacion: ubicacion,
                                  ),
                                );
                                if (mounted && exito == true) {
                                  await _refreshSingleCar(coche['id'] as int);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.primaryColor,
      body: SafeArea(
        child: Column(
          children: [
            // Barra superior
            Container(
              color: theme.primaryColor,
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 35.2,
                    height: 35.2,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.add,
                          size: 19.2, color: Colors.white),
                      onPressed: () async {
                        final exito = await showDialog<bool>(
                          context: context,
                          builder: (context) => const AddCarForm(),
                        );
                        if (exito == true && mounted)
                          await _refreshWithoutScrollLoss();
                      },
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Container(
                      height: 35.0,
                      margin: const EdgeInsets.symmetric(vertical: 1.5),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(
                            color: Colors.black, fontSize: 14.0),
                        decoration: const InputDecoration(
                          hintText: 'Buscar por marca, modelo o matrícula',
                          hintStyle:
                              TextStyle(color: Colors.grey, fontSize: 13.0),
                          prefixIcon: Icon(Icons.search,
                              color: Colors.grey, size: 20.0),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12.0, vertical: 6.0),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(8.0)),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  SizedBox(
                    width: 35.2,
                    height: 35.2,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.filter_list,
                          size: 19.2, color: Colors.white),
                      onPressed: _abrirFiltros,
                    ),
                  ),
                ],
              ),
            ),
            // Filtros de estado
            Container(
              color: theme.scaffoldBackgroundColor,
              padding:
                  const EdgeInsets.symmetric(vertical: 3.0, horizontal: 3.0),
              child: Row(
                children: [
                  _buildFilterButton('POR LLEGAR'),
                  const SizedBox(width: 3.0),
                  _buildFilterButton('DISPONIBLE'),
                  const SizedBox(width: 3.0),
                  _buildFilterButton('RESERVADO'),
                  const SizedBox(width: 3.0),
                  _buildFilterButton('VENDIDO'),
                ],
              ),
            ),
            // Contenido principal
            Expanded(
              child: Container(
                color: theme.scaffoldBackgroundColor,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _cochesFiltrados.isEmpty
                        ? const Center(
                            child: Text(
                              'No hay vehículos que coincidan con la búsqueda o filtros.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _refreshWithoutScrollLoss,
                            child: kIsWeb
                                ? GridView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.all(4.0),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 4,
                                      childAspectRatio: 1.20,
                                      crossAxisSpacing: 4.0,
                                      mainAxisSpacing: 4.0,
                                    ),
                                    itemCount: _cochesFiltrados.length,
                                    itemBuilder: (context, index) =>
                                        _buildWebCarCard(context, index),
                                  )
                                : ListView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 3.0, vertical: 0.0),
                                    itemCount: _cochesFiltrados.length,
                                    itemBuilder: (context, index) {
                                      // ... (el ListView para móvil se mantiene igual)
                                      final coche = _cochesFiltrados[index];
                                      final matricula =
                                          coche['matricula']?.toString() ?? '—';
                                      final marca =
                                          coche['marca']?.toString() ?? '—';
                                      final modelo =
                                          coche['modelo']?.toString() ?? '—';
                                      final estado =
                                          coche['estado_coche']?.toString() ??
                                              '—';
                                      final precio =
                                          coche['precio']?.toString() ?? '—';
                                      final fechaMat =
                                          coche['fecha_matriculacion']
                                                  ?.toString() ??
                                              '—';
                                      final fechaItvRaw =
                                          coche['fecha_itv']?.toString() ?? '—';
                                      final ubicacion =
                                          coche['ubicacion']?.toString() ?? '—';
                                      final ubicacionUpdate =
                                          coche['ubicacion_update']?.toString();
                                      final km = coche['km']?.toString() ?? '—';
                                      final imagenUrl =
                                          coche['imagen_url']?.toString();
                                      String ubicacionDisplay =
                                          ubicacion == '—' ? '—' : ubicacion;
                                      final ubicacionLower =
                                          ubicacion.toLowerCase().trim();
                                      final esPrestado =
                                          ubicacionLower.startsWith('prestado');
                                      if (!esPrestado &&
                                          ubicacionUpdate != null &&
                                          ubicacionUpdate.isNotEmpty) {
                                        try {
                                          final updateDate =
                                              DateTime.parse(ubicacionUpdate)
                                                  .toLocal();
                                          ubicacionDisplay +=
                                              ' ${DateFormat('dd-MMM').format(updateDate)}';
                                        } catch (_) {}
                                      }
                                      String anoMat = '—';
                                      if (fechaMat != '—' &&
                                          fechaMat.isNotEmpty) {
                                        try {
                                          anoMat = DateFormat('yyyy')
                                              .format(DateTime.parse(fechaMat));
                                        } catch (_) {
                                          anoMat = fechaMat;
                                        }
                                      }
                                      String fechaItv = '—';
                                      if (fechaItvRaw != '—' &&
                                          fechaItvRaw.isNotEmpty) {
                                        try {
                                          fechaItv = DateFormat('dd/MM/yy')
                                              .format(
                                                  DateTime.parse(fechaItvRaw));
                                        } catch (_) {
                                          fechaItv = fechaItvRaw;
                                        }
                                      }
                                      Color estadoColor = Colors.black;
                                      switch (estado.toLowerCase()) {
                                        case 'por llegar':
                                          estadoColor = const Color(0xFF0053A0);
                                          break;
                                        case 'disponible':
                                          estadoColor = Colors.green.shade600;
                                          break;
                                        case 'reservado':
                                          estadoColor = Colors.amber.shade700;
                                          break;
                                        case 'vendido':
                                          estadoColor = Colors.red.shade600;
                                          break;
                                      }
                                      return GestureDetector(
                                        onTap: () async {
                                          final updatedCoche = await showDialog<
                                              Map<String, dynamic>>(
                                            context: context,
                                            builder: (context) =>
                                                DataEditButton(
                                              id: coche['id'] as int,
                                              matricula: matricula,
                                              estadoCoche: estado,
                                            ),
                                          );
                                          if (updatedCoche != null && mounted) {
                                            final indexFull =
                                                _coches.indexWhere((c) =>
                                                    c['id'] == coche['id']);
                                            if (indexFull != -1) {
                                              _coches[indexFull] = {
                                                ..._coches[indexFull],
                                                ...updatedCoche
                                              };
                                            }
                                            final indexFiltered =
                                                _cochesFiltrados.indexWhere(
                                                    (c) =>
                                                        c['id'] == coche['id']);
                                            if (indexFiltered != -1) {
                                              _cochesFiltrados[indexFiltered] =
                                                  {
                                                ..._cochesFiltrados[
                                                    indexFiltered],
                                                ...updatedCoche
                                              };
                                            }
                                            setState(() {});
                                          }
                                        },
                                        child: Card(
                                          elevation: 4.0,
                                          margin: EdgeInsets.fromLTRB(0.0,
                                              index == 0 ? 0.0 : 1.5, 0.0, 1.5),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8.0),
                                            side: const BorderSide(
                                                color: Colors.grey, width: 1.0),
                                          ),
                                          child: Container(
                                            height: 140.0,
                                            padding: const EdgeInsets.fromLTRB(
                                                0, 0, 4.0, 0),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  margin: const EdgeInsets.only(
                                                      right: 4.0),
                                                  child: Container(
                                                    width: 130.0,
                                                    height: 140.0,
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.grey.shade200,
                                                      borderRadius:
                                                          const BorderRadius
                                                              .only(
                                                        topLeft:
                                                            Radius.circular(
                                                                8.0),
                                                        bottomLeft:
                                                            Radius.circular(
                                                                8.0),
                                                      ),
                                                    ),
                                                    child: Stack(
                                                      children: [
                                                        Center(
                                                          child: AspectRatio(
                                                            aspectRatio: 1 / 1,
                                                            child: imagenUrl !=
                                                                        null &&
                                                                    imagenUrl
                                                                        .isNotEmpty
                                                                ? Image.network(
                                                                    imagenUrl,
                                                                    fit: BoxFit
                                                                        .contain,
                                                                    errorBuilder: (_,
                                                                            __,
                                                                            ___) =>
                                                                        const Icon(
                                                                            Icons
                                                                                .broken_image,
                                                                            size:
                                                                                50,
                                                                            color:
                                                                                Colors.grey),
                                                                    loadingBuilder:
                                                                        (context,
                                                                            child,
                                                                            loadingProgress) {
                                                                      if (loadingProgress ==
                                                                          null)
                                                                        return child;
                                                                      return const Center(
                                                                          child:
                                                                              CircularProgressIndicator());
                                                                    },
                                                                  )
                                                                : const Icon(
                                                                    Icons
                                                                        .directions_car,
                                                                    size: 50,
                                                                    color: Colors
                                                                        .grey),
                                                          ),
                                                        ),
                                                        Positioned(
                                                          top: 4.0,
                                                          left: 4.0,
                                                          right: 4.0,
                                                          child: Text(
                                                            matricula,
                                                            style: const TextStyle(
                                                                fontSize: 13.0,
                                                                color: Color
                                                                    .fromARGB(
                                                                        255,
                                                                        69,
                                                                        69,
                                                                        69),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500),
                                                            textAlign: TextAlign
                                                                .center,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                        Positioned(
                                                          bottom: 4.0,
                                                          left: 4.0,
                                                          right: 4.0,
                                                          child: Text(
                                                            estado,
                                                            style: TextStyle(
                                                                fontSize: 13.0,
                                                                color:
                                                                    estadoColor),
                                                            textAlign: TextAlign
                                                                .center,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            8.0),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Text(marca,
                                                            style: const TextStyle(
                                                                fontSize: 14.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis),
                                                        Text(modelo,
                                                            style:
                                                                const TextStyle(
                                                                    fontSize:
                                                                        13.0),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis),
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              flex: 4,
                                                              child: Row(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                children: [
                                                                  const Icon(
                                                                      Icons
                                                                          .calendar_today,
                                                                      size:
                                                                          14.0,
                                                                      color: Colors
                                                                          .grey),
                                                                  const SizedBox(
                                                                      width:
                                                                          4.0),
                                                                  Text(anoMat,
                                                                      style: const TextStyle(
                                                                          fontSize:
                                                                              13.0)),
                                                                ],
                                                              ),
                                                            ),
                                                            Expanded(
                                                              flex: 6,
                                                              child: Text(
                                                                  fechaItv ==
                                                                          '—'
                                                                      ? 'ITV —'
                                                                      : 'ITV $fechaItv',
                                                                  style: const TextStyle(
                                                                      fontSize:
                                                                          13.0)),
                                                            ),
                                                          ],
                                                        ),
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              flex: 4,
                                                              child: Text(
                                                                  precio == '—'
                                                                      ? '—'
                                                                      : '€ $precio',
                                                                  style: const TextStyle(
                                                                      fontSize:
                                                                          13.0,
                                                                      color: Color(
                                                                          0xFF0053A0))),
                                                            ),
                                                            Expanded(
                                                              flex: 6,
                                                              child: Text(
                                                                  km == '—'
                                                                      ? '—'
                                                                      : 'KM $km',
                                                                  style: const TextStyle(
                                                                      fontSize:
                                                                          13.0)),
                                                            ),
                                                          ],
                                                        ),
                                                        Row(
                                                          children: [
                                                            const Icon(
                                                                Icons
                                                                    .location_on,
                                                                size: 14.0,
                                                                color: Colors
                                                                    .grey),
                                                            const SizedBox(
                                                                width: 4.0),
                                                            Expanded(
                                                              child: Text(
                                                                  ubicacionDisplay ==
                                                                          '—'
                                                                      ? '—'
                                                                      : ubicacionDisplay,
                                                                  style: const TextStyle(
                                                                      fontSize:
                                                                          13.0),
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    StreamBuilder<
                                                        Map<String, dynamic>?>(
                                                      stream: Stream.fromFuture(
                                                        Supabase.instance.client
                                                            .from('coches')
                                                            .select()
                                                            .eq('id',
                                                                coche['id'])
                                                            .single()
                                                            .then(
                                                                (data) => data)
                                                            .catchError((e) {
                                                          debugPrint(
                                                              'Error cargando datos para PDF: $e');
                                                          return <String,
                                                              dynamic>{};
                                                        }),
                                                      ),
                                                      builder:
                                                          (context, snapshot) {
                                                        final isLoading =
                                                            !snapshot.hasData &&
                                                                !snapshot
                                                                    .hasError;
                                                        final hasError =
                                                            snapshot.hasError;
                                                        return _buildRoundButton(
                                                          context,
                                                          Icons.picture_as_pdf,
                                                          isLoading || hasError
                                                              ? null
                                                              : () async {
                                                                  final data =
                                                                      snapshot.data ??
                                                                          coche;
                                                                  await showDialog(
                                                                      context:
                                                                          context,
                                                                      builder: (context) =>
                                                                          PdfEditButton(
                                                                              cocheData: data));
                                                                  if (mounted)
                                                                    await _refreshSingleCar(
                                                                        coche['id']
                                                                            as int);
                                                                },
                                                          child: isLoading
                                                              ? const SizedBox(
                                                                  width: 16,
                                                                  height: 16,
                                                                  child: CircularProgressIndicator(
                                                                      strokeWidth:
                                                                          2,
                                                                      valueColor: AlwaysStoppedAnimation<
                                                                              Color>(
                                                                          Colors
                                                                              .white)))
                                                              : null,
                                                        );
                                                      },
                                                    ),
                                                    const SizedBox(height: 1.0),
                                                    _buildRoundButton(
                                                      context,
                                                      Icons.location_on,
                                                      () async {
                                                        final exito =
                                                            await showDialog<
                                                                bool>(
                                                          context: context,
                                                          builder: (context) =>
                                                              UbicacionEditButton(
                                                            cocheId: coche['id']
                                                                ?.toString(),
                                                            currentUbicacion:
                                                                ubicacion,
                                                          ),
                                                        );
                                                        if (mounted &&
                                                            exito == true) {
                                                          await _refreshSingleCar(
                                                              coche['id']
                                                                  as int);
                                                        }
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
