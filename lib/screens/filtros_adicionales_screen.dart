import 'package:flutter/material.dart';

class FiltrosAdicionalesDialog extends StatefulWidget {
  final int? initialPrecioMin;
  final int? initialPrecioMax;
  final String? initialCombustible;
  final String? initialTransmision;
  final String? initialItvEstado;
  final String? initialEstadoDocumentos;
  final String? initialEstadoPublicacion;

  const FiltrosAdicionalesDialog({
    super.key,
    this.initialPrecioMin,
    this.initialPrecioMax,
    this.initialCombustible,
    this.initialTransmision,
    this.initialItvEstado,
    this.initialEstadoDocumentos,
    this.initialEstadoPublicacion,
  });

  @override
  State<FiltrosAdicionalesDialog> createState() =>
      _FiltrosAdicionalesDialogState();
}

class _FiltrosAdicionalesDialogState extends State<FiltrosAdicionalesDialog> {
  late RangeValues _rangoPrecio;
  late String? _combustible;
  late String? _transmision;
  late String? _estadoItv;
  late String? _estadoDocumentos;
  late String? _estadoPublicacion;

  final double _precioMin = 0;
  final double _precioMax = 20000;
  final double _divisionPrecio = 1000;
  static const double buttonHeight = 34;

  @override
  void initState() {
    super.initState();
    _rangoPrecio = RangeValues(
      widget.initialPrecioMin?.toDouble() ?? _precioMin,
      widget.initialPrecioMax?.toDouble() ?? _precioMax,
    );
    _combustible = widget.initialCombustible;
    _transmision = widget.initialTransmision;
    _estadoItv = widget.initialItvEstado;
    _estadoDocumentos = widget.initialEstadoDocumentos;
    _estadoPublicacion = widget.initialEstadoPublicacion;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    const verdeSeleccionado = Color.fromARGB(255, 0, 114, 15);
    const spacingHorizontal = 12.0;
    const sectionSpacing = 3.0;
    const smallSpacing = 3.0;

    // Opacidad 0.6 → alpha 153 (0.6 * 255 ≈ 153)
    final Color colorConOpacidad = colorScheme.onSurface.withAlpha(153);

    return AlertDialog(
      titlePadding: EdgeInsets.zero,
      title: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Filtros adicionales',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            IconButton(
              icon: const Icon(Icons.cleaning_services),
              tooltip: 'Limpiar filtros',
              color: Colors.grey[700],
              onPressed: () {
                setState(() {
                  _rangoPrecio = const RangeValues(0, 20000);
                  _combustible = null;
                  _transmision = null;
                  _estadoItv = null;
                  _estadoDocumentos = null;
                  _estadoPublicacion = null;
                });
              },
            ),
          ],
        ),
      ),
      contentPadding: EdgeInsets.zero,
      content: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Precio
              const Text('Precio (€)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              RangeSlider(
                values: _rangoPrecio,
                min: _precioMin,
                max: _precioMax,
                divisions: (_precioMax / _divisionPrecio).round(),
                activeColor: verdeSeleccionado,
                inactiveColor: Colors.grey.shade300,
                labels: RangeLabels(
                  '${_rangoPrecio.start.round()} €',
                  _rangoPrecio.end >= _precioMax
                      ? '20.000 o más'
                      : '${_rangoPrecio.end.round()} €',
                ),
                onChanged: (values) => setState(() => _rangoPrecio = values),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${_rangoPrecio.start.round()} €',
                        style: const TextStyle(fontSize: 14)),
                    Text(
                      _rangoPrecio.end >= _precioMax
                          ? '20.000 o más'
                          : '${_rangoPrecio.end.round()} €',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              SizedBox(height: sectionSpacing),

              // Combustible
              const Text('Combustible',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              SizedBox(height: smallSpacing),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: buttonHeight,
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _combustible =
                                _combustible == 'Diésel' ? null : 'Diésel';
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _combustible == 'Diésel'
                              ? verdeSeleccionado
                              : Colors.white,
                          foregroundColor: _combustible == 'Diésel'
                              ? Colors.white
                              : colorConOpacidad,
                          side: BorderSide(
                            color: _combustible == 'Diésel'
                                ? verdeSeleccionado
                                : colorScheme.outline,
                            width: 1.0,
                          ),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                        ),
                        child: const Text('Diésel',
                            style: TextStyle(fontSize: 14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: spacingHorizontal),
                  Expanded(
                    child: SizedBox(
                      height: buttonHeight,
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _combustible =
                                _combustible == 'Gasolina' ? null : 'Gasolina';
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _combustible == 'Gasolina'
                              ? verdeSeleccionado
                              : Colors.white,
                          foregroundColor: _combustible == 'Gasolina'
                              ? Colors.white
                              : colorConOpacidad,
                          side: BorderSide(
                            color: _combustible == 'Gasolina'
                                ? verdeSeleccionado
                                : colorScheme.outline,
                            width: 1.0,
                          ),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                        ),
                        child: const Text('Gasolina',
                            style: TextStyle(fontSize: 14)),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: sectionSpacing),

              // Transmisión
              const Text('Transmisión',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              SizedBox(height: smallSpacing),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: buttonHeight,
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _transmision =
                                _transmision == 'Manual' ? null : 'Manual';
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _transmision == 'Manual'
                              ? verdeSeleccionado
                              : Colors.white,
                          foregroundColor: _transmision == 'Manual'
                              ? Colors.white
                              : colorConOpacidad,
                          side: BorderSide(
                            color: _transmision == 'Manual'
                                ? verdeSeleccionado
                                : colorScheme.outline,
                            width: 1.0,
                          ),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                        ),
                        child: const Text('Manual',
                            style: TextStyle(fontSize: 14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: spacingHorizontal),
                  Expanded(
                    child: SizedBox(
                      height: buttonHeight,
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _transmision = _transmision == 'Automático'
                                ? null
                                : 'Automático';
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _transmision == 'Automático'
                              ? verdeSeleccionado
                              : Colors.white,
                          foregroundColor: _transmision == 'Automático'
                              ? Colors.white
                              : colorConOpacidad,
                          side: BorderSide(
                            color: _transmision == 'Automático'
                                ? verdeSeleccionado
                                : colorScheme.outline,
                            width: 1.0,
                          ),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                        ),
                        child: const Text('Automático',
                            style: TextStyle(fontSize: 14)),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: sectionSpacing),

              // Estado ITV
              const Text('Estado ITV',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              SizedBox(height: smallSpacing),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: buttonHeight,
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _estadoItv =
                                _estadoItv == 'VENCIDA' ? null : 'VENCIDA';
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _estadoItv == 'VENCIDA'
                              ? verdeSeleccionado
                              : Colors.white,
                          foregroundColor: _estadoItv == 'VENCIDA'
                              ? Colors.white
                              : colorConOpacidad,
                          side: BorderSide(
                            color: _estadoItv == 'VENCIDA'
                                ? verdeSeleccionado
                                : colorScheme.outline,
                            width: 1.0,
                          ),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                        ),
                        child: const Text('Vencida',
                            style: TextStyle(fontSize: 14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: spacingHorizontal),
                  Expanded(
                    child: SizedBox(
                      height: buttonHeight,
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _estadoItv =
                                _estadoItv == 'VIGENTE' ? null : 'VIGENTE';
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _estadoItv == 'VIGENTE'
                              ? verdeSeleccionado
                              : Colors.white,
                          foregroundColor: _estadoItv == 'VIGENTE'
                              ? Colors.white
                              : colorConOpacidad,
                          side: BorderSide(
                            color: _estadoItv == 'VIGENTE'
                                ? verdeSeleccionado
                                : colorScheme.outline,
                            width: 1.0,
                          ),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                        ),
                        child: const Text('Vigente',
                            style: TextStyle(fontSize: 14)),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: sectionSpacing),

              // Estado documentos
              const Text('Estado documentos',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              SizedBox(height: smallSpacing),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: buttonHeight,
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _estadoDocumentos = _estadoDocumentos == 'Pendiente'
                                ? null
                                : 'Pendiente';
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _estadoDocumentos == 'Pendiente'
                              ? verdeSeleccionado
                              : Colors.white,
                          foregroundColor: _estadoDocumentos == 'Pendiente'
                              ? Colors.white
                              : colorConOpacidad,
                          side: BorderSide(
                            color: _estadoDocumentos == 'Pendiente'
                                ? verdeSeleccionado
                                : colorScheme.outline,
                            width: 1.0,
                          ),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                        ),
                        child: const Text('Pendiente',
                            style: TextStyle(fontSize: 14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: spacingHorizontal),
                  Expanded(
                    child: SizedBox(
                      height: buttonHeight,
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _estadoDocumentos = _estadoDocumentos == 'Recibida'
                                ? null
                                : 'Recibida';
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _estadoDocumentos == 'Recibida'
                              ? verdeSeleccionado
                              : Colors.white,
                          foregroundColor: _estadoDocumentos == 'Recibida'
                              ? Colors.white
                              : colorConOpacidad,
                          side: BorderSide(
                            color: _estadoDocumentos == 'Recibida'
                                ? verdeSeleccionado
                                : colorScheme.outline,
                            width: 1.0,
                          ),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                        ),
                        child: const Text('Recibida',
                            style: TextStyle(fontSize: 14)),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: sectionSpacing),

              // Estado publicación
              const Text('Estado publicación',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              SizedBox(height: smallSpacing),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: buttonHeight,
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _estadoPublicacion =
                                _estadoPublicacion == 'Por publicar'
                                    ? null
                                    : 'Por publicar';
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _estadoPublicacion == 'Por publicar'
                              ? verdeSeleccionado
                              : Colors.white,
                          foregroundColor: _estadoPublicacion == 'Por publicar'
                              ? Colors.white
                              : colorConOpacidad,
                          side: BorderSide(
                            color: _estadoPublicacion == 'Por publicar'
                                ? verdeSeleccionado
                                : colorScheme.outline,
                            width: 1.0,
                          ),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                        ),
                        child: const Text('Por publicar',
                            style: TextStyle(fontSize: 14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: spacingHorizontal),
                  Expanded(
                    child: SizedBox(
                      height: buttonHeight,
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _estadoPublicacion =
                                _estadoPublicacion == 'Publicado'
                                    ? null
                                    : 'Publicado';
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _estadoPublicacion == 'Publicado'
                              ? verdeSeleccionado
                              : Colors.white,
                          foregroundColor: _estadoPublicacion == 'Publicado'
                              ? Colors.white
                              : colorConOpacidad,
                          side: BorderSide(
                            color: _estadoPublicacion == 'Publicado'
                                ? verdeSeleccionado
                                : colorScheme.outline,
                            width: 1.0,
                          ),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                        ),
                        child: const Text('Publicado',
                            style: TextStyle(fontSize: 14)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'precioMin': _rangoPrecio.start.round(),
                  'precioMax': _rangoPrecio.end.round(),
                  'itvEstado': _estadoItv,
                  'estadoDocumentos': _estadoDocumentos,
                  'estadoPublicacion': _estadoPublicacion,
                  'combustible': _combustible,
                  'transmision': _transmision,
                });
              },
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ],
    );
  }
}
