import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bodego/data/models/printer_config.dart';
import 'package:bodego/data/repositories/printer_repository.dart';

/// Modal profesional interactivo con detección de hardware REAL
/// para descubrir, conectar y probar impresoras térmicas (Bluetooth, WiFi y USB OTG).
class PrinterScannerModal extends StatefulWidget {
  const PrinterScannerModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const PrinterScannerModal(),
    );
  }

  @override
  State<PrinterScannerModal> createState() => _PrinterScannerModalState();
}

class _PrinterScannerModalState extends State<PrinterScannerModal>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final PrinterRepository _printerRepo = PrinterRepository();

  late final AnimationController _pulseController;
  String _selectedConnectionType = 'bluetooth'; // 'bluetooth', 'wifi', 'usb'
  bool _isScanning = false;
  bool _isBluetoothEnabled = true;
  String? _connectingId;
  String? _connectedId;

  List<DiscoveredPrinter> _discoveredPrinters = [];
  PrinterConfig? _currentConfig;

  // Controladores para configuración WiFi
  final TextEditingController _wifiIpController = TextEditingController(text: '192.168.1.150');
  final TextEditingController _wifiPortController = TextEditingController(text: '9100');
  bool _isTestingWifi = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _loadCurrentAndScan();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _wifiIpController.dispose();
    _wifiPortController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver de los ajustes de Android, re-evaluar si el usuario encendió el Bluetooth
    if (state == AppLifecycleState.resumed && _selectedConnectionType == 'bluetooth') {
      _checkBluetoothStateAndScan();
    }
  }

  Future<void> _loadCurrentAndScan() async {
    final config = await _printerRepo.getConfig();
    if (mounted) {
      setState(() {
        _currentConfig = config;
        _selectedConnectionType = config.connectionType;
        if (config.connectionType == 'wifi' && config.deviceAddress.contains(':')) {
          final parts = config.deviceAddress.split(':');
          _wifiIpController.text = parts[0];
          _wifiPortController.text = parts[1];
        }
      });
      _startScan();
    }
  }

  Future<void> _checkBluetoothStateAndScan() async {
    final isEnabled = await _printerRepo.isBluetoothEnabled();
    if (mounted) {
      setState(() {
        _isBluetoothEnabled = isEnabled;
      });
      if (isEnabled) {
        _startScan();
      }
    }
  }

  Future<void> _startScan() async {
    if (_selectedConnectionType == 'bluetooth') {
      final isEnabled = await _printerRepo.isBluetoothEnabled();
      if (!mounted) return;
      setState(() {
        _isBluetoothEnabled = isEnabled;
      });
      if (!isEnabled) {
        setState(() {
          _isScanning = false;
          _discoveredPrinters = [];
        });
        return;
      }
    }

    setState(() {
      _isScanning = true;
      _discoveredPrinters = [];
      _connectingId = null;
    });

    final results = await _printerRepo.scanPrinters(
      connectionType: _selectedConnectionType,
    );

    if (mounted) {
      setState(() {
        _discoveredPrinters = results;
        _isScanning = false;
        if (_currentConfig != null && _currentConfig!.isConnected) {
          final match = results.where((p) => p.address == _currentConfig!.deviceAddress).firstOrNull;
          if (match != null) {
            _connectedId = match.id;
          }
        }
      });
    }
  }

  Future<void> _handleConnect(DiscoveredPrinter printer) async {
    HapticFeedback.lightImpact();
    setState(() {
      _connectingId = printer.id;
    });

    final updated = await _printerRepo.connectPrinter(printer);

    if (mounted) {
      HapticFeedback.mediumImpact();
      setState(() {
        _connectingId = null;
        _connectedId = printer.id;
        _currentConfig = updated;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '¡${printer.name} vinculada con éxito!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
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

  Future<void> _handleConnectWifi() async {
    final ip = _wifiIpController.text.trim();
    final port = int.tryParse(_wifiPortController.text.trim()) ?? 9100;

    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa una dirección IP válida')),
      );
      return;
    }

    setState(() => _isTestingWifi = true);
    HapticFeedback.lightImpact();

    final isOnline = await _printerRepo.testWifiConnection(ip, port: port);
    if (!mounted) return;
    setState(() => _isTestingWifi = false);

    if (isOnline) {
      final wifiPrinter = DiscoveredPrinter(
        id: 'wifi_$ip',
        name: 'Ticketera LAN WiFi ($ip)',
        address: '$ip:$port',
        type: 'wifi',
        rssi: -35,
        paperWidth: 80,
        isPaired: true,
      );
      await _handleConnect(wifiPrinter);
    } else {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.wifi_off_rounded, color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Text('Impresora No Detectada', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Text(
            'No se pudo conectar a $ip:$port.\n\nVerifica que la impresora esté encendida, conectada a la misma red WiFi del teléfono y con el puerto 9100 habilitado.',
            style: const TextStyle(fontSize: 12.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _handleTestPrint() async {
    if (_currentConfig == null) return;
    HapticFeedback.heavyImpact();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            const SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 20),
            Text(
              'Enviando comando ESC/POS real a ${_currentConfig!.deviceName}...',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    final success = await _printerRepo.printTestTicket(_currentConfig!);

    if (mounted) {
      Navigator.pop(context); // Cierra diálogo de espera
      if (success) {
        _showTestPrintSuccessModal();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar ticket a ${_currentConfig!.deviceName}. Revisa la conexión.'),
            backgroundColor: Colors.red[800],
          ),
        );
      }
    }
  }

  void _showTestPrintSuccessModal() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
            SizedBox(width: 8),
            Text('Ticket Emitido con Éxito', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Text(
          'El comprobante de prueba fue transmitido exitosamente a ${_currentConfig?.deviceName ?? "la impresora"}.\n\nTu ticketera está lista para operar en Caja.',
          style: const TextStyle(fontSize: 12.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Listo'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: media.size.height * 0.88,
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
      child: Column(
        children: [
          // Tirador superior de arrastre
          const SizedBox(height: 10),
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
          const SizedBox(height: 12),

          // Cabecera del Asistente
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.print_rounded,
                        color: theme.colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Asistente de Impresora Real',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Detecta y conecta dispositivos físicos',
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
          ),

          const SizedBox(height: 14),

          // Selector de Conexión: Bluetooth, WiFi, USB
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                _buildMediaTypePill(
                  label: 'Bluetooth',
                  icon: Icons.bluetooth_rounded,
                  type: 'bluetooth',
                ),
                const SizedBox(width: 8),
                _buildMediaTypePill(
                  label: 'Red WiFi',
                  icon: Icons.wifi_rounded,
                  type: 'wifi',
                ),
                const SizedBox(width: 8),
                _buildMediaTypePill(
                  label: 'USB OTG',
                  icon: Icons.usb_rounded,
                  type: 'usb',
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),

          // Cuerpo según el tipo de conexión
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              children: [
                if (_selectedConnectionType == 'bluetooth')
                  _buildBluetoothContent(theme)
                else if (_selectedConnectionType == 'wifi')
                  _buildWifiContent(theme)
                else
                  _buildUsbContent(theme),

                // Sección de Test de impresión si está vinculada
                if (_connectedId != null || (_currentConfig != null && _currentConfig!.isConnected)) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified_rounded, color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Conectada: ${_currentConfig?.deviceName ?? "Impresora"}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_currentConfig?.deviceAddress} • ${_currentConfig?.paperWidthMm} mm',
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.black87),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _handleTestPrint,
                            icon: const Icon(Icons.print_rounded, size: 16),
                            label: const Text('Enviar Ticket de Prueba Real'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // VISTA BLUETOOTH REAL
  // ==========================================
  Widget _buildBluetoothContent(ThemeData theme) {
    if (!_isBluetoothEnabled) {
      // Estado: Bluetooth APAGADO
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.withOpacity(0.35)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bluetooth_disabled_rounded,
                color: Colors.orange,
                size: 40,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Bluetooth Desactivado',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'El Bluetooth de tu teléfono está apagado. Actívalo para descubrir y vincular tu ticketera térmica POS.',
              style: TextStyle(fontSize: 11.5, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  await _printerRepo.requestEnableBluetooth();
                  await Future.delayed(const Duration(milliseconds: 1000));
                  _checkBluetoothStateAndScan();
                },
                icon: const Icon(Icons.bluetooth_rounded, size: 20),
                label: const Text('Activar Bluetooth Ahora'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Estado: Bluetooth ENCENDIDO
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Radar de escaneo
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(140, 140),
                painter: _RadarPulsePainter(
                  animation: _pulseController,
                  color: theme.colorScheme.primary,
                  isScanning: _isScanning,
                ),
              ),
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.4),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.bluetooth_searching_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        Center(
          child: Column(
            children: [
              Text(
                _isScanning
                    ? 'Buscando impresoras Bluetooth en el área...'
                    : '${_discoveredPrinters.length} dispositivos Bluetooth encontrados',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 3),
              Text(
                _isScanning
                    ? 'Asegúrate de que la ticketera esté encendida'
                    : 'Selecciona tu ticketera para vincular',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Botón de acción: Volver a escanear o Abrir Ajustes de Bluetooth
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isScanning ? null : _startScan,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Escanear Dispositivos', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.settings_bluetooth_rounded),
              tooltip: 'Ajustes de Bluetooth de Android',
              onPressed: () => _printerRepo.requestEnableBluetooth(),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Listado de impresoras descubiertas
        if (_discoveredPrinters.isEmpty && !_isScanning) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Icon(Icons.print_disabled_rounded, size: 36, color: Colors.grey[400]),
                const SizedBox(height: 8),
                const Text(
                  'No se detectaron impresoras Bluetooth',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 3),
                Text(
                  '1. Enciende tu ticketera.\n2. Si es nueva, emparéjala primero en los Ajustes de Bluetooth de tu teléfono (PIN usual: 0000 o 1234).\n3. Presiona "Escanear Dispositivos".',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _printerRepo.requestEnableBluetooth(),
                    icon: const Icon(Icons.settings_bluetooth_rounded, size: 16),
                    label: const Text('Vincular en Ajustes de Android', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          ..._discoveredPrinters.map((printer) => _buildPrinterTile(printer, theme)),
        ],
      ],
    );
  }

  // ==========================================
  // VISTA RED WIFI REAL
  // ==========================================
  Widget _buildWifiContent(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wifi_rounded, color: Colors.blue, size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Conexión por Red WiFi / LAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('Ticketeras Epson, Bixolon, Sunmi o Xprinter en red', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Dirección IP de la Impresora:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(
            controller: _wifiIpController,
            keyboardType: TextInputType.datetime,
            decoration: InputDecoration(
              hintText: 'Ej: 192.168.1.150',
              prefixIcon: const Icon(Icons.dns_rounded, size: 20),
              filled: true,
              fillColor: theme.scaffoldBackgroundColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 10),
          const Text('Puerto RAW ESC/POS (Predeterminado 9100):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(
            controller: _wifiPortController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: '9100',
              prefixIcon: const Icon(Icons.numbers_rounded, size: 20),
              filled: true,
              fillColor: theme.scaffoldBackgroundColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isTestingWifi ? null : _handleConnectWifi,
              icon: _isTestingWifi
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.wifi_find_rounded, size: 18),
              label: Text(_isTestingWifi ? 'Verificando Impresora...' : 'Verificar y Conectar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // VISTA USB OTG REAL
  // ==========================================
  Widget _buildUsbContent(ThemeData theme) {
    return Column(
      children: [
        if (_discoveredPrinters.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                const Icon(Icons.usb_rounded, size: 40, color: Colors.grey),
                const SizedBox(height: 10),
                const Text(
                  'No se detecta ticketera USB',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                const SizedBox(height: 4),
                Text(
                  'Conecta tu impresora térmica mediante un adaptador o cable USB OTG al puerto de tu teléfono y enciéndela.',
                  style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _startScan,
                    icon: const Icon(Icons.usb_rounded, size: 18),
                    label: const Text('Detectar Impresora USB Ahora'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          ..._discoveredPrinters.map((printer) => _buildPrinterTile(printer, theme)),
        ],
      ],
    );
  }

  // Widget para tarjeta de cada impresora encontrada
  Widget _buildPrinterTile(DiscoveredPrinter printer, ThemeData theme) {
    final bool isConnecting = _connectingId == printer.id;
    final bool isConnected = _connectedId == printer.id ||
        (_currentConfig != null &&
            _currentConfig!.isConnected &&
            _currentConfig!.deviceAddress == printer.address);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isConnected ? Colors.green.withOpacity(0.6) : Colors.grey.withOpacity(0.2),
          width: isConnected ? 1.8 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isConnected
                    ? Colors.green.withOpacity(0.12)
                    : theme.colorScheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.print_rounded,
                size: 22,
                color: isConnected ? Colors.green[700] : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          printer.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (printer.isPaired)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Vinculada',
                            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.blue[800]),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        printer.address,
                        style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 8),
                      _buildSignalBars(printer.rssi),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (isConnecting)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            else if (isConnected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 14, color: Colors.green[700]),
                    const SizedBox(width: 4),
                    Text(
                      'Activa',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                  ],
                ),
              )
            else
              ElevatedButton(
                onPressed: () => _handleConnect(printer),
                style: ElevatedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Conectar', style: TextStyle(fontSize: 11)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaTypePill({
    required String label,
    required IconData icon,
    required String type,
  }) {
    final theme = Theme.of(context);
    final isSelected = _selectedConnectionType == type;

    return Expanded(
      child: InkWell(
        onTap: () {
          if (_selectedConnectionType != type) {
            setState(() {
              _selectedConnectionType = type;
            });
            _startScan();
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? theme.colorScheme.primary : Colors.grey.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : theme.colorScheme.onSurface,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignalBars(int rssi) {
    final int bars = rssi >= -50 ? 4 : (rssi >= -65 ? 3 : (rssi >= -80 ? 2 : 1));
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (index) {
        final bool active = index < bars;
        return Container(
          width: 2.5,
          height: 4.0 + (index * 2.5),
          margin: const EdgeInsets.symmetric(horizontal: 0.5),
          decoration: BoxDecoration(
            color: active ? Colors.green[600] : Colors.grey[300],
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}

/// Pintor para el radar pulsante
class _RadarPulsePainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;
  final bool isScanning;

  _RadarPulsePainter({
    required this.animation,
    required this.color,
    required this.isScanning,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    final basePaint = Paint()
      ..color = color.withOpacity(0.06)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, maxRadius, basePaint);

    if (!isScanning) return;

    for (int i = 0; i < 3; i++) {
      final double progress = (animation.value + (i * 0.33)) % 1.0;
      final double radius = progress * maxRadius;
      final double opacity = (1.0 - progress).clamp(0.0, 1.0);

      final wavePaint = Paint()
        ..color = color.withOpacity(opacity * 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, radius, wavePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPulsePainter oldDelegate) => true;
}
