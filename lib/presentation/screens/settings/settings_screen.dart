import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bodego/core/theme/app_theme.dart';
import 'package:bodego/data/local/isar/database_service.dart';
import 'package:bodego/data/models/business_config.dart';
import 'package:bodego/data/models/printer_config.dart';
import 'package:bodego/data/models/sale_ticket.dart';
import 'package:bodego/data/repositories/app_settings_repository.dart';
import 'package:bodego/data/repositories/business_config_repository.dart';
import 'package:bodego/data/repositories/printer_repository.dart';
import 'package:bodego/data/repositories/user_repository.dart';
import 'package:bodego/presentation/screens/auth/pin_login_screen.dart';
import 'package:bodego/presentation/screens/auth/splash_screen.dart';
import 'package:bodego/presentation/screens/pos/widgets/ticket_preview_modal.dart';
import 'package:bodego/presentation/screens/settings/widgets/printer_scanner_modal.dart';
import 'package:bodego/presentation/screens/auth/widgets/legal_terms_modal.dart';
import 'package:bodego/core/services/app_version_service.dart';
import 'package:bodego/core/services/ota_update_service.dart';
import 'package:bodego/presentation/widgets/ota_update_modal.dart';

/// Pantalla completa de Configuración del Sistema BodeGo con categorías colapsables:
/// - Perfil e Identidad del Negocio (Nombre, RUC, Dirección, Teléfono, Logo).
/// - Personalización del Ticket Térmico (Mensaje de despedida, 58/80mm, datos fiscales).
/// - Marca de agua "Tecnología impulsada por EddamCore".
/// - Vista previa del ticket en vivo.
/// - Tema visual (Moderno vs EddamCore Dark).
/// - Gestión de usuarios y acciones del sistema.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final BusinessConfigRepository _businessRepo = BusinessConfigRepository();
  final AppSettingsRepository _settingsRepository = AppSettingsRepository();
  final UserRepository _userRepository = UserRepository();
  final PrinterRepository _printerRepo = PrinterRepository();

  // Controladores de texto
  late final TextEditingController _businessNameController;
  late final TextEditingController _rucController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _footerMessageController;
  late final TextEditingController _customLogoPathController;

  // Estado de secciones colapsables (inicia con 'identity' abierta para acceso inmediato)
  final Set<String> _expandedSections = {'identity'};

  // Estado del negocio y ticket
  String _logoType = 'preset';
  String _logoValue = 'storefront';
  int _paperWidthMm = 58;
  bool _showRuc = true;
  bool _showAddress = true;
  bool _showPhone = true;
  bool _showBarcode = true;
  bool _showEddamCoreBranding = true;

  // Estado de la impresora térmica
  PrinterConfig _printerConfig = const PrinterConfig();

  // Estado de sesión y tema
  String _currentTheme = 'moderno';
  String _cashierName = 'Cargando...';
  String _adminEmail = 'Cargando...';
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _businessNameController = TextEditingController();
    _rucController = TextEditingController();
    _addressController = TextEditingController();
    _phoneController = TextEditingController();
    _footerMessageController = TextEditingController();
    _customLogoPathController = TextEditingController();
    _loadAllSettings();
    _printerRepo.printerNotifier.addListener(_onPrinterChanged);
  }

  @override
  void dispose() {
    _printerRepo.printerNotifier.removeListener(_onPrinterChanged);
    _businessNameController.dispose();
    _rucController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _footerMessageController.dispose();
    _customLogoPathController.dispose();
    super.dispose();
  }

  void _onPrinterChanged() {
    if (mounted) {
      setState(() {
        _printerConfig = _printerRepo.printerNotifier.value ?? _printerConfig;
      });
    }
  }

  Future<void> _loadAllSettings() async {
    final businessConfig = await _businessRepo.getConfig();
    final appSettings = await _settingsRepository.getSettings();
    final users = await _userRepository.getAllUsers();
    final printerConfig = await _printerRepo.getConfig();

    final cashier = users.where((u) => u.role == 'cajero').firstOrNull;
    final admin = users.where((u) => u.role == 'admin').firstOrNull;

    if (mounted) {
      setState(() {
        _businessNameController.text = businessConfig.businessName;
        _rucController.text = businessConfig.ruc;
        _addressController.text = businessConfig.address;
        _phoneController.text = businessConfig.phone;
        _footerMessageController.text = businessConfig.ticketFooterMessage;
        _customLogoPathController.text =
            businessConfig.logoType == 'file' ? businessConfig.logoValue : '';

        _logoType = businessConfig.logoType;
        _logoValue = businessConfig.logoValue;
        _paperWidthMm = businessConfig.paperWidthMm;
        _showRuc = businessConfig.showRucOnTicket;
        _showAddress = businessConfig.showAddressOnTicket;
        _showPhone = businessConfig.showPhoneOnTicket;
        _showBarcode = businessConfig.showBarcodeOnTicket;
        _showEddamCoreBranding = businessConfig.showEddamCoreBranding;

        _printerConfig = printerConfig;
        _currentTheme = appSettings.selectedTheme;
        _cashierName = cashier?.name ?? 'Sin cajero registrado';
        _adminEmail = admin?.email ?? 'Sin admin registrado';
        _isLoading = false;
      });
    }
  }

  BusinessConfig _getCurrentDraftConfig() {
    return BusinessConfig(
      businessName: _businessNameController.text.trim().isNotEmpty
          ? _businessNameController.text.trim()
          : 'MI BODEGA',
      ruc: _rucController.text.trim(),
      address: _addressController.text.trim(),
      phone: _phoneController.text.trim(),
      logoType: _logoType,
      logoValue: _logoType == 'file'
          ? _customLogoPathController.text.trim()
          : _logoValue,
      ticketFooterMessage: _footerMessageController.text.trim(),
      paperWidthMm: _paperWidthMm,
      showRucOnTicket: _showRuc,
      showAddressOnTicket: _showAddress,
      showPhoneOnTicket: _showPhone,
      showBarcodeOnTicket: _showBarcode,
      showEddamCoreBranding: _showEddamCoreBranding,
    );
  }

  Future<void> _saveSettings() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    final newConfig = _getCurrentDraftConfig();
    await _businessRepo.saveConfig(newConfig);
    await _printerRepo.saveConfig(_printerConfig);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text(
                '¡Configuración guardada exitosamente!',
                style: TextStyle(fontWeight: FontWeight.bold),
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

  Future<void> _handleTestPrint() async {
    HapticFeedback.heavyImpact();
    await _printerRepo.printTestTicket(_printerConfig);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.print_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text('¡Ticket de prueba enviado a la impresora con éxito!'),
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

  void _previewTicket() {
    HapticFeedback.lightImpact();
    final draftConfig = _getCurrentDraftConfig();

    final previewTicket = SaleTicket(
      id: 'TKT_PREVIEW',
      ticketNumber: 'TKT-0042',
      date: DateTime.now(),
      total: 19.50,
      isCredit: false,
      cashierName: _cashierName.isNotEmpty ? _cashierName : 'Cajero de Turno',
      businessName: draftConfig.businessName,
      items: [
        SaleTicketItem(
          productId: 1,
          name: 'Leche Gloria Azul 400g',
          quantity: 2,
          unitPrice: 4.50,
          subtotal: 9.00,
        ),
        SaleTicketItem(
          productId: 2,
          name: 'Pan Francés',
          quantity: 10,
          unitPrice: 0.35,
          subtotal: 3.50,
        ),
        SaleTicketItem(
          productId: 3,
          name: 'Gaseosa Inca Kola 500ml',
          quantity: 2,
          unitPrice: 3.50,
          subtotal: 7.00,
        ),
      ],
    );

    TicketPreviewModal.show(context, previewTicket, customConfig: draftConfig);
  }

  void _toggleExpandAll() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_expandedSections.length >= 6) {
        _expandedSections.clear();
      } else {
        _expandedSections.addAll({'identity', 'printer', 'ticket', 'theme', 'users', 'system'});
      }
    });
  }

  Future<void> _changeTheme(BodeGoTheme theme) async {
    final themeName =
        theme == BodeGoTheme.eddamcoreDark ? 'eddamcoreDark' : 'moderno';

    setState(() {
      _currentTheme = themeName;
    });

    await _settingsRepository.updateTheme(themeName);
    AppTheme.setTheme(theme);
  }

  void _showLogoPickerSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Seleccionar Logo del Negocio',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Elige un ícono de alto contraste optimizado para ticketera térmica o especifica una imagen:',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),

                  // Galería de Presets Térmicos
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: BusinessConfig.presets.entries.map((entry) {
                      final isSelected =
                          _logoType == 'preset' && _logoValue == entry.key;

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _logoType = 'preset';
                            _logoValue = entry.key;
                          });
                          setModalState(() {});
                          Navigator.pop(ctx);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 80,
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primary.withOpacity(0.12)
                                : theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : Colors.grey.withOpacity(0.3),
                              width: isSelected ? 2.0 : 1.0,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                entry.value.icon,
                                size: 30,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                entry.value.label,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 10),

                  // Opción de Ruta de Imagen Local
                  Row(
                    children: [
                      const Icon(Icons.photo_library_rounded, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'O usar ruta de foto / imagen local:',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customLogoPathController,
                          decoration: InputDecoration(
                            hintText: '/sdcard/Download/logo_bodega.png',
                            labelText: 'Ruta del archivo de imagen',
                            isDense: true,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final path = _customLogoPathController.text.trim();
                          if (path.isNotEmpty) {
                            setState(() {
                              _logoType = 'file';
                              _logoValue = path;
                            });
                            Navigator.pop(ctx);
                          }
                        },
                        child: const Text('Aplicar'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
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

    final bool allExpanded = _expandedSections.length >= 5;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración del Sistema'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Vista Previa del Ticket',
            icon: const Icon(Icons.receipt_long_rounded),
            onPressed: _previewTicket,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: TextButton.icon(
              onPressed: _isSaving ? null : _saveSettings,
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded, size: 18),
              label: const Text('Guardar'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Barra de control rápido: "Expandir todo / Colapsar todo"
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Categorías de Ajustes',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: _toggleExpandAll,
                  icon: Icon(
                    allExpanded
                        ? Icons.unfold_less_rounded
                        : Icons.unfold_more_rounded,
                    size: 16,
                  ),
                  label: Text(
                    allExpanded ? 'Colapsar todo' : 'Expandir todo',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ==========================================
            // CATEGORÍA 1: IDENTIDAD Y DATOS DE LA BODEGA
            // ==========================================
            _buildCollapsibleSection(
              id: 'identity',
              title: 'Identidad y Datos de la Bodega',
              subtitle: 'Nombre comercial, logo, RUC y teléfono',
              icon: Icons.storefront_rounded,
              badgeText: _businessNameController.text.trim().isNotEmpty
                  ? _businessNameController.text.trim()
                  : null,
              child: Column(
                children: [
                  // Logo Selector con Vista Previa
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _showLogoPickerSheet,
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.primary,
                              width: 2.0,
                            ),
                          ),
                          child: Center(
                            child: _buildCurrentLogoPreview(theme),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Logo para Impresión y Marca',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _logoType == 'preset'
                                  ? 'Preset: ${BusinessConfig.presets[_logoValue]?.label ?? "Bodega"}'
                                  : 'Foto personalizada seleccionada',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 4),
                            OutlinedButton.icon(
                              onPressed: _showLogoPickerSheet,
                              icon: const Icon(Icons.brush_rounded, size: 13),
                              label: const Text('Cambiar Logo / Ícono',
                                  style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 10),

                  // Nombre de la Bodega
                  TextField(
                    controller: _businessNameController,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Nombre Comercial de la Bodega *',
                      hintText: 'Ej. Bodega Mascherano',
                      prefixIcon: const Icon(Icons.store_rounded),
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // RUC / DNI Fiscal
                  TextField(
                    controller: _rucController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'RUC / Identificación Fiscal',
                      hintText: 'Ej. RUC: 20601234567',
                      prefixIcon: const Icon(Icons.badge_rounded),
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Dirección
                  TextField(
                    controller: _addressController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Dirección Comercial del Local',
                      hintText: 'Ej. Av. Principal 450 - San Borja',
                      prefixIcon: const Icon(Icons.location_on_rounded),
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Teléfono / WhatsApp
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Teléfono / WhatsApp de Pedidos',
                      hintText: 'Ej. +51 987 654 321',
                      prefixIcon: const Icon(Icons.phone_android_rounded),
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),

            // ==========================================
            // CATEGORÍA 2: IMPRESORA TÉRMICA Y DISPOSITIVOS
            // ==========================================
            _buildCollapsibleSection(
              id: 'printer',
              title: 'Impresora Térmica y Dispositivos',
              subtitle: 'Bluetooth, Red WiFi o USB para tickets',
              icon: Icons.print_rounded,
              badgeText: _printerConfig.isConnected
                  ? 'Activa (${_printerConfig.paperWidthMm}mm)'
                  : 'Sin vincular',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tarjeta de estado de la impresora actual
                  if (_printerConfig.isConnected) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withOpacity(0.35)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.print_rounded,
                                  color: Colors.green[800],
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _printerConfig.deviceName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_printerConfig.connectionType.toUpperCase()} • ${_printerConfig.deviceAddress}',
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 10.5,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.link_off_rounded, color: Colors.redAccent, size: 20),
                                tooltip: 'Desvincular impresora',
                                onPressed: () async {
                                  await _printerRepo.disconnectPrinter();
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _handleTestPrint,
                                  icon: const Icon(Icons.print_rounded, size: 14),
                                  label: const Text('Probar Impresión', style: TextStyle(fontSize: 11)),
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => PrinterScannerModal.show(context),
                                  icon: const Icon(Icons.sync_rounded, size: 14),
                                  label: const Text('Cambiar Equipo', style: TextStyle(fontSize: 11)),
                                  style: ElevatedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Estado Desconectado / Sin Vincular
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.25)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.print_disabled_rounded, size: 36, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          const Text(
                            'No hay impresora vinculada',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Escanea y vincula tu ticketera Bluetooth, WiFi o USB para emitir comprobantes físicos.',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => PrinterScannerModal.show(context),
                              icon: const Icon(Icons.radar_rounded, size: 18),
                              label: const Text('Escanear y Conectar Impresora'),
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 11),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 6),

                  // Automatizaciones de caja
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Impresión automática al cobrar', style: TextStyle(fontSize: 13)),
                    subtitle: const Text('Emite el ticket inmediatamente al registrar la venta', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    value: _printerConfig.autoPrintOnSale,
                    onChanged: (val) {
                      setState(() {
                        _printerConfig = _printerConfig.copyWith(autoPrintOnSale: val);
                      });
                    },
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Pitido / Alerta sonora al imprimir', style: TextStyle(fontSize: 13)),
                    subtitle: const Text('Emite un sonido de confirmación al terminar la impresión', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    value: _printerConfig.soundOnPrint,
                    onChanged: (val) {
                      setState(() {
                        _printerConfig = _printerConfig.copyWith(soundOnPrint: val);
                      });
                    },
                  ),
                  const SizedBox(height: 4),

                  // Número de copias
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Número de Copias por Venta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                          Text('1 copia para cliente o duplicado de control', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                      SegmentedButton<int>(
                        style: SegmentedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        segments: const [
                          ButtonSegment<int>(value: 1, label: Text('1 Copia')),
                          ButtonSegment<int>(value: 2, label: Text('2 Copias')),
                        ],
                        selected: {_printerConfig.numberOfCopies},
                        onSelectionChanged: (newSelection) {
                          setState(() {
                            _printerConfig = _printerConfig.copyWith(numberOfCopies: newSelection.first);
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ==========================================
            // CATEGORÍA 3: PERSONALIZACIÓN DE TICKETS
            // ==========================================
            _buildCollapsibleSection(
              id: 'ticket',
              title: 'Personalización de Tickets e Impresión',
              subtitle: 'Mensaje de pie, ancho 58/80mm y datos fiscales',
              icon: Icons.receipt_long_rounded,
              badgeText: '$_paperWidthMm mm',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mensaje de Despedida / Pie de Ticket',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _footerMessageController,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: '¡GRACIAS POR SU COMPRA!\nVUELVA PRONTO',
                      helperText:
                          'Aparece centrado al final de cada comprobante emitido.',
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Ancho de papel: 58mm o 80mm
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ancho de Papel Térmico',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Estándar POS portátil (58mm) o de mesa (80mm)',
                              style:
                                  TextStyle(fontSize: 11, color: Colors.grey),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SegmentedButton<int>(
                        style: SegmentedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        segments: const [
                          ButtonSegment<int>(value: 58, label: Text('58 mm')),
                          ButtonSegment<int>(value: 80, label: Text('80 mm')),
                        ],
                        selected: {_paperWidthMm},
                        onSelectionChanged: (newSelection) {
                          setState(() {
                            _paperWidthMm = newSelection.first;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 4),

                  // Switches de datos en ticket
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Mostrar RUC en el comprobante',
                        style: TextStyle(fontSize: 13)),
                    subtitle: const Text('Imprime el RUC debajo del nombre',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                    value: _showRuc,
                    onChanged: (val) => setState(() => _showRuc = val),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Mostrar Dirección en el comprobante',
                        style: TextStyle(fontSize: 13)),
                    subtitle: const Text('Ubicación física del establecimiento',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                    value: _showAddress,
                    onChanged: (val) => setState(() => _showAddress = val),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Mostrar Teléfono / WhatsApp',
                        style: TextStyle(fontSize: 13)),
                    subtitle: const Text('Número de contacto para clientes',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                    value: _showPhone,
                    onChanged: (val) => setState(() => _showPhone = val),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Mostrar Código de Barras decorativo',
                        style: TextStyle(fontSize: 13)),
                    subtitle: const Text('Simulación gráfica al pie del ticket',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                    value: _showBarcode,
                    onChanged: (val) => setState(() => _showBarcode = val),
                  ),

                  // Switch Marca de Agua EddamCore
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeColor: const Color(0xFF4353FF),
                    title: const Row(
                      children: [
                        Icon(Icons.bolt_rounded,
                            size: 16, color: Color(0xFF4353FF)),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Marca de Agua "EddamCore"',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: const Text(
                        'Insignia "Tecnología impulsada por EddamCore" al pie del comprobante',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                    value: _showEddamCoreBranding,
                    onChanged: (val) =>
                        setState(() => _showEddamCoreBranding = val),
                  ),

                  const SizedBox(height: 12),

                  // Botón de Vista Previa del Ticket
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _previewTicket,
                      icon: const Icon(Icons.remove_red_eye_rounded, size: 18),
                      label: const Text('Ver Vista Previa del Ticket en Vivo'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ==========================================
            // CATEGORÍA 3: TEMA VISUAL DE LA APP
            // ==========================================
            _buildCollapsibleSection(
              id: 'theme',
              title: 'Tema Visual de la Aplicación',
              subtitle: 'Estilo y colores de la interfaz',
              icon: Icons.palette_rounded,
              badgeText: _currentTheme == 'eddamcoreDark'
                  ? 'EddamCore Dark'
                  : 'Moderno',
              child: Row(
                children: [
                  Expanded(
                    child: _buildThemeCard(
                      title: 'Moderno',
                      subtitle: 'Blanco / Azul Rey',
                      isSelected: _currentTheme == 'moderno',
                      primaryColor: const Color(0xFF4353FF),
                      backgroundColor: const Color(0xFFF8F9FE),
                      surfaceColor: const Color(0xFFE8EBFA),
                      onTap: () => _changeTheme(BodeGoTheme.moderno),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildThemeCard(
                      title: 'EddamCore Dark',
                      subtitle: 'Negro / Rojo Neón',
                      isSelected: _currentTheme == 'eddamcoreDark',
                      primaryColor: const Color(0xFFFF0033),
                      backgroundColor: const Color(0xFF000000),
                      surfaceColor: const Color(0xFF1A1A1A),
                      onTap: () => _changeTheme(BodeGoTheme.eddamcoreDark),
                    ),
                  ),
                ],
              ),
            ),

            // ==========================================
            // CATEGORÍA 4: USUARIOS Y SEGURIDAD
            // ==========================================
            _buildCollapsibleSection(
              id: 'users',
              title: 'Usuarios y Seguridad',
              subtitle: 'Sesión activa y control de acceso',
              icon: Icons.shield_rounded,
              badgeText: _cashierName.split(' ').first,
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      child: Icon(Icons.badge_rounded),
                    ),
                    title: const Text('Cajero de Turno'),
                    subtitle: Text(_cashierName),
                    trailing: const Chip(
                      label: Text('PIN 4 dígitos', style: TextStyle(fontSize: 11)),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      child: Icon(Icons.admin_panel_settings_rounded),
                    ),
                    title: const Text('Administrador'),
                    subtitle: Text(_adminEmail),
                    trailing: const Chip(
                      label: Text('Acceso Total', style: TextStyle(fontSize: 11)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Botón Principal de Guardado
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveSettings,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_rounded),
                label: Text(
                  _isSaving
                      ? 'Guardando configuración...'
                      : 'Guardar Toda la Configuración',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Footer Oficial con Marca EddamCore
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.withOpacity(0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt_rounded,
                            size: 15, color: Color(0xFF4353FF)),
                        const SizedBox(width: 6),
                        Text(
                          'Tecnología impulsada por EddamCore',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Botón manual de búsqueda de actualización OTA
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      side: BorderSide(
                        color: theme.colorScheme.primary.withOpacity(0.35),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    icon: const Icon(Icons.system_update_rounded, size: 16),
                    label: const Text(
                      'Buscar Actualizaciones de la APP',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: _checkOtaUpdateManually,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${AppVersionService.displayLabel} • eddamcore.com',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => LegalTermsModal.show(context),
                    icon: const Icon(Icons.gavel_rounded, size: 14),
                    label: const Text(
                      'Términos y Privacidad (EddamCore)',
                      style: TextStyle(
                        fontSize: 11.5,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF4353FF),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Verifica manualmente si hay actualizaciones OTA en GitHub mostrando avisos en pantalla
  Future<void> _checkOtaUpdateManually() async {
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text('Buscando actualizaciones en GitHub...'),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final result = await OtaUpdateService.checkForUpdate();

    if (!mounted) return;
    messenger.hideCurrentSnackBar();

    if (result != null) {
      OtaUpdateModal.show(context, result);
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '¡BodeGo está al día! Tienes la última versión (${AppVersionService.displayLabel}).',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF00D084),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  /// Widget contenedor de categoría colapsable con animación suave
  Widget _buildCollapsibleSection({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    String? badgeText,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final isExpanded = _expandedSections.contains(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExpanded
              ? theme.colorScheme.primary.withOpacity(0.35)
              : Colors.grey.withOpacity(0.2),
          width: isExpanded ? 1.5 : 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  if (isExpanded) {
                    _expandedSections.remove(id);
                  } else {
                    _expandedSections.add(id);
                  }
                });
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isExpanded
                            ? theme.colorScheme.primary.withOpacity(0.12)
                            : theme.colorScheme.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        size: 20,
                        color: theme.colorScheme.primary,
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
                                  title,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (badgeText != null &&
                                  badgeText.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    badgeText,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: isExpanded
                            ? theme.colorScheme.primary
                            : Colors.grey[500],
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: child,
                  ),
                ],
              ),
              secondChild: const SizedBox.shrink(),
              crossFadeState: isExpanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 240),
              firstCurve: Curves.easeInOut,
              secondCurve: Curves.easeInOut,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentLogoPreview(ThemeData theme) {
    if (_logoType == 'file' && _logoValue.isNotEmpty) {
      final file = File(_logoValue);
      if (file.existsSync()) {
        return ClipOval(
          child: Image.file(
            file,
            width: 52,
            height: 52,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Icon(
              Icons.storefront_rounded,
              color: theme.colorScheme.primary,
              size: 28,
            ),
          ),
        );
      }
    }

    final entry = BusinessConfig.presets[_logoValue] ??
        BusinessConfig.presets['storefront']!;

    return Icon(
      entry.icon,
      color: theme.colorScheme.primary,
      size: 28,
    );
  }

  Widget _buildThemeCard({
    required String title,
    required String subtitle,
    required bool isSelected,
    required Color primaryColor,
    required Color backgroundColor,
    required Color surfaceColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: theme.scaffoldBackgroundColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? theme.colorScheme.primary : Colors.transparent,
              width: 2.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(7)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle_rounded,
                      color: theme.colorScheme.primary,
                      size: 16,
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10.5,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
