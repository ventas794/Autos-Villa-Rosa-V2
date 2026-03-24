import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../main.dart'; // Para AppColors y AppConstants
import 'dashboard_screen.dart'; // ← Importamos el nuevo dashboard

class ActividadScreen extends StatefulWidget {
  const ActividadScreen({super.key});

  @override
  State<ActividadScreen> createState() => _ActividadScreenState();
}

class _ActividadScreenState extends State<ActividadScreen> {
  List<Map<String, dynamic>> _actividades = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _hasMore = true;
  final int _pageSize = 25;
  int _currentOffset = 0;

  static const Map<String, String> _userNames = {
    'd57ace4e-6372-4d08-a9d4-62af42d1177c': 'Lahcen',
    'ab193932-356f-4753-9f86-f98c2ef5d6c8': 'Luisjavier',
    '2301aa78-4156-4cb1-a48b-a433c11bb683': 'Achraf',
    '883d3cd1-681d-44af-80cd-ba4073b07778': 'Lucia',
    'c33cecce-c95a-4cd5-93a4-547a2efb9ccd': 'Basilio',
    '0e507c01-505b-430f-963f-4929687cbe47': 'Alejandro',
    'd2d5b8a8-052f-484a-8115-46cb0939127b': 'Daniel',
    'f7968c62-5b16-49b6-80d9-b7ec461bdb57': 'Ursula',
    'e95175b6-451b-469c-ad37-09404aa492df': 'Mohammed',
    '7b96e90b-802b-4c4c-8bcc-c0d2acc60bc7': 'Abdelghani',
    '9cf5e1f2-e053-4e5d-b026-dae25befae32': 'Usuario1',
    '267dbf73-2091-41e0-9728-69b69e7d855c': 'Usuario2',
  };

