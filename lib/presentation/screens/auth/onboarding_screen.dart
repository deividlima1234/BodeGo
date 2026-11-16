import 'package:flutter/material.dart';
import 'package:bodego/data/models/business_config.dart';
import 'package:bodego/data/repositories/app_settings_repository.dart';
import 'package:bodego/data/repositories/business_config_repository.dart';
import 'package:bodego/data/repositories/user_repository.dart';
import 'package:bodego/presentation/screens/pos/main_pos_screen.dart';
import 'package:bodego/presentation/screens/auth/pin_login_screen.dart';
import 'package:bodego/presentation/widgets/numeric_pad.dart';
import 'package:bodego/presentation/widgets/bodego_logo.dart';
import 'package:bodego/presentation/screens/auth/widgets/tour_illustrations.dart';
import 'package:bodego/presentation/screens/auth/widgets/welcome_presentation_view.dart';
import 'package:bodego/presentation/screens/auth/widgets/legal_terms_modal.dart';

/// Fases del flujo inicial de Onboarding
enum OnboardingPhase {
  welcome, // 1. Presentación Oficial BodeGo + EddamCore + Condiciones Legales
  tour,    // 2. Tour interactivo animado de 4 láminas
  form,    // 3. Formulario de configuración (Negocio -> Admin -> Cajero)
}

