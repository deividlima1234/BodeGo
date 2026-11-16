import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bodego/core/services/device_pairing_service.dart';
import 'package:bodego/core/services/license_service.dart';
import 'package:bodego/data/models/linked_device.dart';
import 'package:bodego/data/repositories/ticket_repository.dart';
import 'package:bodego/presentation/widgets/modern_barcode_scanner.dart';

enum SyncMode { twoWay, uploadOnly, downloadOnly }

/// Modal interactivo con pasos guiados y elementos animados para realizar
/// la sincronización bidireccional y fusión de datos entre terminales BodeGo.
class SyncWizardModal extends StatefulWidget {
  final VoidCallback? onSyncCompleted;

  const SyncWizardModal({super.key, this.onSyncCompleted});

  static Future<void> show(BuildContext context, {VoidCallback? onSyncCompleted}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SyncWizardModal(onSyncCompleted: onSyncCompleted),
    );
  }

  @override
  State<SyncWizardModal> createState() => _SyncWizardModalState();
}

class _SyncWizardModalState extends State<SyncWizardModal> with SingleTickerProviderStateMixin {
  final DevicePairingService _pairingService = DevicePairingService();
  final TicketRepository _ticketRepo = TicketRepository();

  int _currentStep = 0; // 0: Modo, 1: Verificación de red, 2: Transferencia y Fusión
  SyncMode _selectedMode = SyncMode.twoWay;

  MasterDeviceInfo? _masterInfo;
  late final TextEditingController _ipController;
  final TextEditingController _whatsappFallbackController = TextEditingController();

  bool _isCheckingNetwork = false;
  bool _isNetworkAvailable = false;
  bool _isTransferring = false;
  bool _transferSuccess = false;
  String? _errorMessage;

