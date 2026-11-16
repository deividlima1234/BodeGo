import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bodego/core/services/license_service.dart';
import 'package:bodego/data/models/license_info.dart';

/// Modal secreto exclusivo para el Desarrollador y Propietario de BodeGo.
/// Permite generar claves de activación offline para clientes y diagnosticar el estado del dispositivo.
class DeveloperPanelModal extends StatefulWidget {
  const DeveloperPanelModal({super.key});

  /// Abre el modal solicitando autenticación de desarrollador
  static Future<void> show(BuildContext context) async {
    final passwordController = TextEditingController();
    bool obscure = true;

    final isAuthenticated = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          return AlertDialog(
            backgroundColor: theme.scaffoldBackgroundColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.amber),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Consola Desarrollador',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Acceso restringido para el desarrollador de EddamCore. Ingresa la clave maestra para continuar:',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: obscure,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Contraseña Maestra',
                    prefixIcon: const Icon(Icons.key_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onSubmitted: (val) {
                    if (LicenseService.validateDevPassword(val)) {
                      Navigator.pop(ctx, true);
                    } else {
                      HapticFeedback.vibrate();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Contraseña de desarrollador incorrecta.'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4353FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  if (LicenseService.validateDevPassword(passwordController.text)) {
                    Navigator.pop(ctx, true);
                  } else {
                    HapticFeedback.vibrate();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Contraseña de desarrollador incorrecta.'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                },
                child: const Text('Desbloquear'),
              ),
            ],
          );
        },
      ),
    );

    if (isAuthenticated == true && context.mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const DeveloperPanelModal(),
      );
    }
  }

  @override
  State<DeveloperPanelModal> createState() => _DeveloperPanelModalState();
}

