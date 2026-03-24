import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../main.dart'; // Tus AppColors y AppConstants

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedTab = 0;
  List<Map<String, dynamic>> _cochesInventario = [];
  List<Map<String, dynamic>> _cochesVendidos = [];

  // Inventario
  Map<String, int> _conteoDias = {'0-15': 0, '16-30': 0, '30+': 0};
  String? _filtroDias;
  String? _filtroUbicacion;

  // Ventas
  final Map<int, Map<String, dynamic>> _ventasComparativa = {};
  String? _filtroMesKey;
  String _yearFilter = '2026';
  bool _isLoading = true;

  // Usuarios autorizados para ver el tab de Ventas
  final List<String> _usuariosAutorizadosVentas = [
    '0e507c01-505b-430f-963f-4929687cbe47',
    'f7968c62-5b16-49b6-80d9-b7ec461bdb57',
    'e95175b6-451b-469c-ad37-09404aa492df',
    'ab193932-356f-4753-9f86-f98c2ef5d6c8',
  ];

  bool get _puedeVerVentas {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;
    return _usuariosAutorizadosVentas.contains(user.id);
  }

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final inv = await supabase
          .from('coches')
          .select()
          .inFilter('estado_coche', ['Disponible', 'Reservado']);

      final ven = await supabase
          .from('coches')
          .select()
          .eq('estado_coche', 'Vendido')
          .order('fecha_venta', ascending: false);

      _cochesInventario = List.from(inv);
      _cochesVendidos = List.from(ven);

      _procesarInventario();
      _procesarVentasComparativa();
    } catch (e) {
      debugPrint('Error dashboard: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _procesarInventario() {
    final hoy = DateTime.now();
    _conteoDias = {'0-15': 0, '16-30': 0, '30+': 0};
    for (var c in _cochesInventario) {
      final fechaStr = c['ubicacion_update'] as String?;
      final dias = fechaStr == null
          ? 999
          : hoy.difference(DateTime.parse(fechaStr)).inDays;

      if (dias <= 15) {
        _conteoDias['0-15'] = (_conteoDias['0-15'] ?? 0) + 1;
      } else if (dias <= 30) {
        _conteoDias['16-30'] = (_conteoDias['16-30'] ?? 0) + 1;
      } else {
        _conteoDias['30+'] = (_conteoDias['30+'] ?? 0) + 1;
      }
    }
  }

  void _procesarVentasComparativa() {
    _ventasComparativa.clear();
    for (var c in _cochesVendidos) {
      final fechaStr = c['fecha_venta'] as String?;
      if (fechaStr == null) continue;
      final fecha = DateTime.parse(fechaStr);
      final mes = fecha.month;
      final precio = (c['precio_final'] as num?)?.toDouble() ?? 0.0;

      _ventasComparativa.putIfAbsent(
        mes,
        () => {
          '2025_total': 0.0,
          '2026_total': 0.0,
          '2025_count': 0,
          '2026_count': 0,
        },
      );

      if (fecha.year == 2025) {
        _ventasComparativa[mes]!['2025_total'] += precio;
        _ventasComparativa[mes]!['2025_count'] += 1;
      } else if (fecha.year == 2026) {
        _ventasComparativa[mes]!['2026_total'] += precio;
        _ventasComparativa[mes]!['2026_count'] += 1;
      }
    }
  }

  String _getCategoriaUbicacion(String? ubicacion) {
    if (ubicacion == null) return 'Otros';
    final u = ubicacion.trim().toUpperCase();

    if (u.startsWith('PRESTADO')) return 'Prestado';

    const malagaKeys = [
      'CURVA',
      'LINEA',
      'PALENQUE',
      'DECATHLON',
      'ESCUELA',
      'IGLESIA',
      'GUITARRERO',
      'AV. VILLA ROSA',
      'VILLA ROSA'
    ];
    if (malagaKeys.any((key) => u.contains(key))) return 'Málaga';

    const algarroboKeys = ['POLÍGONO', 'EXPLANADA', 'MEZQUITILLA', 'CHILCHES'];
    if (algarroboKeys.any((key) => u.contains(key))) return 'Algarrobo';

    return 'Otros';
  }

  List<Map<String, dynamic>> get _inventarioFiltrado {
    var lista = List<Map<String, dynamic>>.from(_cochesInventario);

    if (_filtroDias != null) {
      final hoy = DateTime.now();
      lista.retainWhere((c) {
        final fechaStr = c['ubicacion_update'] as String?;
        if (fechaStr == null) return _filtroDias == '30+';
        final dias = hoy.difference(DateTime.parse(fechaStr)).inDays;
        if (_filtroDias == '0-15') return dias <= 15;
        if (_filtroDias == '16-30') return dias > 15 && dias <= 30;
        return dias > 30;
      });
    }

    if (_filtroUbicacion != null) {
      lista.retainWhere((c) {
        final cat = _getCategoriaUbicacion(c['ubicacion'] as String?);
        return cat == _filtroUbicacion;
      });
    }

    lista.sort((a, b) =>
        (b['ubicacion_update'] ?? '').compareTo(a['ubicacion_update'] ?? ''));
    return lista;
  }

  List<Map<String, dynamic>> get _ventasFiltradas {
    var lista = List<Map<String, dynamic>>.from(_cochesVendidos);
    if (_filtroMesKey != null) {
      final prefix = _filtroMesKey!.substring(0, 7);
      lista = lista.where((c) {
        final fechaStr = c['fecha_venta'] as String?;
        return fechaStr != null && fechaStr.startsWith(prefix);
      }).toList();
    }
    if (_yearFilter != 'Ambos') {
      lista = lista.where((c) {
        final fechaStr = c['fecha_venta'] as String?;
        if (fechaStr == null) return false;
        final year = DateTime.parse(fechaStr).year.toString();
        return year == _yearFilter;
      }).toList();
    }
    return lista;
  }

  int get _conteoFilasFiltradas => _ventasFiltradas.length;

  double get _sumaPreciosFiltrados {
    return _ventasFiltradas.fold(0.0, (sum, c) {
      final precio = (c['precio_final'] as num?)?.toDouble() ?? 0.0;
      return sum + precio;
    });
  }

  double get _precioPromedio {
    final conteo = _conteoFilasFiltradas;
    if (conteo == 0) return 0.0;
    return _sumaPreciosFiltrados / conteo;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_puedeVerVentas && _selectedTab == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedTab = 0);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        centerTitle: true,
        toolbarHeight: 40,
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: theme.scaffoldBackgroundColor,
              padding:
                  const EdgeInsets.symmetric(vertical: 3.0, horizontal: 4.0),
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
                            'INVENTARIO',
                            style: TextStyle(
                                fontSize: 12.0, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        selected: _selectedTab == 0,
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedTab = 0);
                        },
                        labelStyle: TextStyle(
                          color:
                              _selectedTab == 0 ? Colors.white : Colors.black87,
                        ),
                        backgroundColor: Colors.grey.shade200,
                        selectedColor: const Color(0xFF0053A0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          side: BorderSide(
                            color: _selectedTab == 0
                                ? const Color(0xFF0053A0)
                                : Colors.grey.shade400,
                            width: 1.0,
                          ),
                        ),
                        showCheckmark: false,
                        padding: EdgeInsets.zero,
                        labelPadding:
                            const EdgeInsets.symmetric(horizontal: 4.0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 3.0),
                  if (_puedeVerVentas)
                    Expanded(
                      child: SizedBox(
                        height: 30.0,
                        child: ChoiceChip(
                          label: Container(
                            width: double.infinity,
                            alignment: Alignment.center,
                            child: const Text(
                              'VENTAS',
                              style: TextStyle(
                                  fontSize: 12.0, fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          selected: _selectedTab == 1,
                          onSelected: (selected) {
                            if (selected) setState(() => _selectedTab = 1);
                          },
                          labelStyle: TextStyle(
                            color: _selectedTab == 1
                                ? Colors.white
                                : Colors.black87,
                          ),
                          backgroundColor: Colors.grey.shade200,
                          selectedColor: const Color(0xFF0053A0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            side: BorderSide(
                              color: _selectedTab == 1
                                  ? const Color(0xFF0053A0)
                                  : Colors.grey.shade400,
                              width: 1.0,
                            ),
                          ),
                          showCheckmark: false,
                          padding: EdgeInsets.zero,
                          labelPadding:
                              const EdgeInsets.symmetric(horizontal: 4.0),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                color: const Color(0xFFE6F0FA),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _selectedTab == 0
                        ? _buildInventarioTab()
                        : _buildVentasTab(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== INVENTARIO ====================
  Widget _buildInventarioTab() {
    return Column(
      children: [
        Expanded(flex: 5, child: _buildGraficoInventario()),
        Expanded(flex: 5, child: _buildListaInventario()),
      ],
    );
  }

  Widget _buildGraficoInventario() {
    final total =
        _conteoDias['0-15']! + _conteoDias['16-30']! + _conteoDias['30+']!;
    if (total == 0) {
      return const Center(
          child: Text('No hay datos', style: TextStyle(fontSize: 16)));
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(4, 0, 4, 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(
            color: Color.fromARGB(255, 189, 189, 189), width: 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          children: [
            const Text(
              'Status Inventario',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 6,
                    child: Center(
                      child: Container(
                        constraints:
                            const BoxConstraints(maxWidth: 210, maxHeight: 210),
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 35,
                            startDegreeOffset: -90,
                            sections: [
                              PieChartSectionData(
                                value: _conteoDias['0-15']!.toDouble(),
                                color: AppColors.estadoDisponible,
                                title: _conteoDias['0-15']! > 0
                                    ? '${_conteoDias['0-15']}'
                                    : '',
                                radius: 65,
                                titleStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                              PieChartSectionData(
                                value: _conteoDias['16-30']!.toDouble(),
                                color: AppColors.estadoReservado,
                                title: _conteoDias['16-30']! > 0
                                    ? '${_conteoDias['16-30']}'
                                    : '',
                                radius: 65,
                                titleStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                              PieChartSectionData(
                                value: _conteoDias['30+']!.toDouble(),
                                color: AppColors.estadoVendido,
                                title: _conteoDias['30+']! > 0
                                    ? '${_conteoDias['30+']}'
                                    : '',
                                radius: 65,
                                titleStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                            ],
                            // === CAMBIO AQUÍ ===
                            // Se elimina completamente el pieTouchData para que no haya interacción
                            pieTouchData: PieTouchData(enabled: false),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 125,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildFilterChip(
                            '0-15 días', '0-15', AppColors.estadoDisponible),
                        const SizedBox(height: 10),
                        _buildFilterChip(
                            '16-30 días', '16-30', AppColors.estadoReservado),
                        const SizedBox(height: 10),
                        _buildFilterChip(
                            '30+ días', '30+', AppColors.estadoVendido),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildUbicacionChip('Málaga')),
                const SizedBox(width: 6),
                Expanded(child: _buildUbicacionChip('Algarrobo')),
                const SizedBox(width: 6),
                Expanded(child: _buildUbicacionChip('Prestado')),
                const SizedBox(width: 6),
                Expanded(child: _buildUbicacionChip('Otros')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String key, Color color) {
    final isSelected = _filtroDias == key;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filtroDias = selected ? key : null;
        });
      },
      avatar: CircleAvatar(
        backgroundColor: color,
        radius: 9,
        child: isSelected
            ? const Icon(Icons.check, size: 12, color: Colors.white)
            : null,
      ),
      selectedColor: color.withValues(alpha: 0.18),
      backgroundColor: Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? color : Colors.grey.shade300,
          width: isSelected ? 1.6 : 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      labelPadding: const EdgeInsets.only(left: 6, right: 10),
    );
  }

  Widget _buildUbicacionChip(String label) {
    final isSelected = _filtroUbicacion == label;
    return FilledButton(
      onPressed: () {
        setState(() {
          _filtroUbicacion = isSelected ? null : label;
        });
      },
      style: FilledButton.styleFrom(
        backgroundColor:
            isSelected ? const Color(0xFF0053A0) : Colors.grey.shade200,
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        elevation: 0,
        minimumSize: const Size.fromHeight(38),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
        ),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  Widget _buildListaInventario() {
    return Card(
      margin: const EdgeInsets.fromLTRB(4, 0, 4, 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(
            color: Color.fromARGB(255, 189, 189, 189), width: 1.0),
      ),
      child: _inventarioFiltrado.isEmpty
          ? const Center(child: Text('No hay coches con este filtro'))
          : ListView.separated(
              itemCount: _inventarioFiltrado.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                thickness: 1,
                color: Color(0xFFE0E0E0),
                indent: 16,
                endIndent: 16,
              ),
              itemBuilder: (context, i) {
                final c = _inventarioFiltrado[i];
                final fechaUpdate = c['ubicacion_update'] as String?;
                final fechaStr = fechaUpdate != null
                    ? DateFormat('dd-MM-yyyy')
                        .format(DateTime.parse(fechaUpdate))
                    : 'sin fecha';

                String ubicacionMostrada = c['ubicacion']?.toString() ?? '—';
                if (ubicacionMostrada.startsWith('Prestado')) {
                  final partes = ubicacionMostrada.split('-');
                  if (partes.length >= 2) {
                    ubicacionMostrada = partes.skip(1).join('-').trim();
                  }
                }

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${c['marca'] ?? ''} ${c['modelo'] ?? ''}'.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  (c['matricula'] as String?)?.toUpperCase() ??
                                      'Sin matrícula',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'últ. mov. el $fechaStr',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Text(
                        ubicacionMostrada,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E88E5),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // ==================== VENTAS ====================
  Widget _buildVentasTab() {
    final maxYRaw = _ventasComparativa.values
        .map((v) => (v['2025_total'] as double) + (v['2026_total'] as double))
        .fold(0.0, (a, b) => a > b ? a : b);
    final maxY = maxYRaw * 1.18;
    final conteo = _conteoFilasFiltradas;
    final suma = _sumaPreciosFiltrados;
    final promedio = _precioPromedio;
    final euroFormat =
        NumberFormat.currency(locale: 'es_ES', symbol: '€', decimalDigits: 0);
    final String ventasValue = '$conteo';

    return Column(
      children: [
        Expanded(
          flex: 5,
          child: Card(
            margin: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(
                  color: Color.fromARGB(255, 189, 189, 189), width: 1.0),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 40,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Center(
                          child: Text(
                            'Ventas',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: DropdownButton<String>(
                              value: _yearFilter,
                              icon: const Icon(Icons.filter_list,
                                  color: AppColors.primaryBlue),
                              underline: Container(
                                  height: 2, color: AppColors.primaryBlue),
                              items: const [
                                DropdownMenuItem(
                                    value: '2025', child: Text('2025')),
                                DropdownMenuItem(
                                    value: '2026', child: Text('2026')),
                                DropdownMenuItem(
                                    value: 'Ambos', child: Text('Ambos')),
                              ],
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() => _yearFilter = newValue);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceBetween,
                        groupsSpace: 24,
                        maxY: maxY,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) =>
                                Colors.black.withValues(alpha: 0.8),
                            tooltipRoundedRadius: 8,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final mes = group.x;
                              final year = rodIndex == 0 ? '2025' : '2026';
                              final value = rod.toY;
                              return BarTooltipItem(
                                '$mes/$year\n€ ${NumberFormat('#,##0').format(value.toInt())}',
                                const TextStyle(
                                    color: Colors.white, fontSize: 13),
                              );
                            },
                          ),
                        ),
                        barGroups: List.generate(12, (i) {
                          final mes = i + 1;
                          final data = _ventasComparativa[mes];
                          final t25 = data?['2025_total'] as double? ?? 0.0;
                          final t26 = data?['2026_total'] as double? ?? 0.0;
                          final isSelected = _filtroMesKey
                                  ?.endsWith(mes.toString().padLeft(2, '0')) ==
                              true;

                          return BarChartGroupData(
                            x: mes,
                            barRods: [
                              BarChartRodData(
                                toY: t25,
                                color: isSelected
                                    ? Colors.blue.shade700
                                    : Colors.blue.shade400,
                                width: 14,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6)),
                              ),
                              BarChartRodData(
                                toY: t26,
                                color: isSelected
                                    ? AppColors.estadoVendido
                                        .withValues(alpha: 0.85)
                                    : AppColors.estadoVendido,
                                width: 14,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6)),
                              ),
                            ],
                          );
                        }),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) {
                                final mes = value.toInt();
                                final monthStr = DateFormat('MMM', 'es')
                                    .format(DateTime(2026, mes));
                                final isSelected = _filtroMesKey?.endsWith(
                                        mes.toString().padLeft(2, '0')) ==
                                    true;

                                return GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    setState(() {
                                      final selectedYear =
                                          _yearFilter == 'Ambos'
                                              ? '2026'
                                              : _yearFilter;
                                      final newKey =
                                          '$selectedYear-${mes.toString().padLeft(2, '0')}';
                                      _filtroMesKey = (_filtroMesKey == newKey)
                                          ? null
                                          : newKey;
                                    });
                                  },
                                  child: Container(
                                    width: 30,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 1, horizontal: 1),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.estadoVendido
                                              .withValues(alpha: 0.15)
                                          : null,
                                      borderRadius: BorderRadius.circular(12),
                                      border: isSelected
                                          ? Border.all(
                                              color: AppColors.estadoVendido,
                                              width: 2)
                                          : Border.all(
                                              color: Colors.grey.shade300,
                                              width: 1),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      monthStr,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? AppColors.estadoVendido
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: const FlGridData(
                            show: true, drawVerticalLine: false),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                          child: _buildStatCard(
                              title: 'Ventas',
                              value: ventasValue,
                              color: Colors.blue.shade700)),
                      const SizedBox(width: 5),
                      Expanded(
                          child: _buildStatCard(
                              title: 'Total',
                              value: euroFormat.format(suma),
                              color: AppColors.estadoVendido)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: _buildStatCard(
                          title: 'Promedio',
                          value: conteo > 0 ? euroFormat.format(promedio) : '—',
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'Toca una etiqueta para filtrar la lista inferior',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(flex: 5, child: _buildListaVentas()),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildListaVentas() {
    return Card(
      margin: const EdgeInsets.fromLTRB(4, 0, 4, 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(
            color: Color.fromARGB(255, 189, 189, 189), width: 1.0),
      ),
      child: _ventasFiltradas.isEmpty
          ? const Center(child: Text('Toca una etiqueta en el gráfico'))
          : ListView.separated(
              itemCount: _ventasFiltradas.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                thickness: 1,
                color: Color(0xFFE0E0E0),
                indent: 16,
                endIndent: 16,
              ),
              itemBuilder: (context, i) {
                final c = _ventasFiltradas[i];
                final precio = (c['precio_final'] as num?)?.toDouble() ?? 0.0;
                final fechaVentaStr = c['fecha_venta'] as String?;
                final fechaTexto = fechaVentaStr != null
                    ? DateFormat('dd-MM-yyyy')
                        .format(DateTime.parse(fechaVentaStr))
                    : 'sin fecha';

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${c['marca'] ?? ''} ${c['modelo'] ?? ''}'.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  (c['matricula'] as String?)?.toUpperCase() ??
                                      'Sin matrícula',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'vendido el $fechaTexto',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '€ ${NumberFormat('#,##0').format(precio.toInt())}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.estadoVendido,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