  int _pendingTicketsCount = 0;
  int _syncedTicketsCount = 0;
  int _syncedProductsCount = 0;

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _initData();
  }

  Future<void> _initData() async {
    final info = await _pairingService.getMasterInfo();
    final pending = await _ticketRepo.getPendingSyncTickets();
    if (mounted) {
      setState(() {
        _masterInfo = info;
        _ipController.text = info?.masterIp ?? '';
        _pendingTicketsCount = pending.length;
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ipController.dispose();
    _whatsappFallbackController.dispose();
    super.dispose();
  }

  /// Verifica la conectividad con la Caja Master
  Future<void> _verifyNetworkConnection() async {
    setState(() {
      _isCheckingNetwork = true;
      _errorMessage = null;
    });

    final targetIp = _ipController.text.trim();
    if (targetIp.isEmpty) {
      setState(() {
        _isCheckingNetwork = false;
        _isNetworkAvailable = false;
        _errorMessage = 'Por favor ingresa la dirección IP de la Caja Master.';
      });
      return;
    }

    final isAlive = await _pairingService.pingServer(targetIp);

    if (mounted) {
      setState(() {
        _isCheckingNetwork = false;
        _isNetworkAvailable = isAlive;
        if (!isAlive) {
          _errorMessage =
              'No se detectó respuesta en $targetIp:8089.\nAsegúrate de que ambos equipos estén en el mismo Wi-Fi y la Caja Master tenga BodeGo abierto.';
        }
      });
    }
  }

  /// Abre el escáner de cámara para reconectar escaneando el QR de la Caja Master
  Future<void> _scanReconnectionQr() async {
    final result = await ModernBarcodeScanner.scanSingle(
      context,
      title: 'Escanear QR de Caja Master',
      subtitle: 'Apunta al código QR generado en la Caja Principal',
    );

    if (result != null && mounted) {
      final clean = result.trim();
      if (clean.startsWith('BODEGO_PAIR:')) {
        try {
          final base64String = clean.substring('BODEGO_PAIR:'.length);
          final decodedJson = utf8.decode(base64Url.decode(base64String));
          final Map<String, dynamic> data = jsonDecode(decodedJson) as Map<String, dynamic>;
          final scannedIp = data['ip'] as String?;
          if (scannedIp != null && scannedIp.isNotEmpty) {
            setState(() {
              _ipController.text = scannedIp;
            });
            _verifyNetworkConnection();
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al procesar QR: $e')),
          );
        }
      }
    }
  }

  /// Ejecuta el proceso de fusión y sincronización de datos
  Future<void> _executeSync() async {
    setState(() {
      _currentStep = 2;
      _isTransferring = true;
      _transferSuccess = false;
      _errorMessage = null;
      _syncedTicketsCount = 0;
      _syncedProductsCount = 0;
    });

    final targetIp = _ipController.text.trim();
    final myLicense = await LicenseService().init();
    final myIp = await _pairingService.getLocalIp();
    const deviceName = 'Móvil Dueño / Secundario';

    try {
      // 1. Fase de Subida: Enviar ventas locales hacia la Caja Master
      if (_selectedMode == SyncMode.twoWay || _selectedMode == SyncMode.uploadOnly) {
        final sendResult = await _pairingService.sendPendingSalesToMaster(masterIp: targetIp);
        if (!sendResult.success && _selectedMode == SyncMode.uploadOnly) {
          throw Exception(sendResult.message ?? 'Error al enviar ventas a la Caja Master');
        }
        _syncedTicketsCount = sendResult.ticketsSent;
      }

      // 2. Fase de Bajada: Descargar catálogo consolidado desde la Caja Master
      if (_selectedMode == SyncMode.twoWay || _selectedMode == SyncMode.downloadOnly) {
        final snapshotJson = await _pairingService.fetchSnapshotFromMaster(
          ip: targetIp,
          secondaryMachineId: myLicense.machineId,
          secondaryDeviceName: deviceName,
          secondaryIp: myIp,
        );

        if (snapshotJson == null || snapshotJson.isEmpty) {
          throw Exception('La Caja Master no entregó los datos del catálogo');
        }

        final imported = await _pairingService.importDatabaseSnapshot(snapshotJson);
        if (!imported) {
          throw Exception('Error al aplicar el catálogo en la base de datos');
        }

        final decoded = jsonDecode(snapshotJson) as Map<String, dynamic>;
        _syncedProductsCount = (decoded['products'] as List<dynamic>? ?? []).length;
        await _pairingService.updateMasterLastSync();
      }

      if (mounted) {
        setState(() {
          _isTransferring = false;
          _transferSuccess = true;
        });
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTransferring = false;
          _transferSuccess = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.88,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Barra de agarre
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.35),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Encabezado
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4353FF).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.sync_rounded, color: Color(0xFF4353FF), size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sincronización de Datos',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          'Fusión de Ventas e Inventario Wi-Fi',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey),
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
          const Divider(height: 1),

          // Indicador de pasos
          _buildStepIndicator(theme),

          // Contenido del paso actual
          Expanded(
            child: _buildStepContent(theme, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          _buildStepPill(0, '1. Modo'),
          const Expanded(child: Divider(thickness: 2, indent: 8, endIndent: 8)),
          _buildStepPill(1, '2. Conexión'),
          const Expanded(child: Divider(thickness: 2, indent: 8, endIndent: 8)),
          _buildStepPill(2, '3. Fusión'),
        ],
      ),
    );
  }

  Widget _buildStepPill(int stepIndex, String label) {
    final isActive = _currentStep == stepIndex;
    final isDone = _currentStep > stepIndex;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isDone
                ? Colors.green
                : isActive
                    ? const Color(0xFF4353FF)
                    : Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              if (isDone)
                const Icon(Icons.check_rounded, color: Colors.white, size: 14)
              else
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: (isActive || isDone) ? Colors.white : Colors.grey,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepContent(ThemeData theme, bool isDark) {
    switch (_currentStep) {
      case 0:
        return _buildStep0ModeSelection(theme, isDark);
      case 1:
        return _buildStep1NetworkCheck(theme, isDark);
      case 2:
      default:
        return _buildStep2TransferAndResult(theme, isDark);
    }
  }

  // PASO 0: SELECCIÓN DEL TIPO DE SINCRONIZACIÓN
  Widget _buildStep0ModeSelection(ThemeData theme, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_pendingTicketsCount > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: Colors.orange, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tienes $_pendingTicketsCount venta(s) realizadas en este equipo listas para transferir a la Caja Master.',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

        const Text(
          '¿Qué deseas sincronizar?',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        const SizedBox(height: 6),
        Text(
          'Selecciona la dirección del intercambio de datos con la tienda:',
          style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
        const SizedBox(height: 18),

        // Opción 1: Dos vías (Recomendada)
        _buildModeCard(
          mode: SyncMode.twoWay,
          title: 'Sincronización Completa (2 Vías)',
          subtitle: 'Sube las ventas del móvil a la Caja Master y descarga el stock consolidado.',
          icon: Icons.sync_rounded,
          badge: 'RECOMENDADO',
          isRecommended: true,
          theme: theme,
        ),
        const SizedBox(height: 12),

        // Opción 2: Solo enviar ventas
        _buildModeCard(
          mode: SyncMode.uploadOnly,
          title: 'Enviar Ventas a Caja Master',
          subtitle: 'Solo transfiere los tickets emitidos en este equipo sin alterar tu inventario.',
          icon: Icons.upload_rounded,
          theme: theme,
        ),
        const SizedBox(height: 12),

        // Opción 3: Solo descargar catálogo
        _buildModeCard(
          mode: SyncMode.downloadOnly,
          title: 'Descargar Catálogo de la Tienda',
          subtitle: 'Recibe nuevos productos, precios oficiales y existencias frescas.',
          icon: Icons.download_rounded,
          theme: theme,
        ),
        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4353FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: () {
              setState(() => _currentStep = 1);
              _verifyNetworkConnection();
            },
            child: const Text(
              'CONTINUAR A VERIFICAR RED',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModeCard({
    required SyncMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
    String? badge,
    bool isRecommended = false,
    required ThemeData theme,
  }) {
    final isSelected = _selectedMode == mode;

    return InkWell(
      onTap: () => setState(() => _selectedMode = mode),
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4353FF).withOpacity(0.08) : theme.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? const Color(0xFF4353FF) : Colors.grey.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF4353FF) : Colors.grey.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isSelected ? Colors.white : Colors.grey, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                          color: isSelected ? const Color(0xFF4353FF) : null,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Radio<SyncMode>(
              value: mode,
              groupValue: _selectedMode,
              activeColor: const Color(0xFF4353FF),
              onChanged: (val) => setState(() => _selectedMode = val!),
            ),
          ],
        ),
      ),
    );
  }

  // PASO 1: VERIFICACIÓN DE RED Y RECONEXIÓN
  Widget _buildStep1NetworkCheck(ThemeData theme, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Tarjeta de estado de conexión
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _isCheckingNetwork
                ? Colors.blue.withOpacity(0.08)
                : _isNetworkAvailable
                    ? Colors.green.withOpacity(0.08)
                    : Colors.orange.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isCheckingNetwork
                  ? Colors.blue.withOpacity(0.3)
                  : _isNetworkAvailable
                      ? Colors.green.withOpacity(0.3)
                      : Colors.orange.withOpacity(0.3),
            ),
          ),
          child: Column(
            children: [
              if (_isCheckingNetwork) ...[
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Comprobando conexión con Caja Master...',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ] else if (_isNetworkAvailable) ...[
                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 40),
                const SizedBox(height: 10),
                const Text(
                  '¡Caja Master en línea!',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                ),
                const SizedBox(height: 4),
                Text(
                  'Conectado en ${_ipController.text.trim()}:8089',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ] else ...[
                const Icon(Icons.wifi_off_rounded, color: Colors.orange, size: 40),
                const SizedBox(height: 10),
                const Text(
                  'No se detectó la Caja Master',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.orange),
                ),
                const SizedBox(height: 6),
                Text(
                  _errorMessage ?? 'Verifica que ambos teléfonos estén en el mismo Wi-Fi.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Campo para editar IP
        TextField(
          controller: _ipController,
          keyboardType: TextInputType.datetime,
          decoration: InputDecoration(
            labelText: 'IP Local de la Caja Master',
            hintText: 'Ej: 10.185.98.193',
            prefixIcon: const Icon(Icons.wifi_rounded),
            suffixIcon: IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Reintentar ping',
              onPressed: _verifyNetworkConnection,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onSubmitted: (_) => _verifyNetworkConnection(),
        ),
        const SizedBox(height: 14),

        // Botón Escanear QR para reconectar
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Escanear Código QR de Caja Master'),
            onPressed: _scanReconnectionQr,
          ),
        ),
        const SizedBox(height: 28),

        // Botón Ejecutar Fusión
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isNetworkAvailable ? const Color(0xFF4353FF) : Colors.grey,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text(
              'INICIAR SINCRONIZACIÓN Y FUSIÓN',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            onPressed: _isNetworkAvailable ? _executeSync : null,
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _currentStep = 0),
            child: const Text('Volver a cambiar modo'),
          ),
        ),
      ],
    );
  }

  // PASO 2: TRANSFERENCIA, FUSIÓN Y RESULTADO
  Widget _buildStep2TransferAndResult(ThemeData theme, bool isDark) {
    if (_isTransferring) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeTransition(
                opacity: Tween<double>(begin: 0.6, end: 1.0).animate(_pulseController),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4353FF).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.sync_rounded,
                    color: Color(0xFF4353FF),
                    size: 54,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Fusionando Datos en Red...',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              const Text(
                'Transfiriendo tickets y consolidando stock de inventario con la Caja Master...',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 180,
                child: LinearProgressIndicator(color: Color(0xFF4353FF)),
              ),
            ],
          ),
        ),
      );
    }

    if (_transferSuccess) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 54),
                const SizedBox(height: 14),
                const Text(
                  '¡Sincronización Exitosa!',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Los datos se han fusionado y consolidado con la Caja Master de forma limpia.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const Divider(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildResultMetric(
                      icon: Icons.receipt_long_rounded,
                      value: '$_syncedTicketsCount',
                      label: 'Ventas Subidas',
                    ),
                    _buildResultMetric(
                      icon: Icons.inventory_2_rounded,
                      value: '$_syncedProductsCount',
                      label: 'Stock Consolidado',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4353FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.pop(context);
                if (widget.onSyncCompleted != null) widget.onSyncCompleted!();
              },
              child: const Text(
                'FINALIZAR Y CONTINUAR',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      );
    }

    // Si hubo error en la transferencia
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 44),
              const SizedBox(height: 12),
              const Text(
                'Fallo en la Sincronización',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.redAccent),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'Ocurrió un error inesperado al conectar con la Caja Master.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: Colors.grey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4353FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar Sincronización'),
            onPressed: _executeSync,
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _currentStep = 1),
            child: const Text('Cambiar IP o reconectar con QR'),
          ),
        ),
      ],
    );
  }

  Widget _buildResultMetric({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF4353FF), size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}
