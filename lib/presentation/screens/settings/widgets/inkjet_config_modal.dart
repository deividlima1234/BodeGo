import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bodego/core/services/ipp_client.dart';
import 'package:bodego/data/models/printer_config.dart';
import 'package:bodego/data/repositories/printer_repository.dart';

/// Modal para seleccionar y configurar la impresora de inyección de tinta (Canon G3110, Epson, HP)
/// con soporte dual: Impresión Directa IPP por Wi-Fi (0 ventanas) y Servicio Android Print (1 toque).
class InkjetConfigModal extends StatefulWidget {
  final PrinterConfig currentConfig;
  final ValueChanged<PrinterConfig> onConfigUpdated;

  const InkjetConfigModal({
    super.key,
    required this.currentConfig,
    required this.onConfigUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required PrinterConfig currentConfig,
    required ValueChanged<PrinterConfig> onConfigUpdated,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => InkjetConfigModal(
        currentConfig: currentConfig,
        onConfigUpdated: onConfigUpdated,
      ),
    );
  }

  @override
  State<InkjetConfigModal> createState() => _InkjetConfigModalState();
}

class _InkjetConfigModalState extends State<InkjetConfigModal> {
  final PrinterRepository _printerRepo = PrinterRepository();
  late final TextEditingController _modelController;
  late final TextEditingController _ipController;
  late final TextEditingController _portController;

  late String _selectedMode;
  bool _isTestingConnection = false;
  String? _testMessage;
  bool? _testSuccess;

  static const List<String> _popularModels = [
    'Canon MegaTank G3110',
    'Epson EcoTank L7590',
    'Epson EcoTank L3250',
    'HP Smart Tank 580',
    'Canon MegaTank G2110',
    'Brother InkBenefit T420W',
  ];

  @override
  void initState() {
    super.initState();
    _modelController = TextEditingController(
      text: widget.currentConfig.inkjetPrinterModel.isNotEmpty
          ? widget.currentConfig.inkjetPrinterModel
          : 'Canon MegaTank G3110',
    );
    _ipController = TextEditingController(
      text: widget.currentConfig.inkjetPrinterIp.isNotEmpty
          ? widget.currentConfig.inkjetPrinterIp
          : '192.168.22.1',
    );
    _portController = TextEditingController(
      text: widget.currentConfig.inkjetPrinterPort.toString(),
    );
    _selectedMode = widget.currentConfig.inkjetMode;
  }