class _DeveloperPanelModalState extends State<DeveloperPanelModal>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final LicenseService _licenseService = LicenseService();

  // Controladores de Generador
  final TextEditingController _targetMachineIdController = TextEditingController();
  String _selectedPlan = 'lifetime';
  String? _generatedCode;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _targetMachineIdController.dispose();
    super.dispose();
  }

  void _generateCode() {
    final inputId = _targetMachineIdController.text.trim();
    if (inputId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa el ID de equipo del cliente (ej: BDG-XXXX-XXXX)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final code = LicenseService.generateActivationCode(
      machineId: inputId,
      planType: _selectedPlan,
    );

    setState(() {
      _generatedCode = code;
    });

    HapticFeedback.mediumImpact();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copiado al portapapeles'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
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

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4353FF).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.terminal_rounded,
                    color: Color(0xFF4353FF),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Panel Desarrollador EddamCore',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      Text(
                        'Generador de Licencias & Control de Hardware',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),

          // Tab Bar
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF4353FF),
            indicatorColor: const Color(0xFF4353FF),
            tabs: const [
              Tab(
                icon: Icon(Icons.key_rounded, size: 20),
                text: 'Generar Licencia Cliente',
              ),
              Tab(
                icon: Icon(Icons.phonelink_setup_rounded, size: 20),
                text: 'Este Dispositivo',
              ),
            ],
          ),

          // Contenido de Tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGeneratorTab(theme, isDark),
                _buildDeviceControlTab(theme, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // TAB 1: Generador de Licencias para clientes
  Widget _buildGeneratorTab(ThemeData theme, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF4353FF).withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF4353FF).withOpacity(0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFF4353FF), size: 22),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'El cliente te envía su ID de Equipo (BDG-XXXX-XXXX). Pégalo aquí para generar su clave de activación offline.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Campo ID de Máquina del Cliente
        TextField(
          controller: _targetMachineIdController,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: 'ID de Equipo del Cliente',
            hintText: 'Ej: BDG-7A9B-4F2E',
            prefixIcon: const Icon(Icons.fingerprint_rounded),
            suffixIcon: IconButton(
              icon: const Icon(Icons.paste_rounded),
              tooltip: 'Pegar del portapapeles',
              onPressed: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                if (data?.text != null) {
                  setState(() {
                    _targetMachineIdController.text = data!.text!.trim();
                  });
                }
              },
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 16),

        // Selector de Plan
        const Text(
          'Tipo de Licencia a Emitir:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildPlanChoiceChip('lifetime', 'De por Vida (Permanente)'),
            _buildPlanChoiceChip('1year', '1 Año (Anual)'),
            _buildPlanChoiceChip('6months', '6 Meses'),
            _buildPlanChoiceChip('1month', '1 Mes'),
          ],
        ),
        const SizedBox(height: 24),

        // Botón Generar
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4353FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text(
              'GENERAR CLAVE DE ACTIVACIÓN',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            onPressed: _generateCode,
          ),
        ),
        const SizedBox(height: 24),

        // Tarjeta con Código Generado
        if (_generatedCode != null) ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E2640), const Color(0xFF14192B)]
                    : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF4353FF).withOpacity(0.4)),
            ),
            child: Column(
              children: [
                const Text(
                  'CÓDIGO DE ACTIVACIÓN EMITIDO',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: Color(0xFF4353FF),
                  ),
                ),
                const SizedBox(height: 10),
                SelectableText(
                  _generatedCode!,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Copiar'),
                        onPressed: () => _copyToClipboard(
                          _generatedCode!,
                          'Código de activación',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text('WhatsApp'),
                        onPressed: () {
                          final msg =
                              '¡Hola! Tu código de activación para BodeGo es:\n\n*$_generatedCode*\n\nIngrésalo en tu pantalla de activación para desbloquear la app.';
                          _copyToClipboard(msg, 'Mensaje para WhatsApp');
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPlanChoiceChip(String planKey, String label) {
    final isSelected = _selectedPlan == planKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF4353FF).withOpacity(0.2),
      onSelected: (val) {
        if (val) {
          setState(() {
            _selectedPlan = planKey;
            if (_targetMachineIdController.text.isNotEmpty) {
              _generateCode();
            }
          });
        }
      },
    );
  }

  // TAB 2: Control y diagnóstico de este dispositivo
  Widget _buildDeviceControlTab(ThemeData theme, bool isDark) {
    return ValueListenableBuilder<LicenseInfo?>(
      valueListenable: _licenseService.licenseNotifier,
      builder: (context, info, _) {
        if (info == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Tarjeta de estado de hardware
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black.withOpacity(0.08),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ID de Este Dispositivo',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        onPressed: () => _copyToClipboard(info.machineId, 'ID de Dispositivo'),
                      ),
                    ],
                  ),
                  Text(
                    info.machineId,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Estado de Licencia:'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: info.isActivated
                              ? Colors.green.withOpacity(0.15)
                              : info.isTrialExpired
                                  ? Colors.red.withOpacity(0.15)
                                  : Colors.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          info.isActivated
                              ? 'ACTIVADA (${info.licenseType.toUpperCase()})'
                              : info.isTrialExpired
                                  ? 'PRUEBA EXPIRADA'
                                  : 'PRUEBA (${info.trialDaysRemaining} DÍAS)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: info.isActivated
                                ? Colors.green
                                : info.isTrialExpired
                                    ? Colors.redAccent
                                    : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Inicio Prueba: ${info.trialStartDate.toString().split('.')[0]}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    'Último Uso: ${info.lastActiveDate.toString().split('.')[0]}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Acciones Rápidas de Prueba:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),

            // Botón 1: Activar de por vida
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              tileColor: Colors.green.withOpacity(0.1),
              leading: const Icon(Icons.verified_rounded, color: Colors.green),
              title: const Text('Activar Directamente (De por Vida)'),
              subtitle: const Text('Aplica licencia permanente a este equipo'),
              onTap: () async {
                await _licenseService.devDirectActivate();
                HapticFeedback.heavyImpact();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('¡Este equipo fue activado con licencia permanente!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 10),

            // Botón 2: Reiniciar Trial a 7 días
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              tileColor: Colors.blue.withOpacity(0.1),
              leading: const Icon(Icons.replay_rounded, color: Colors.blue),
              title: const Text('Reiniciar Prueba a 7 Días'),
              subtitle: const Text('Restaura el contador inicial de prueba'),
              onTap: () async {
                await _licenseService.devResetTrial();
                HapticFeedback.mediumImpact();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Periodo de prueba reiniciado a 7 días.'),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 10),

            // Botón 3: Simular Prueba Expirada
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              tileColor: Colors.red.withOpacity(0.1),
              leading: const Icon(Icons.lock_clock_rounded, color: Colors.redAccent),
              title: const Text('Simular Prueba Expirada'),
              subtitle: const Text('Pone el trial en día 8 para probar la pantalla de bloqueo'),
              onTap: () async {
                await _licenseService.devSimulateExpiredTrial();
                HapticFeedback.mediumImpact();
                if (mounted) {
                  Navigator.pop(context); // Cierra el modal
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Modo de prueba expirada activado. Reabre la app o navega.'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}