/// Carrusel de bienvenida interactivo + configuración inicial (Onboarding) de 3 pasos:
/// - Ventana institucional de bienvenida y condiciones legales
/// - Tour Animado de 4 slides (Ventas, Fiados, Impresora, Cierre Z)
/// 1. Datos del Negocio
/// 2. Administrador (Correo / Contraseña)
/// 3. Cajero (Nombre / PIN)
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final PageController _tourPageController = PageController();
  final AppSettingsRepository _settingsRepository = AppSettingsRepository();
  final UserRepository _userRepository = UserRepository();

  OnboardingPhase _currentPhase = OnboardingPhase.welcome;
  int _currentTourIndex = 0;
  int _currentPage = 0;

  // Controladores Página 1: Negocio
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _businessAddressController = TextEditingController();
  final TextEditingController _businessRucController = TextEditingController();
  String _selectedBusinessPreset = 'storefront';
  String? _businessNameError;

  final BusinessConfigRepository _businessConfigRepository = BusinessConfigRepository();

  // Controladores Página 2: Administrador
  final TextEditingController _adminNameController = TextEditingController();
  final TextEditingController _adminEmailController = TextEditingController();
  final TextEditingController _adminPasswordController = TextEditingController();
  String? _adminError;
  bool _obscurePassword = true;

  // Controladores Página 3: Cajero
  final TextEditingController _cashierNameController = TextEditingController();
  String _cashierPin = '';
  String? _cashierError;
  bool _isSaving = false;

  @override
  void dispose() {
    _pageController.dispose();
    _tourPageController.dispose();
    _businessNameController.dispose();
    _businessAddressController.dispose();
    _businessRucController.dispose();
    _adminNameController.dispose();
    _adminEmailController.dispose();
    _adminPasswordController.dispose();
    _cashierNameController.dispose();
    super.dispose();
  }

  void _nextPage() {
    FocusScope.of(context).unfocus();
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _previousPage() {
    FocusScope.of(context).unfocus();
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // --- Validación Página 1 ---
  void _validateAndGoToAdmin() {
    final businessName = _businessNameController.text.trim();
    if (businessName.isEmpty) {
      setState(() {
        _businessNameError = 'Por favor, ingresa el nombre de tu bodega';
      });
      return;
    }

    setState(() {
      _businessNameError = null;
    });
    _nextPage();
  }

  // --- Validación Página 2 ---
  void _validateAndGoToCashier() {
    final name = _adminNameController.text.trim();
    final email = _adminEmailController.text.trim();
    final password = _adminPasswordController.text;

    if (name.isEmpty) {
      setState(() {
        _adminError = 'Ingresa el nombre del encargado o dueño';
      });
      return;
    }

    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() {
        _adminError = 'Ingresa un correo electrónico válido';
      });
      return;
    }

    if (password.length < 4) {
      setState(() {
        _adminError = 'La contraseña debe tener al menos 4 caracteres';
      });
      return;
    }

    setState(() {
      _adminError = null;
    });
    _nextPage();
  }

  // --- Lógica Teclado PIN Cajero ---
  void _onPinNumberSelected(String number) {
    if (_cashierPin.length < 4) {
      setState(() {
        _cashierError = null;
        _cashierPin += number;
      });
    }
  }

  void _onPinDelete() {
    if (_cashierPin.isNotEmpty) {
      setState(() {
        _cashierError = null;
        _cashierPin = _cashierPin.substring(0, _cashierPin.length - 1);
      });
    }
  }

  // --- Lógica de Finalización ---
  Future<void> _finishOnboarding() async {
    final cashierName = _cashierNameController.text.trim();

    if (cashierName.isEmpty) {
      setState(() {
        _cashierError = 'Ingresa el nombre del cajero';
      });
      return;
    }

    if (_cashierPin.length != 4) {
      setState(() {
        _cashierError = 'El PIN del cajero debe ser de 4 dígitos';
      });
      return;
    }

    if (_isSaving) return;

    setState(() {
      _isSaving = true;
      _cashierError = null;
    });

    try {
      final businessName = _businessNameController.text.trim();
      final adminName = _adminNameController.text.trim();
      final adminEmail = _adminEmailController.text.trim();
      final adminPassword = _adminPasswordController.text;

      // 1. Guardar configuración completa del negocio en business_config.json y marcar isFirstRun = false
      final existingConfig = await _businessConfigRepository.getConfig();
      final updatedConfig = existingConfig.copyWith(
        businessName: businessName,
        address: _businessAddressController.text.trim().isNotEmpty
            ? _businessAddressController.text.trim()
            : existingConfig.address,
        ruc: _businessRucController.text.trim().isNotEmpty
            ? _businessRucController.text.trim()
            : existingConfig.ruc,
        logoValue: _selectedBusinessPreset,
      );
      await _businessConfigRepository.saveConfig(updatedConfig);
      await _settingsRepository.updateBusinessName(businessName);

      // 2. Crear usuario Administrador
      await _userRepository.createAdmin(adminName, adminEmail, adminPassword);

      // 3. Crear usuario Cajero
      await _userRepository.createCashier(cashierName, _cashierPin);

      if (!mounted) return;

      // 4. Navegar a la pantalla principal del POS
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainPosScreen()),
      );
    } catch (e) {
      setState(() {
        _isSaving = false;
        _cashierError = 'Error al finalizar configuración: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: _buildCurrentPhaseWidget(context),
    );
  }

  Widget _buildCurrentPhaseWidget(BuildContext context) {
    switch (_currentPhase) {
      case OnboardingPhase.welcome:
        return WelcomePresentationView(
          key: const ValueKey('welcome_presentation_view'),
          onStartTour: () {
            setState(() {
              _currentPhase = OnboardingPhase.tour;
            });
          },
          onSkipToForm: () {
            setState(() {
              _currentPhase = OnboardingPhase.form;
            });
          },
          onPairedSuccessfully: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const PinLoginScreen()),
            );
          },
        );
      case OnboardingPhase.tour:
        return _buildTourScreen(context);
      case OnboardingPhase.form:
        return _buildSetupFormScreen(context);
    }
  }

  // ==========================================
  // PANTALLA DEL TOUR INTERACTIVO DE BIENVENIDA
  // ==========================================
  Widget _buildTourScreen(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      key: const ValueKey('welcome_tour_screen'),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Barra Superior del Tour: Retroceso a Bienvenida + Logo BodeGo + Botón Omitir
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: 'Volver a la presentación',
                    onPressed: () {
                      setState(() {
                        _currentPhase = OnboardingPhase.welcome;
                      });
                    },
                  ),
                  const BodeGoLogoWidget(
                    size: 28,
                    withBackground: true,
                    borderRadius: 8,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'BodeGo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _currentPhase = OnboardingPhase.form;
                      });
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? Colors.white60 : Colors.grey[700],
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Omitir',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Carrusel de Slides Animados con PageView
            Expanded(
              child: PageView(
                controller: _tourPageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentTourIndex = index;
                  });
                },
                children: [
                  _buildTourSlide(
                    illustration: const SalesTourIllustration(),
                    tag: 'PUNTO DE VENTA RÁPIDO',
                    tagColor: const Color(0xFF4353FF),
                    title: 'Ventas y Catálogo al Instante',
                    description:
                        'Escanea códigos de barras o busca por nombre al instante. Agrega productos al carrito y cobra en segundos.',
                    benefits: const [
                      'Escaneo ágil de código de barras con cámara o pistola USB/BT',
                      'Cálculo automático de vuelto y cobro mixto (Efectivo / Yape / Plin)',
                      'Búsqueda instantánea en catálogo por nombre o categoría',
                    ],
                  ),
                  _buildTourSlide(
                    illustration: const FiadosTourIllustration(),
                    tag: 'CRÉDITO Y CASEROS',
                    tagColor: const Color(0xFFFFA114),
                    title: 'Control de Fiados sin Enredos',
                    description:
                        'Dile adiós al cuaderno arrugado. Registra a tus clientes, establece límites de crédito y anota pagos fácilmente.',
                    benefits: const [
                      'Libreta digital por cliente casero con historial de compras',
                      'Límite de crédito con alerta visual de deuda acumulada',
                      'Registro de abonos parciales y saldo restante al segundo',
                    ],
                  ),
                  _buildTourSlide(
                    illustration: const ThermalPrintTourIllustration(),
                    tag: 'CONECTIVIDAD POS',
                    tagColor: const Color(0xFF00D084),
                    title: 'Tickets Térmicos Bluetooth',
                    description:
                        'Imprime boletas claras en impresoras portátiles de 58mm y 80mm con código de barras y el logo de tu negocio.',
                    benefits: const [
                      'Conexión inalámbrica Bluetooth rápida a impresoras de 58mm y 80mm',
                      'Boletas con logo de tu bodega, RUC y mensaje de despedida',
                      'Código de barras impreso para agilizar cambios o consultas',
                    ],
                  ),
                  _buildTourSlide(
                    illustration: const ZReportTourIllustration(),
                    tag: 'CONTROL DE DINERO',
                    tagColor: const Color(0xFF8B5CF6),
                    title: 'Caja Cuadrada y Cierre Z',
                    description:
                        'Control por turnos de cajero, registro ágil de entradas y salidas de efectivo, y arqueo exacto al terminar el día.',
                    benefits: const [
                      'Apertura con fondo de sencillo y control de turnos por cajero',
                      'Registro ágil de salidas de dinero (proveedores y gastos)',
                      'Reporte Z diario con balance y arqueo cuadrado al centavo',
                    ],
                  ),
                ],
              ),
            ),

            // Indicador de Puntos (Dots) y Botón de Acción Principal
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Puntos de página dinámicos
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final isSelected = _currentTourIndex == index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isSelected ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF4353FF)
                              : (isDark ? Colors.white24 : Colors.grey.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 18),

                  // Botón Siguiente / Empezar Configuración
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentTourIndex < 3) {
                          _tourPageController.nextPage(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          setState(() {
                            _currentPhase = OnboardingPhase.form;
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _currentTourIndex == 3
                            ? const Color(0xFF00D084)
                            : const Color(0xFF4353FF),
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentTourIndex == 3
                                ? 'Empezar Configuración'
                                : 'Siguiente',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _currentTourIndex == 3
                                ? Icons.rocket_launch_rounded
                                : Icons.arrow_forward_rounded,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTourSlide({
    required Widget illustration,
    required String tag,
    required Color tagColor,
    required String title,
    required String description,
    required List<String> benefits,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Ilustración animada con sombra y marco
                illustration,

                // 2. Bloque de Textos (Badge de Categoría + Título + Descripción)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: tagColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: tagColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          description,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.4,
                            color: isDark ? Colors.white60 : Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. Tarjeta de Micro-Beneficios con Checks Verdes (Aprovecha el espacio con alto valor)
                _buildBenefitsCard(
                  benefits: benefits,
                  tagColor: tagColor,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBenefitsCard({
    required List<String> benefits,
    required Color tagColor,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: tagColor.withOpacity(0.18),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: tagColor.withOpacity(isDark ? 0.08 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: benefits.map((benefit) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D084).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 13,
                    color: Color(0xFF00D084),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    benefit,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ==========================================
  // PANTALLA DEL FORMULARIO DE 3 PASOS
  // ==========================================
  Widget _buildSetupFormScreen(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      key: const ValueKey('setup_form_screen'),
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BodeGoLogoWidget(
              size: 26,
              withBackground: true,
              borderRadius: 6,
            ),
            const SizedBox(width: 8),
            Text(
              _getTitleForPage(_currentPage),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        centerTitle: true,
        leading: _currentPage == 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Volver a la presentación',
                onPressed: () {
                  setState(() {
                    _currentPhase = OnboardingPhase.welcome;
                  });
                },
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Paso anterior',
                onPressed: _previousPage,
              ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Tour y Condiciones Legales',
            onPressed: () => _showHelpOptionsModal(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Barra de Progreso Moderna y Animada
            _buildModernStepProgressHeader(context),

            // Contenido de las 3 páginas
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  _buildBusinessPage(context),
                  _buildAdminPage(context),
                  _buildCashierPage(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Barra de progreso superior segmentada y animada con números, iconos y gradientes
  Widget _buildModernStepProgressHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final steps = [
      (label: 'Tu Negocio', icon: Icons.storefront_rounded),
      (label: 'Administrador', icon: Icons.shield_rounded),
      (label: 'Cajero PIN', icon: Icons.badge_rounded),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.withOpacity(0.18),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Fila de Pasos con Números/Checks e Iconos
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(steps.length, (index) {
              final isCompleted = _currentPage > index;
              final isCurrent = _currentPage == index;

              Color stepColor;
              if (isCompleted) {
                stepColor = const Color(0xFF00D084);
              } else if (isCurrent) {
                stepColor = const Color(0xFF4353FF);
              } else {
                stepColor = isDark ? Colors.white38 : Colors.grey[500]!;
              }

              return Expanded(
                child: InkWell(
                  onTap: isCompleted
                      ? () {
                          FocusScope.of(context).unfocus();
                          _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCompleted
                                ? const Color(0xFF00D084)
                                : (isCurrent
                                    ? const Color(0xFF4353FF)
                                    : (isDark ? Colors.white12 : Colors.grey[200])),
                            boxShadow: isCurrent
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF4353FF).withOpacity(0.4),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: isCompleted
                                ? const Icon(Icons.check_rounded,
                                    size: 15, color: Colors.white)
                                : Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isCurrent
                                          ? Colors.white
                                          : (isDark ? Colors.white54 : Colors.grey[600]),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            steps[index].label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                              color: stepColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 10),

          // Segmentos de Progreso con Gradiente
          Row(
            children: List.generate(steps.length, (index) {
              final isCompleted = _currentPage > index;
              final isCurrent = _currentPage == index;

              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                    left: index == 0 ? 0 : 4,
                    right: index == steps.length - 1 ? 0 : 4,
                  ),
                  height: 5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: isDark ? Colors.white12 : Colors.grey[200],
                  ),
                  child: AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeInOut,
                    alignment: Alignment.centerLeft,
                    widthFactor: isCompleted ? 1.0 : (isCurrent ? 1.0 : 0.0),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        gradient: isCompleted
                            ? const LinearGradient(
                                colors: [Color(0xFF00D084), Color(0xFF00E676)],
                              )
                            : const LinearGradient(
                                colors: [Color(0xFF4353FF), Color(0xFF707EFF)],
                              ),
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF4353FF).withOpacity(0.5),
                                  blurRadius: 6,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  String _getTitleForPage(int page) {
    switch (page) {
      case 0:
        return 'Paso 1: Tu Negocio';
      case 1:
        return 'Paso 2: Administrador';
      case 2:
        return 'Paso 3: Cajero PIN';
      default:
        return 'Configuración';
    }
  }

  // ==========================================
  // PÁGINA 1: DATOS DEL NEGOCIO (OPTIMIZADA)
  // ==========================================
  Widget _buildBusinessPage(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final presets = [
      (key: 'storefront', label: 'Bodega Clásica', icon: Icons.storefront_rounded),
      (key: 'shopping_cart', label: 'Minimarket', icon: Icons.shopping_cart_rounded),
      (key: 'local_grocery', label: 'Abarrotes', icon: Icons.local_grocery_store_rounded),
      (key: 'shopping_bag', label: 'Tienda / Bazar', icon: Icons.shopping_bag_rounded),
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Cabecera con Icono y Texto
          Center(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4353FF).withOpacity(0.12),
                border: Border.all(
                  color: const Color(0xFF4353FF).withOpacity(0.25),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                size: 38,
                color: Color(0xFF4353FF),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '¡Identidad de tu Bodega!',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Personaliza el nombre y rubro que saldrán en tus boletas e inventario.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 18),

          // 2. Selector Rápido de Rubro / Tipo de Comercio
          Text(
            'Giro de tu Negocio:',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presets.map((p) {
              final isSelected = _selectedBusinessPreset == p.key;
              return ChoiceChip(
                selected: isSelected,
                avatar: Icon(
                  p.icon,
                  size: 16,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : const Color(0xFF4353FF)),
                ),
                label: Text(p.label),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
                selectedColor: const Color(0xFF4353FF),
                backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFF4353FF)
                        : (isDark ? Colors.white12 : Colors.grey.withOpacity(0.25)),
                  ),
                ),
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _selectedBusinessPreset = p.key;
                    });
                  }
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // 3. Campo Obligatorio: Nombre de la Bodega
          TextField(
            controller: _businessNameController,
            textCapitalization: TextCapitalization.words,
            autofocus: false,
            decoration: InputDecoration(
              labelText: 'Nombre de la Bodega *',
              hintText: 'Ej. Bodega San José',
              errorText: _businessNameError,
              prefixIcon: const Icon(Icons.store_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : theme.colorScheme.surface,
            ),
            onSubmitted: (_) => _validateAndGoToAdmin(),
          ),

          const SizedBox(height: 12),

          // 4. Campo Opcional: Dirección o Distrito
          TextField(
            controller: _businessAddressController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Dirección o Distrito (Opcional)',
              hintText: 'Ej. Av. Los Pinos 450, SMP',
              prefixIcon: const Icon(Icons.location_on_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : theme.colorScheme.surface,
            ),
          ),

          const SizedBox(height: 12),

          // 5. Campo Opcional: RUC o DNI
          TextField(
            controller: _businessRucController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'RUC o DNI del Titular (Opcional)',
              hintText: 'Ej. 10458921341',
              prefixIcon: const Icon(Icons.badge_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : theme.colorScheme.surface,
            ),
          ),

          const SizedBox(height: 16),

          // 6. Tarjeta Informativa de Seguridad & Offline
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF00D084).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF00D084).withOpacity(0.2),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 20,
                  color: Color(0xFF00D084),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tus datos y ventas se guardan localmente en tu equipo. 100% privado y sin requerir internet.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // 7. Botón Principal de Continuar
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _validateAndGoToAdmin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4353FF),
                foregroundColor: Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Siguiente: Administrador',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ==========================================
  // PÁGINA 2: DATOS DEL ADMINISTRADOR (OPTIMIZADA)
  // ==========================================
  Widget _buildAdminPage(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Icono y Título
          Center(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4353FF).withOpacity(0.12),
                border: Border.all(
                  color: const Color(0xFF4353FF).withOpacity(0.25),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.shield_rounded,
                size: 38,
                color: Color(0xFF4353FF),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Cuenta de Administrador',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'El dueño o encargado tendrá acceso total al negocio y sus ganancias.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20),

          // 2. Formulario Administrador
          TextField(
            controller: _adminNameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Nombre del Dueño o Encargado *',
              hintText: 'Ej. Juan Mascherano',
              prefixIcon: const Icon(Icons.person_outline_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : theme.colorScheme.surface,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _adminEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Correo Electrónico *',
              hintText: 'admin@bodega.com',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : theme.colorScheme.surface,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _adminPasswordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Contraseña de Acceso *',
              hintText: 'Mínimo 4 caracteres',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : theme.colorScheme.surface,
            ),
          ),

          if (_adminError != null) ...[
            const SizedBox(height: 10),
            Text(
              _adminError!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 16),

          // 3. Tarjeta de Privilegios Exclusivos
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF4353FF).withOpacity(0.18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.workspace_premium_rounded,
                        size: 16, color: Color(0xFF4353FF)),
                    SizedBox(width: 8),
                    Text(
                      'Privilegios del Administrador:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4353FF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildBulletPoint('Visualizar reportes de ganancias y márgenes de utilidad', isDark),
                _buildBulletPoint('Gestionar inventario, precios y catálogo de productos', isDark),
                _buildBulletPoint('Controlar arqueos de caja y configurar impresoras Bluetooth', isDark),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // 4. Botón Siguiente
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _validateAndGoToCashier,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4353FF),
                foregroundColor: Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Siguiente: Configurar Cajero',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ==========================================
  // PÁGINA 3: DATOS DEL CAJERO (OPTIMIZADA)
  // ==========================================
  Widget _buildCashierPage(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Icono y Título
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF00D084).withOpacity(0.12),
              border: Border.all(
                color: const Color(0xFF00D084).withOpacity(0.25),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.badge_rounded,
              size: 34,
              color: Color(0xFF00D084),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Perfil de Cajero (Turno)',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            'Iniciará turno ágilmente ingresando solo su PIN de 4 dígitos.',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? Colors.white60 : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 14),

          // 2. Nombre del Cajero
          TextField(
            controller: _cashierNameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Nombre del Cajero *',
              hintText: 'Ej. Cajero 1 / Carlos',
              prefixIcon: const Icon(Icons.badge_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : theme.colorScheme.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            'Asigna un PIN de 4 dígitos:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // 3. Indicadores visuales de los 4 dígitos del PIN
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final bool isFilled = index < _cashierPin.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled ? const Color(0xFF00D084) : Colors.transparent,
                  border: Border.all(
                    color: isFilled
                        ? const Color(0xFF00D084)
                        : (isDark ? Colors.white30 : const Color(0xFF4353FF).withOpacity(0.4)),
                    width: 2,
                  ),
                  boxShadow: isFilled
                      ? [
                          BoxShadow(
                            color: const Color(0xFF00D084).withOpacity(0.5),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              );
            }),
          ),

          if (_cashierError != null) ...[
            const SizedBox(height: 8),
            Text(
              _cashierError!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12.5),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 12),

          // 4. Teclado Numérico
          NumericPad(
            onNumberSelected: _onPinNumberSelected,
            onDelete: _onPinDelete,
          ),

          const SizedBox(height: 14),

          // 5. Botón de Finalización
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _finishOnboarding,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D084),
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: const Color(0xFF00D084).withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.rocket_launch_rounded, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Finalizar y Entrar a Vender',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF00D084)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // MODAL DE AYUDA Y ACCESO A RECURSOS
  // ==========================================
  void _showHelpOptionsModal(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.help_outline_rounded,
                        color: Color(0xFF4353FF), size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Recursos y Asistencia BodeGo',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4353FF).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.slideshow_rounded,
                        color: Color(0xFF4353FF), size: 20),
                  ),
                  title: const Text('Ver Tour de Funcionalidades',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text(
                      'Animaciones de ventas, fiados, tickets y caja',
                      style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _currentPhase = OnboardingPhase.tour;
                    });
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D084).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.storefront_rounded,
                        color: Color(0xFF00D084), size: 20),
                  ),
                  title: const Text('Presentación Institucional',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text(
                      '¿Qué es BodeGo? y tecnología de EddamCore',
                      style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _currentPhase = OnboardingPhase.welcome;
                    });
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFA114).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.gavel_rounded,
                        color: Color(0xFFFFA114), size: 20),
                  ),
                  title: const Text('Términos y Privacidad',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text(
                      'Políticas offline, seguridad local y licencia',
                      style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(ctx);
                    LegalTermsModal.show(context);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}