  @override
  void initState() {
    super.initState();
    _loadActividades();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        !_isLoading &&
        _hasMore) {
      _loadActividades(loadMore: true);
    }
  }

  Future<void> _loadActividades({bool loadMore = false}) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final response =
          await Supabase.instance.client.from('actividad').select('''
            id, coche_id, usuario_id, campo, valor_nuevo, fecha_evento,
            coches!inner (marca, modelo, matricula)
          ''').order('fecha_evento', ascending: false).range(
                loadMore ? _currentOffset : 0,
                loadMore ? _currentOffset + _pageSize - 1 : _pageSize - 1,
              );

      final data = response as List<dynamic>? ?? [];

      if (mounted) {
        setState(() {
          if (!loadMore) {
            _actividades = List<Map<String, dynamic>>.from(data);
            _currentOffset = data.length;
          } else {
            _actividades.addAll(List<Map<String, dynamic>>.from(data));
            _currentOffset += data.length;
          }
          _hasMore = data.length == _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar actividades: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _actividades.clear();
      _currentOffset = 0;
      _hasMore = true;
    });
    await _loadActividades();
  }

  String _getActionDescription(Map<String, dynamic> act) {
    final campo = (act['campo'] as String?)?.toLowerCase() ?? 'desconocido';
    final valor = (act['valor_nuevo'] as String?)?.trim() ?? '—';

    switch (campo) {
      case 'creacion':
        return 'Añadido al stock';
      case 'ubicacion':
        return 'Movido a $valor';
      case 'estado_coche':
        final valorLower = valor.toLowerCase();
        switch (valorLower) {
          case 'disponible':
            return 'Recibido / Disponible';
          case 'reservado':
            return 'Reservado';
          case 'vendido':
            return 'Vendido';
          case 'reserva cancelada':
            return 'Reserva cancelada';
          case 'venta anulada':
            return 'Venta anulada';
          default:
            return 'Cambio de estado: $valor';
        }
      case 'fecha_cita':
        final valorLower = valor.toLowerCase();
        if (valorLower.contains('agendada') || valorLower.contains('creada')) {
          return 'Cita agendada';
        }
        if (valorLower.contains('eliminada') ||
            valorLower.contains('cancelada')) {
          return 'Cita cancelada';
        }
        try {
          final fecha = DateTime.parse(valor).toLocal();
          final hoy = DateTime.now().toLocal();
          final esHoy = fecha.day == hoy.day &&
              fecha.month == hoy.month &&
              fecha.year == hoy.year;
          final esManana = fecha.difference(hoy).inDays == 1;
          final hora = DateFormat('HH:mm').format(fecha);

          if (esHoy) return 'Cita agendada hoy $hora';
          if (esManana) return 'Cita agendada mañana $hora';
          return 'Cita agendada ${DateFormat('dd/MM/yyyy HH:mm').format(fecha)}';
        } catch (_) {
          return 'Cita modificada: $valor';
        }
      default:
        return 'Modificó $campo → $valor';
    }
  }

  Color _getActionColor(Map<String, dynamic> act) {
    final campo = (act['campo'] as String?)?.toLowerCase() ?? '';
    final valor = (act['valor_nuevo'] as String?)?.toLowerCase() ?? '';

    if (campo == 'estado_coche') {
      switch (valor) {
        case 'disponible':
          return AppColors.estadoDisponible;
        case 'reservado':
          return AppColors.estadoReservado;
        case 'vendido':
          return AppColors.estadoVendido;
        case 'reserva cancelada':
          return Colors.grey.shade700;
        case 'venta anulada':
          return Colors.orange.shade800;
        default:
          return AppColors.textAlmostBlack;
      }
    }

    if (campo == 'fecha_cita') {
      if (valor.contains('eliminada') || valor.contains('cancelada')) {
        return Colors.orange.shade700;
      }
      return AppColors.primaryBlue;
    }

    return AppColors.textAlmostBlack;
  }

  IconData _getActionIcon(Map<String, dynamic> act) {
    final campo = (act['campo'] as String?)?.toLowerCase() ?? '';
    final valor = (act['valor_nuevo'] as String?)?.toLowerCase() ?? '';

    if (campo == 'creacion') return Icons.add_circle_outline;
    if (campo == 'ubicacion') return Icons.location_on;

    if (campo == 'estado_coche') {
      switch (valor) {
        case 'disponible':
          return Icons.check_circle;
        case 'reservado':
          return Icons.lock;
        case 'vendido':
          return Icons.attach_money;
        case 'reserva cancelada':
          return Icons.undo;
        case 'venta anulada':
          return Icons.money_off;
        default:
          return Icons.change_circle;
      }
    }

    if (campo == 'fecha_cita') {
      if (valor.contains('eliminada') || valor.contains('cancelada')) {
        return Icons.event_busy;
      }
      return Icons.calendar_today;
    }

    return Icons.edit_note;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Actividad Reciente'),
        centerTitle: true,
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 40,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        leading: IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Cerrar sesión',
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Cerrar sesión'),
                content: const Text('¿Quieres cerrar sesión?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text(
                      'Salir',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            );

            if (confirmed == true) {
              await Supabase.instance.client.auth.signOut();
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard),
            tooltip: 'Ir al Dashboard',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const DashboardScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primaryBlue,
        backgroundColor: Colors.white,
        child: _isLoading && _actividades.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _actividades.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 80,
                          color: AppColors.primaryBlue.withAlpha(102),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No hay actividades recientes',
                          style: TextStyle(
                            fontSize: 18,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 4,
                    ),
                    itemCount:
                        _actividades.length + (_hasMore && _isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _actividades.length) {
                        return const Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final act = _actividades[index];
                      final coche =
                          act['coches'] as Map<String, dynamic>? ?? {};
                      final userId = act['usuario_id'] as String?;
                      final userName =
                          _userNames[userId] ?? 'Usuario desconocido';

                      final fechaRaw = act['fecha_evento'] as String?;
                      final fecha = fechaRaw != null
                          ? DateTime.parse(fechaRaw).toLocal()
                          : DateTime.now();
                      final fechaStr =
                          DateFormat('dd/MM/yyyy HH:mm').format(fecha);

                      final description = _getActionDescription(act);
                      final color = _getActionColor(act);
                      final icon = _getActionIcon(act);

                      return SizedBox(
                        height: 82.5,
                        child: Card(
                          elevation: 4.0,
                          margin: const EdgeInsets.fromLTRB(4, 2, 4, 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            contentPadding:
                                const EdgeInsets.fromLTRB(8, 6, 8, 6),
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: color.withAlpha(38),
                              child: Icon(icon, color: color, size: 26),
                            ),
                            title: Text(
                              description,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${coche['matricula'] ?? '—'} • ${coche['marca'] ?? ''} ${coche['modelo'] ?? ''}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    '$userName • $fechaStr',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
