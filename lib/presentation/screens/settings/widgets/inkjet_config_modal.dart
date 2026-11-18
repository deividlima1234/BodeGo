import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bodego/data/models/printer_config.dart';
import 'package:bodego/data/repositories/printer_repository.dart';

/// Modal para seleccionar y configurar la impresora de inyección de tinta (Epson, HP, Canon)
/// y abrir los servicios de impresión de Android (Mopria / Epson Print Enabler).
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

  static const List<String> _popularModels = [
    'Epson EcoTank L7590',
    'Epson EcoTank L3250',
    'Epson EcoTank L4260',
    'Epson EcoTank L3110',
    'HP Smart Tank 580',
    'Canon MegaTank G3110',
    'Brother InkBenefit T420W',
  ];

  @override
  void initState() {
    super.initState();
    _modelController = TextEditingController(
      text: widget.currentConfig.inkjetPrinterModel.isNotEmpty
          ? widget.currentConfig.inkjetPrinterModel
          : 'Epson EcoTank L7590',
    );
  }

  @override
  void dispose() {
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    HapticFeedback.lightImpact();
    final modelName = _modelController.text.trim().isNotEmpty
        ? _modelController.text.trim()
        : 'Epson EcoTank L7590';

    final updated = widget.currentConfig.copyWith(
      inkjetPrinterModel: modelName,
      printerType: 'inkjet_system',
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
                child: Text('¡Impresora $modelName configurada con éxito!'),
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
                          'Impresora de Tinta / A4',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Epson EcoTank, HP o Canon vía WiFi',
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

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // 1. Campo de modelo
            const Text(
              'Modelo o Nombre de tu Impresora:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _modelController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Ej: Epson EcoTank L7590',
                prefixIcon: const Icon(Icons.print_rounded, size: 20),
                filled: true,
                fillColor: theme.colorScheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),

            const SizedBox(height: 10),

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
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // 2. Tarjeta explicativa de conexión WiFi y Mopria / Epson Enabler
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.wifi_rounded, color: Colors.blue, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Conexión automática por WiFi',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.blue[900],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '1. Conecta tu teléfono y la impresora a la misma red WiFi.\n'
                    '2. Android detectará tu impresora mediante Mopria o Epson Print Enabler.\n'
                    '3. Al cobrar en BodeGo, el comprobante se enviará directo a tu impresora.',
                    style: TextStyle(fontSize: 11, color: Colors.grey[800], height: 1.3),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _printerRepo.openAndroidPrintSettings();
                      },
                      icon: const Icon(Icons.settings_suggest_rounded, size: 16),
                      label: const Text('Abrir Ajustes de Impresión de Android', style: TextStyle(fontSize: 11.5)),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        side: BorderSide(color: Colors.blue[700]!),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Botón Guardar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Guardar y Seleccionar Impresora', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