  @override
  void dispose() {
    _modelController.dispose();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _handleTestConnection() async {
    setState(() {
      _isTestingConnection = true;
      _testMessage = null;
      _testSuccess = null;
    });
    HapticFeedback.selectionClick();

    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 631;

    final result = await IppClient.testConnection(ip, port);

    if (!mounted) return;
    setState(() {
      _isTestingConnection = false;
      _testSuccess = result.success;
      if (result.success) {
        _testMessage = result.message.startsWith('✅') ? result.message : '✅ ${result.message}';
        if (result.detectedModel != null && result.detectedModel!.isNotEmpty) {
          _modelController.text = result.detectedModel!;
        }
        if (!result.supportsDirectPdf && port == 631) {
          _selectedMode = 'android_spooler';
        }
        HapticFeedback.mediumImpact();
      } else {
        _testMessage = '❌ No se pudo conectar a $ip:$port. Verifica que el teléfono esté en la red Wi-Fi de la impresora.';
        HapticFeedback.heavyImpact();
      }
    });
  }

  Future<void> _handleSave() async {
    HapticFeedback.lightImpact();
    final modelName = _modelController.text.trim().isNotEmpty
        ? _modelController.text.trim()
        : 'Canon MegaTank G3110';
    final ip = _ipController.text.trim().isNotEmpty ? _ipController.text.trim() : '192.168.22.1';
    final port = int.tryParse(_portController.text.trim()) ?? 631;

    final updated = widget.currentConfig.copyWith(
      inkjetPrinterModel: modelName,
      inkjetMode: _selectedMode,
      inkjetPrinterIp: ip,
      inkjetPrinterPort: port,
      printerType: 'inkjet_system',
      deviceName: modelName,
      isConnected: _selectedMode == 'direct_ipp' ? true : widget.currentConfig.isConnected,
    );

    await _printerRepo.saveConfig(updated);
    widget.onConfigUpdated(updated);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_selectedMode == 'direct_ipp'
                    ? '¡Modo Directo IPP activo en $ip:$port!'
                    : '¡Impresora $modelName configurada con éxito!'),
              ),
            ],
          ),
          backgroundColor: Colors.green[800],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);

    return Container(
      padding: EdgeInsets.only(
        bottom: media.viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tirador superior
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Cabecera
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.local_printshop_rounded,
                          color: Colors.blue[800],
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Configurar Impresora de Tinta',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Canon MegaTank, Epson o HP vía Wi-Fi',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // 1. Selector de Modo de Transmisión
              const Text(
                'Método de Impresión:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),

              // Opción A: Modo Directo IPP (0 Ventanas)
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedMode = 'direct_ipp');
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _selectedMode == 'direct_ipp' ? Colors.blue.withOpacity(0.08) : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedMode == 'direct_ipp' ? Colors.blue : Colors.grey.withOpacity(0.2),
                      width: _selectedMode == 'direct_ipp' ? 1.6 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _selectedMode == 'direct_ipp' ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        color: _selectedMode == 'direct_ipp' ? Colors.blue : Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Directo por Wi-Fi IPP',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '0 VENTANAS',
                                    style: TextStyle(color: Colors.green[800], fontSize: 9.5, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Envío instantáneo por red a la IP de la Canon/Epson sin confirmación en pantalla.',
                              style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Opción B: Servicio Android Spooler (1 Toque)
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedMode = 'android_spooler');
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _selectedMode == 'android_spooler' ? Colors.blue.withOpacity(0.08) : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedMode == 'android_spooler' ? Colors.blue : Colors.grey.withOpacity(0.2),
                      width: _selectedMode == 'android_spooler' ? 1.6 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _selectedMode == 'android_spooler' ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        color: _selectedMode == 'android_spooler' ? Colors.blue : Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Servicio Android Print / Mopria',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Utiliza el plugin de Canon Print Service o Mopria con diálogo de confirmación.',
                              style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Nota de compatibilidad de fabricante
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.green[800]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Motor universal PWG-Raster activo: Impresión directa silenciosa (0 ventanas) compatible con Canon MegaTank (G3110/G2110), Epson EcoTank, HP Smart Tank y Brother.',
                        style: TextStyle(fontSize: 10.5, color: Colors.green[900], height: 1.3, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 2. Modelo de la impresora
              const Text(
                'Modelo de Impresora:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _modelController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Ej: Canon MegaTank G3110',
                  prefixIcon: const Icon(Icons.print_rounded, size: 20),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),

              const SizedBox(height: 8),

              // Chips de modelos populares
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _popularModels.map((model) {
                  final isSelected = _modelController.text == model;
                  return ActionChip(
                    label: Text(model, style: const TextStyle(fontSize: 11)),
                    backgroundColor: isSelected ? Colors.blue.withOpacity(0.2) : theme.colorScheme.surface,
                    side: BorderSide(
                      color: isSelected ? Colors.blue : Colors.grey.withOpacity(0.25),
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _modelController.text = model;
                        if (model.contains('Canon') && _ipController.text == '192.168.1.150') {
                          _ipController.text = '192.168.22.1';
                        }
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // 3. Panel de Configuración de Red (IP y Puerto)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.wifi_tethering_rounded, color: Colors.blue, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Conexión de Red (Wi-Fi de la Impresora)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: Colors.blue[900],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        // Campo IP
                        Expanded(
                          flex: 7,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Dirección IP de la Impresora:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              TextField(
                                controller: _ipController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: '192.168.22.1',
                                  filled: true,
                                  fillColor: theme.colorScheme.surface,
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Campo Puerto
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Puerto:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              TextField(
                                controller: _portController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: '631',
                                  filled: true,
                                  fillColor: theme.colorScheme.surface,
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Accesos rápidos de IP
                    Wrap(
                      spacing: 6,
                      children: [
                        InkWell(
                          onTap: () {
                            _ipController.text = '192.168.22.1';
                            _portController.text = '631';
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.withOpacity(0.3)),
                            ),
                            child: const Text('IP Wi-Fi Direct Canon (192.168.22.1)', style: TextStyle(fontSize: 9.5, color: Colors.blue)),
                          ),
                        ),
                        InkWell(
                          onTap: () => _portController.text = '9100',
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.withOpacity(0.3)),
                            ),
                            child: const Text('RAW 9100', style: TextStyle(fontSize: 9.5, color: Colors.blue)),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Botón Probar Conexión
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isTestingConnection ? null : _handleTestConnection,
                        icon: _isTestingConnection
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.network_check_rounded, size: 16),
                        label: Text(_isTestingConnection ? 'Verificando socket...' : 'Probar Conexión con Impresora'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          side: BorderSide(color: Colors.blue[700]!),
                        ),
                      ),
                    ),

                    // Banner de resultado del test
                    if (_testMessage != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _testSuccess == true ? Colors.green.withOpacity(0.12) : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _testSuccess == true ? Colors.green : Colors.red, width: 0.8),
                        ),
                        child: Text(
                          _testMessage!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _testSuccess == true ? Colors.green[900] : Colors.red[900],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Botón Guardar y Enlazar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _handleSave,
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: const Text('Guardar y Enlazar Impresora', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
