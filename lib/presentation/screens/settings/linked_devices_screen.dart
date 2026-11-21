import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:bodego/core/services/google_sheets_sync_service.dart';
import 'package:bodego/core/services/sync_queue_service.dart';
import 'package:bodego/core/services/license_service.dart';
import 'package:bodego/core/services/device_pairing_service.dart';
import 'package:bodego/data/models/google_sheets_config.dart';
import 'package:bodego/data/models/linked_device.dart';
import 'package:bodego/data/repositories/business_config_repository.dart';
import 'package:bodego/presentation/widgets/modern_barcode_scanner.dart';

/// Pantalla moderna para Gestión Multi-Equipo y Sincronización en la Nube
/// con Google Sheets como base de datos y respaldos centralizados.
class LinkedDevicesScreen extends StatefulWidget {
  const LinkedDevicesScreen({super.key});

  @override
  State<LinkedDevicesScreen> createState() => _LinkedDevicesScreenState();
}

class _LinkedDevicesScreenState extends State<LinkedDevicesScreen>
    with SingleTickerProviderStateMixin {
  final GoogleSheetsSyncService _syncService = GoogleSheetsSyncService();
  final SyncQueueService _queueService = SyncQueueService();
  final DevicePairingService _pairingService = DevicePairingService();

  late TabController _tabController;

  GoogleSheetsConfig _config = const GoogleSheetsConfig();
  bool _isLoading = true;
  bool _isTesting = false;
  bool _isSyncing = false;

  List<LinkedDevice> _devices = [];
  bool _isSecondary = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final conf = await _syncService.getConfig();
    final devs = await _pairingService.getLinkedDevices();
    final isSec = await _pairingService.isSecondaryDevice();
    await _queueService.updatePendingCount();

    if (mounted) {
      setState(() {
        _config = conf;
        _devices = devs;
        _isSecondary = isSec;
        _isLoading = false;
      });
    }

    // Si aún no está autenticado en la nube (creado offline), intentar vincular en caliente
    if (!conf.isTenantAuthenticated) {
      _syncService.ensureTenantRegistered().then((registered) {
        if (registered && mounted) {
          _syncService.getConfig().then((newConf) {
            if (mounted) setState(() => _config = newConf);
          });
        }
      });
    }
  }

  Future<void> _handleTestAndConnectCloud() async {
    setState(() => _isTesting = true);

    final pingRes = await _syncService.testConnection();
    if (!pingRes.success) {
      if (mounted) {
        setState(() => _isTesting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(pingRes.message),
            backgroundColor: Colors.red[800],
          ),
        );
      }
      return;
    }

    // Servidor activo: asegurar registro de tienda si no estaba autenticado
    if (!_config.isTenantAuthenticated) {
      final regOk = await _syncService.ensureTenantRegistered();
      final updatedConf = await _syncService.getConfig();
      if (mounted) {
        setState(() {
          _isTesting = false;
          _config = updatedConf;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(regOk
                ? '¡Conexión exitosa! Negocio vinculado con su hoja privada en Google Sheets.'
                : 'Servidor alcanzable. Tu cuenta se sincronizará automáticamente.'),
            backgroundColor: regOk ? Colors.green[800] : Colors.orange[800],
          ),
        );
      }
      return;
    }

    if (mounted) {
      setState(() => _isTesting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Conexión activa con la Nube!\nHoja asignada: ${_config.sheetName ?? "BodeGo Cloud"}'),
          backgroundColor: Colors.green[800],
        ),
      );
    }
  }

  Future<void> _handleSyncNow() async {
    setState(() => _isSyncing = true);
    final res = await _syncService.syncNow();
    await _queueService.updatePendingCount();
    final updatedConf = await _syncService.getConfig();

    if (mounted) {
      setState(() {
        _isSyncing = false;
        _config = updatedConf;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: res.success ? Colors.green[800] : Colors.orange[800],
        ),
      );
    }
  }

  Future<void> _handleFullBackup() async {
    if (!_config.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google Sheets no está configurado')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Crear Respaldo en la Nube'),
        content: const Text(
          'Se enviará todo el catálogo de productos, clientes, categorías y configuración comercial hacia tu hoja de cálculo en Google Sheets.\n\n¿Deseas continuar?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4353FF)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Subir Respaldo', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isSyncing = true);
    final res = await _syncService.createFullBackup();
    final updatedConf = await _syncService.getConfig();

    if (mounted) {
      setState(() {
        _isSyncing = false;
        _config = updatedConf;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: res.success ? Colors.green[800] : Colors.red[800],
        ),
      );
    }
  }

  Future<void> _handleRestoreFromSheets() async {
    if (!_config.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google Sheets no está configurado')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar desde Google Sheets'),
        content: const Text(
          'Se descargarán todos los productos, categorías y clientes desde tu hoja de cálculo hacia este dispositivo.\n\nLos productos existentes con el mismo código o nombre serán actualizados.\n\n¿Deseas proceder?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Descargar Catálogo', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isSyncing = true);
    final res = await _syncService.restoreCatalogFromSheets();
    final updatedConf = await _syncService.getConfig();

    if (mounted) {
      setState(() {
        _isSyncing = false;
        _config = updatedConf;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: res.success ? Colors.teal[800] : Colors.red[800],
        ),
      );
    }
  }

  /// Escanear código QR desde el equipo secundario para conectarse en 1 toque
  Future<void> _scanPairingQr() async {
    final scanned = await ModernBarcodeScanner.scanSingle(
      context,
      title: 'Vincular con Caja Principal',
      subtitle: 'Apunta al código QR generado en la Caja Master',
    );

    if (scanned != null && mounted) {
      final clean = scanned.trim();
      if (clean.startsWith('BODEGO_CLOUD_PAIR:')) {
        try {
          final b64 = clean.substring('BODEGO_CLOUD_PAIR:'.length);
          final raw = utf8.decode(base64Url.decode(b64));
          final data = jsonDecode(raw) as Map<String, dynamic>;

          final bizName = data['businessName'] as String? ?? 'BodeGo';
          final masterId = data['masterId'] as String? ?? 'BDG-MASTER';
          final businessId = data['businessId'] as String?;
          final authToken = data['authToken'] as String?;
          final sheetName = data['sheetName'] as String? ?? 'BodeGo - $bizName';

          final newConf = _config.copyWith(
            businessId: businessId,
            authToken: authToken,
            sheetName: sheetName,
            isEnabled: true,
          );
          await _syncService.saveConfig(newConf);
          setState(() => _config = newConf);

          // Registrar rol secundario
          await _pairingService.setSecondaryRole(
            masterMachineId: masterId,
            masterIp: 'cloud',
            businessName: bizName,
          );
          _isSecondary = true;

          // Descargar catálogo de inmediato
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('¡Equipo vinculado! Descargando catálogo desde Google Sheets...'),
                backgroundColor: Colors.blueAccent,
              ),
            );
          }

          await _handleRestoreFromSheets();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al procesar el código QR: $e')),
            );
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El código QR escaneado no corresponde a BodeGo Cloud')),
        );
      }
    }
  }

  /// Muestra el modal con el código QR para que otro equipo lo escanee
  Future<void> _showGeneratePairingQrModal() async {
    final license = await LicenseService().init();
    final biz = await BusinessConfigRepository().getConfig();

    final payload = {
      'protocol': 'bodego_cloud_sync_v2',
      'masterId': license.machineId,
      'businessName': biz.businessName,
      'businessId': _config.businessId,
      'authToken': _config.authToken,
      'sheetName': _config.sheetName,
      'createdAt': DateTime.now().toIso8601String(),
    };

    final qrString = 'BODEGO_CLOUD_PAIR:${base64UrlEncode(utf8.encode(jsonEncode(payload)))}';

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 18),
              const Text('Vincular Terminal Secundaria', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              const SizedBox(height: 6),
              const Text(
                'En el segundo teléfono, abre BodeGo y escanea este código QR.\nSe vinculará la base de datos de Google Sheets de forma instantánea.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4)),
                  ],
                ),
                child: QrImageView(
                  data: qrString,
                  version: QrVersions.auto,
                  size: 210,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1E2640)),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF1E2640)),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Negocio: ${biz.businessName}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Multi-Equipo & Sincronización', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4353FF),
          indicatorColor: const Color(0xFF4353FF),
          tabs: const [
            Tab(icon: Icon(Icons.cloud_sync_rounded), text: 'Nube Google Sheets'),
            Tab(icon: Icon(Icons.devices_rounded), text: 'Vincular Equipos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ==========================================
          // PESTAÑA 1: NUBE GOOGLE SHEETS
          // ==========================================
          ListView(
            padding: const EdgeInsets.all(18),
            children: [
              // Tarjeta de Estado
              _buildCloudStatusCard(theme),
              const SizedBox(height: 18),

              // Tarjeta Segura del Servicio Cloud (Sin URL expuesta)
              _buildCloudSecurityInfoCard(theme),

              const SizedBox(height: 18),

              // Botón Principal: Sincronizar Ahora
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSyncing ? null : _handleSyncNow,
                  icon: _isSyncing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.sync_rounded, color: Colors.white),
                  label: Text(
                    _isSyncing ? 'Sincronizando con la nube...' : 'Sincronizar Todo Ahora',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4353FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Tarjetas de Acciones Rápidas (Respaldo y Restauración)
              Row(
                children: [
                  Expanded(
                    child: _buildActionTile(
                      icon: Icons.cloud_upload_rounded,
                      color: Colors.indigo,
                      title: 'Crear Respaldo',
                      subtitle: 'Sube todo el catálogo a Google Sheets',
                      onTap: _isSyncing ? null : _handleFullBackup,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionTile(
                      icon: Icons.cloud_download_rounded,
                      color: Colors.teal,
                      title: 'Restaurar Datos',
                      subtitle: 'Descarga catálogo de la nube',
                      onTap: _isSyncing ? null : _handleRestoreFromSheets,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Switch: Sincronización Automática en Segundo Plano
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: SwitchListTile(
                  title: const Text('Sincronización Automática', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Envía los movimientos en segundo plano al emitir cada venta o abono.', style: TextStyle(fontSize: 12)),
                  value: _config.autoSyncOnSale,
                  activeColor: const Color(0xFF4353FF),
                  onChanged: (val) async {
                    final updated = _config.copyWith(autoSyncOnSale: val);
                    await _syncService.saveConfig(updated);
                    setState(() => _config = updated);
                  },
                ),
              ),
            ],
          ),

          // ==========================================
          // PESTAÑA 2: VINCULAR EQUIPOS (MULTI-EQUIPO)
          // ==========================================
          ListView(
            padding: const EdgeInsets.all(18),
            children: [
              // Rol Actual
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: _isSecondary ? Colors.orange.withOpacity(0.12) : const Color(0xFF4353FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _isSecondary ? Colors.orange.withOpacity(0.4) : const Color(0xFF4353FF).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(_isSecondary ? Icons.phone_android_rounded : Icons.store_rounded, color: _isSecondary ? Colors.orange[800] : const Color(0xFF4353FF), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isSecondary ? 'Terminal Secundaria' : 'Caja Principal (Master)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _isSecondary ? Colors.orange[900] : const Color(0xFF4353FF)),
                          ),
                          Text(
                            _isSecondary ? 'Sincronizada con la nube de Google Sheets' : 'Administra el catálogo maestro y vincula otros móviles',
                            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Botones de Vinculación
              if (!_isSecondary) ...[
                // Caja Master: Generar QR
                ElevatedButton.icon(
                  onPressed: _showGeneratePairingQrModal,
                  icon: const Icon(Icons.qr_code_rounded, color: Colors.white),
                  label: const Text('Generar QR para Nuevo Equipo', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4353FF),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Botón Escanear QR
              OutlinedButton.icon(
                onPressed: _scanPairingQr,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: Text(_isSecondary ? 'Re-vincular escaneando QR' : 'Escanear QR de otra Caja'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),

              const SizedBox(height: 24),
              const Text('Dispositivos Registrados', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),

              if (_devices.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: const Center(
                    child: Text(
                      'No hay terminales secundarias registradas aún.\nGenera el código QR para conectar el celular del dueño o de otro cajero.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ),
                )
              else
                ..._devices.map((d) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF4353FF).withOpacity(0.12),
                          child: const Icon(Icons.smartphone_rounded, color: Color(0xFF4353FF)),
                        ),
                        title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text('ID: ${d.machineId} • Rol: ${d.role}', style: const TextStyle(fontSize: 12)),
                        trailing: Icon(d.isActive ? Icons.check_circle_rounded : Icons.pause_circle_rounded, color: d.isActive ? Colors.green : Colors.grey),
                      ),
                    )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCloudStatusCard(ThemeData theme) {
    return ValueListenableBuilder<int>(
      valueListenable: _queueService.pendingCountNotifier,
      builder: (context, pendingCount, _) {
        final isLinked = _config.isTenantAuthenticated;
        final hasPending = pendingCount > 0;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isLinked
                  ? [const Color(0xFF1E2640), const Color(0xFF2C3968)]
                  : [Colors.grey[800]!, Colors.grey[900]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isLinked ? Icons.cloud_done_rounded : Icons.cloud_queue_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Google Sheets Cloud', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(
                            _config.sheetName ?? (isLinked ? 'Hoja Conectada' : 'Modo Offline (Local)'),
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isLinked ? Colors.greenAccent.withOpacity(0.2) : Colors.orangeAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isLinked ? 'ACTIVO' : 'MODO OFFLINE',
                      style: TextStyle(
                        color: isLinked ? Colors.greenAccent : Colors.orangeAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 26),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Última Sincronización', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
                      const SizedBox(height: 2),
                      Text(
                        _config.lastSyncAt != null
                            ? '${_config.lastSyncAt!.day}/${_config.lastSyncAt!.month} ${_config.lastSyncAt!.hour}:${_config.lastSyncAt!.minute.toString().padLeft(2, '0')}'
                            : 'Nunca',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Cola Offline', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (hasPending)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: const BoxDecoration(color: Colors.amberAccent, shape: BoxShape.circle),
                            ),
                          Text(
                            hasPending ? '$pendingCount pendientes' : 'Al día',
                            style: TextStyle(
                              color: hasPending ? Colors.amberAccent : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCloudSecurityInfoCard(ThemeData theme) {
    final isLinked = _config.isTenantAuthenticated;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLinked
              ? const Color(0xFF00D084).withOpacity(0.3)
              : Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isLinked ? Icons.security_rounded : Icons.cloud_off_rounded,
                    color: isLinked ? const Color(0xFF00D084) : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Servicio BodeGo Cloud',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isLinked
                      ? const Color(0xFF00D084).withOpacity(0.12)
                      : Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isLinked ? 'CONECTADO' : 'MODO OFFLINE',
                  style: TextStyle(
                    color: isLinked ? const Color(0xFF00A86B) : Colors.orange[800],
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Base de Datos:', _config.sheetName ?? 'BodeGo POS Local'),
          const SizedBox(height: 6),
          _buildInfoRow('ID Cloud:', _config.businessId ?? 'Se vinculará automáticamente al detectar red'),
          if (_config.ownerEmail != null && _config.ownerEmail!.isNotEmpty) ...[
            const SizedBox(height: 6),
            _buildInfoRow('Cuenta:', _config.ownerEmail!),
          ],
          if (_config.spreadsheetId != null && _config.spreadsheetId!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF4353FF).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF4353FF).withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.table_chart_rounded, size: 20, color: Color(0xFF4353FF)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hoja privada en tu Google Drive:',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                        Text(
                          _config.sheetName ?? 'BodeGo - Minimarket',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4353FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      final url = 'https://docs.google.com/spreadsheets/d/${_config.spreadsheetId}/edit';
                      Clipboard.setData(ClipboardData(text: url));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Enlace copiado al portapapeles:\n$url'),
                          backgroundColor: const Color(0xFF00A86B),
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 13),
                    label: const Text('Copiar Link', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'El enlace de sincronización está protegido internamente. Si creaste tu cuenta sin conexión, se auto-registrará al haber Internet.',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white60 : Colors.grey[600],
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isTesting ? null : _handleTestAndConnectCloud,
              icon: _isTesting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_protected_setup_rounded, size: 18),
              label: Text(_isTesting ? 'Verificando servicio...' : 'Comprobar Conexión Cloud'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 95,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[600], height: 1.25)),
          ],
        ),
      ),
    );
  }
}
