import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bodego/core/services/device_pairing_service.dart';
import 'package:bodego/presentation/widgets/modern_barcode_scanner.dart';
import 'package:bodego/presentation/screens/auth/pin_login_screen.dart';

/// Modal interactivo con pasos guiados y elementos animados para vincular
/// un dispositivo secundario (ej. teléfono del dueño o segunda terminal de venta)
/// sin tener que volver a configurar el negocio desde cero.
class SecondaryDeviceOnboardingModal extends StatefulWidget {
  final VoidCallback? onPairedSuccessfully;

  const SecondaryDeviceOnboardingModal({
    super.key,
    this.onPairedSuccessfully,
  });

  /// Método estático conveniente para desplegar el modal desde cualquier pantalla
  static Future<void> show(BuildContext context, {VoidCallback? onPairedSuccessfully}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SecondaryDeviceOnboardingModal(
        onPairedSuccessfully: onPairedSuccessfully,
      ),
    );
  }

  @override
  State<SecondaryDeviceOnboardingModal> createState() =>
      _SecondaryDeviceOnboardingModalState();
}

class _SecondaryDeviceOnboardingModalState
    extends State<SecondaryDeviceOnboardingModal> with SingleTickerProviderStateMixin {
  final DevicePairingService _pairingService = DevicePairingService();

  int _currentStep = 0; // 0: Preparación, 1: Escanear/PIN, 2: Sincronización y Éxito
  late final AnimationController _waveAnimController;

  // Variables de emparejamiento
  String? _masterIp;
  List<String> _candidateIps = [];
  int _masterPort = DevicePairingService.defaultPort;
  String? _passkey;
  String _businessName = 'BodeGo';
  String? _masterMachineId;

  // Controladores de texto para modo manual
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _fallbackJsonController = TextEditingController();
  String? _ipHint;

  bool _isSyncing = false;
  bool _syncSuccess = false;
  String? _syncErrorMessage;
  int _importedProductsCount = 0;

  @override
  void initState() {
    super.initState();
    _initLocalNetworkHint();
    _waveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  Future<void> _initLocalNetworkHint() async {
    try {
      final myIp = await _pairingService.getLocalIp();
      if (mounted && myIp.contains('.')) {
        final parts = myIp.split('.');
        if (parts.length == 4) {
          setState(() {
            _ipHint = 'Ej: ${parts[0]}.${parts[1]}.${parts[2]}.xxx';
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _waveAnimController.dispose();
    _pinController.dispose();
    _ipController.dispose();
    _fallbackJsonController.dispose();
    super.dispose();
  }

  /// Procesa el texto obtenido al escanear el Código QR de la Caja Principal
  void _processScannedQrPayload(String rawPayload) async {
    final clean = rawPayload.trim();
    if (!clean.startsWith('BODEGO_PAIR:')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El código QR escaneado no pertenece a una Caja BodeGo.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    try {
      final base64String = clean.substring('BODEGO_PAIR:'.length);
      final decodedJson = utf8.decode(base64Url.decode(base64String));
      final Map<String, dynamic> data = jsonDecode(decodedJson) as Map<String, dynamic>;

      final candidateList = (data['candidateIps'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();

      setState(() {
        _masterIp = data['ip'] as String? ?? (candidateList.isNotEmpty ? candidateList.first : '192.168.1.1');
        _candidateIps = candidateList;
        _masterPort = (data['port'] as num?)?.toInt() ?? DevicePairingService.defaultPort;
        _passkey = data['passkey'] as String?;
        _businessName = data['business'] as String? ?? 'BodeGo';
        _masterMachineId = data['masterId'] as String? ?? 'BDG-MASTER';
        _currentStep = 2; // Avanzar a Sincronización
      });

      HapticFeedback.heavyImpact();
      _startDirectSync();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al decodificar código QR: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  /// Inicia la sincronización HTTP directa con el servidor shelf de la Caja Master
  Future<void> _startDirectSync() async {
    setState(() {
      _isSyncing = true;
      _syncErrorMessage = null;
      _syncSuccess = false;
    });

    final targetIp = _masterIp ?? _ipController.text.trim();
    final snapshotJson = await _pairingService.fetchSnapshotFromMaster(
      ip: targetIp,
      candidateIps: _candidateIps,
      port: _masterPort,
    );

    if (snapshotJson != null && snapshotJson.isNotEmpty) {
      await _applySnapshot(snapshotJson);
    } else {
      // Si la red directa no responde (ej. aislamiento de clientes Wi-Fi), ofrecer fallback
      setState(() {
        _isSyncing = false;
        _syncErrorMessage =
            'No se pudo conectar directamente por Wi-Fi a $targetIp:$_masterPort. Puedes pegar el catálogo exportado por WhatsApp como respaldo:';
      });
    }
  }

  /// Aplica el snapshot JSON recibido (por red o pegado manual)
  Future<void> _applySnapshot(String rawJson) async {
    try {
      final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
      final prods = (decoded['products'] as List<dynamic>? ?? []);
      final bName = (decoded['businessName'] as String? ?? _businessName).trim();
      final mId = (decoded['machineId'] as String? ?? _masterMachineId ?? 'BDG-MASTER');

      final ok = await _pairingService.completeSecondaryDeviceSetup(
        businessName: bName,
        masterMachineId: mId,
        rawSnapshotJson: rawJson,
      );

      if (ok) {
        setState(() {
          _isSyncing = false;
          _syncSuccess = true;
          _businessName = bName;
          _importedProductsCount = prods.length;
        });
        HapticFeedback.heavyImpact();
      } else {
        setState(() {
          _isSyncing = false;
          _syncErrorMessage = 'El formato del catálogo es incorrecto o está dañado.';
        });
      }
    } catch (e) {
      setState(() {
        _isSyncing = false;
        _syncErrorMessage = 'Error procesando catálogo: $e';
      });
    }
  }

  /// Abre el lector de código QR con marco y láser animado
  Future<void> _openCameraScanner() async {
    final result = await ModernBarcodeScanner.scanSingle(
      context,
      title: 'Escanear QR de Caja Central',
      subtitle: 'Apunta al código QR generado en la Caja Principal',
    );

    if (result != null && mounted) {
      _processScannedQrPayload(result);
    }
  }

  /// Finaliza el proceso y lleva al usuario a operar el POS
  void _finishAndEnterApp() {
    Navigator.pop(context); // Cierra el modal
    if (widget.onPairedSuccessfully != null) {
      widget.onPairedSuccessfully!();
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PinLoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.90,
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
          // Barra de agarre superior
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

          // Header con botón cerrar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4353FF).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.devices_other_rounded,
                    color: Color(0xFF4353FF),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vincular como Equipo Secundario',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Móvil del Dueño • Segunda Caja • Modo Mayorista',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Indicador de Pasos Animado
          _buildStepIndicators(theme),
          const Divider(height: 1),

          // Contenido Dinámico según el Paso Activo
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildCurrentStepView(theme, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicators(ThemeData theme) {
    final steps = ['1. Preparar', '2. Escanear / PIN', '3. Sincronizar'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(steps.length, (index) {
          final isCompleted = _currentStep > index;
          final isCurrent = _currentStep == index;

          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? Colors.green
                        : isCurrent
                            ? const Color(0xFF4353FF)
                            : Colors.grey.withOpacity(0.25),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isCurrent ? Colors.white : Colors.grey,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  steps[index].substring(3),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCurrent ? const Color(0xFF4353FF) : Colors.grey,
                  ),
                ),
                if (index < steps.length - 1)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      height: 2,
                      color: isCompleted ? Colors.green : Colors.grey.withOpacity(0.2),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStepView(ThemeData theme, bool isDark) {
    switch (_currentStep) {
      case 0:
        return _buildStep1Preparation(theme, isDark);
      case 1:
        return _buildStep2ScanOrPin(theme, isDark);
      case 2:
      default:
        return _buildStep3SyncAndSuccess(theme, isDark);
    }
  }

  // ==========================================
  // PASO 1: PREPARACIÓN Y GUÍA ANIMADA
  // ==========================================
  Widget _buildStep1Preparation(ThemeData theme, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Ilustración Animada de Dos Dispositivos con Ondas de Señal
        Center(
          child: AnimatedBuilder(
            animation: _waveAnimController,
            builder: (context, _) {
              final wave = _waveAnimController.value;
              return Container(
                width: 240,
                height: 120,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161C2E) : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF4353FF).withOpacity(0.2 + wave * 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Dispositivo 1: Caja Master
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4353FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(height: 6),
                        const Text('Caja Central', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                      ],
                    ),

                    // Ondas animadas en el centro
                    Row(
                      children: [
                        Icon(Icons.wifi_rounded, size: 18 + wave * 6, color: const Color(0xFF4353FF).withOpacity(0.4 + wave * 0.6)),
                        const SizedBox(width: 4),
                        const Icon(Icons.swap_horiz_rounded, color: Color(0xFF4353FF), size: 22),
                      ],
                    ),

                    // Dispositivo 2: Este Móvil
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00D084),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.phone_android_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(height: 6),
                        const Text('Este Móvil', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),

        const Text(
          '¿Cómo conectar este equipo?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Sigue estos 3 sencillos pasos para importar automáticamente todos los productos y configuraciones de tu tienda:',
          style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // Pasos enumerados
        _buildInstructionCard(
          number: '1',
          title: 'Abre tu Caja Central',
          description: 'En el equipo principal de tu negocio, ingresa a:\nConfiguración > Multi-Equipo > Vincular Equipo (+)',
          icon: Icons.qr_code_2_rounded,
        ),
        const SizedBox(height: 12),
        _buildInstructionCard(
          number: '2',
          title: 'Verifica la Red Wi-Fi',
          description: 'Ambos equipos deben estar en la misma red Wi-Fi o uno compartiendo zona Wi-Fi portátil (Hotspot).',
          icon: Icons.wifi_tethering_rounded,
        ),
        const SizedBox(height: 12),
        _buildInstructionCard(
          number: '3',
          title: 'Ten el Código QR o PIN a la mano',
          description: 'Escanéalo con la cámara de este teléfono o escribe la llave de acceso de 6 dígitos.',
          icon: Icons.vpn_key_rounded,
        ),
        const SizedBox(height: 28),

        // Botón Continuar
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4353FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text(
              'CONTINUAR A ESCANEAR QR',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            onPressed: () {
              setState(() {
                _currentStep = 1;
              });
            },
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: () {
              setState(() {
                _currentStep = 1;
              });
            },
            child: const Text('O ingresar PIN numérico manualmente'),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionCard({
    required String number,
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF4353FF).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4353FF)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Icon(icon, color: Colors.grey[400], size: 20),
        ],
      ),
    );
  }

  // ==========================================
  // PASO 2: ESCANEAR CÓDIGO QR O INGRESAR PIN
  // ==========================================
  Widget _buildStep2ScanOrPin(ThemeData theme, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Opción A: Botón de Escaneo con Cámara
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E2640), const Color(0xFF14192B)]
                  : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF4353FF).withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF4353FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Opción Recomendada',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4353FF),
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Escanear Código QR en Pantalla',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Apunta con la cámara de este teléfono al código QR que se muestra en tu Caja Principal.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4353FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('ABRIR CÁMARA Y ESCANEAR', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _openCameraScanner,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Divisor visual
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.withOpacity(0.3))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Text(
                'O INGRESAR MANUALMENTE',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500]),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey.withOpacity(0.3))),
          ],
        ),
        const SizedBox(height: 20),

        // Opción B: PIN numérico de 6 dígitos
        TextField(
          controller: _pinController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 6,
          ),
          decoration: InputDecoration(
            labelText: 'Llave de Acceso (PIN de 6 dígitos)',
            hintText: 'Ej: 742918',
            counterText: '',
            prefixIcon: const Icon(Icons.pin_rounded),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 14),

        // IP de la Caja Central
        TextField(
          controller: _ipController,
          keyboardType: TextInputType.datetime,
          decoration: InputDecoration(
            labelText: 'IP Local de la Caja Master',
            hintText: _ipHint ?? 'Ej: 10.185.98.193',
            helperText: 'Ingresa la IP exacta que se muestra en tu Caja Principal',
            prefixIcon: const Icon(Icons.wifi_rounded),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.sync_rounded),
            label: const Text('CONECTAR Y SINCRONIZAR'),
            onPressed: () {
              final pin = _pinController.text.trim();
              if (pin.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ingresa la llave de acceso completa de 6 dígitos.')),
                );
                return;
              }
              final enteredIp = _ipController.text.trim();
              if (enteredIp.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ingresa la IP que se muestra en la Caja Principal (ej. 10.185.98.193).')),
                );
                return;
              }
              setState(() {
                _masterIp = enteredIp;
                _passkey = pin;
                _currentStep = 2;
              });
              _startDirectSync();
            },
          ),
        ),
      ],
    );
  }

  // ==========================================
  // PASO 3: SINCRONIZACIÓN Y CELEBRACIÓN DE ÉXITO
  // ==========================================
  Widget _buildStep3SyncAndSuccess(ThemeData theme, bool isDark) {
    if (_isSyncing) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  color: Color(0xFF4353FF),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Sincronizando con Caja Central...',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Descargando catálogo de productos, categorías y configuración desde ${_masterIp ?? "Caja Master"}...',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_syncSuccess) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF00D084),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 54),
            ),
            const SizedBox(height: 20),
            const Text(
              '¡Equipo Vinculado con Éxito!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
            const SizedBox(height: 8),
            Text(
              'Este teléfono ahora está conectado como terminal secundaria de:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
            const SizedBox(height: 12),

            // Tarjeta de Resumen de la Bodega
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF00D084).withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.storefront_rounded, color: Color(0xFF00D084)),
                      const SizedBox(width: 8),
                      Text(
                        _businessName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('$_importedProductsCount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          const Text('Productos', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                      Container(width: 1, height: 28, color: Colors.grey.withOpacity(0.2)),
                      const Column(
                        children: [
                          Text('Secundario', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF4353FF))),
                          Text('Rol de Terminal', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                  if (_passkey != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Llave de acceso autorizada: $_passkey',
                      style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4353FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.rocket_launch_rounded),
                label: const Text(
                  'COMENZAR A OPERAR BODEGO',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                onPressed: _finishAndEnterApp,
              ),
            ),
          ],
        ),
      );
    }

    // Si falló la conexión directa por Wi-Fi: Fallback amigable
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _syncErrorMessage ?? 'No se pudo conectar directamente por Wi-Fi.',
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Text(
          'Alternativa: Importar Catálogo (WhatsApp o Archivo)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 6),
        const Text(
          'En tu Caja Principal presiona "Exportar Catálogo para WhatsApp". Luego pega ese texto aquí:',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _fallbackJsonController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Pega el texto del catálogo aquí...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 14),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4353FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final text = _fallbackJsonController.text.trim();
              if (text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pega primero el texto del catálogo.')),
                );
                return;
              }
              _applySnapshot(text);
            },
            child: const Text('IMPORTAR Y FINALIZAR'),
          ),
        ),
        const SizedBox(height: 12),

        Center(
          child: TextButton.icon(
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar conexión directa Wi-Fi'),
            onPressed: _startDirectSync,
          ),
        ),
        Center(
          child: TextButton.icon(
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Volver a escanear QR o editar IP'),
            onPressed: () {
              setState(() {
                _currentStep = 1;
                _syncErrorMessage = null;
              });
            },
          ),
        ),
      ],
    );
  }
}
