import 'package:flutter/material.dart';
import 'package:bodego/data/repositories/app_settings_repository.dart';
import 'package:bodego/data/repositories/user_repository.dart';
import 'package:bodego/presentation/screens/pos/main_pos_screen.dart';
import 'package:bodego/presentation/widgets/numeric_pad.dart';

/// Carrusel de configuración inicial (Onboarding) de 3 pasos:
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
  final AppSettingsRepository _settingsRepository = AppSettingsRepository();
  final UserRepository _userRepository = UserRepository();

  int _currentPage = 0;

  // Controladores Página 1: Negocio
  final TextEditingController _businessNameController = TextEditingController();
  String? _businessNameError;

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
    _businessNameController.dispose();
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

      // 1. Guardar nombre del negocio y marcar isFirstRun = false
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_getTitleForPage(_currentPage)),
        centerTitle: true,
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(
            value: (_currentPage + 1) / 3,
            backgroundColor: theme.colorScheme.surface,
            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            minHeight: 4,
          ),
        ),
      ),
      body: SafeArea(
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
    );
  }

  String _getTitleForPage(int page) {
    switch (page) {
      case 0:
        return 'Paso 1: Tu Negocio';
      case 1:
        return 'Paso 2: Administrador';
      case 2:
        return 'Paso 3: Cajero de Turno';
      default:
        return 'Configuración';
    }
  }

  // ==========================================
  // PÁGINA 1: DATOS DEL NEGOCIO
  // ==========================================
  Widget _buildBusinessPage(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Icon(
            Icons.storefront_rounded,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            '¡Bienvenido a BodeGo!',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Configura la identidad de tu bodega o minimarket para empezar a vender.',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),
          TextField(
            controller: _businessNameController,
            textCapitalization: TextCapitalization.words,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Nombre de la Bodega',
              hintText: 'Ej. Bodega San José',
              errorText: _businessNameError,
              prefixIcon: const Icon(Icons.store_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: theme.colorScheme.surface,
            ),
            onSubmitted: (_) => _validateAndGoToAdmin(),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _validateAndGoToAdmin,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Siguiente',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PÁGINA 2: DATOS DEL ADMINISTRADOR
  // ==========================================
  Widget _buildAdminPage(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _previousPage,
                tooltip: 'Regresar',
              ),
              const Expanded(
                child: Text(
                  'Cuenta de Administrador',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tendrá acceso total a inventario, ganancias, reportes y configuración.',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _adminNameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Nombre del Encargado',
              hintText: 'Ej. Juan Pérez',
              prefixIcon: const Icon(Icons.person_outline_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: theme.colorScheme.surface,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _adminEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Correo Electrónico',
              hintText: 'admin@bodega.com',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: theme.colorScheme.surface,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _adminPasswordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Contraseña de Acceso',
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
              fillColor: theme.colorScheme.surface,
            ),
          ),
          if (_adminError != null) ...[
            const SizedBox(height: 12),
            Text(
              _adminError!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _validateAndGoToCashier,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
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
        ],
      ),
    );
  }

  // ==========================================
  // PÁGINA 3: DATOS DEL CAJERO (PIN)
  // ==========================================
  Widget _buildCashierPage(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _previousPage,
                tooltip: 'Regresar',
              ),
              const Expanded(
                child: Text(
                  'Perfil de Caja (Turno)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'El cajero iniciará sesión de forma ágil ingresando solo su PIN.',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _cashierNameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Nombre del Cajero',
              hintText: 'Ej. Cajero 1 / Carlos',
              prefixIcon: const Icon(Icons.badge_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: theme.colorScheme.surface,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Asigna un PIN de 4 dígitos:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          // Indicadores de los 4 círculos del PIN
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final bool isFilled = index < _cashierPin.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled ? theme.colorScheme.primary : Colors.transparent,
                  border: Border.all(
                    color: isFilled
                        ? theme.colorScheme.primary
                        : theme.colorScheme.primary.withOpacity(0.4),
                    width: 2,
                  ),
                ),
              );
            }),
          ),
          if (_cashierError != null) ...[
            const SizedBox(height: 10),
            Text(
              _cashierError!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 16),
          // Teclado numérico táctil
          NumericPad(
            onNumberSelected: _onPinNumberSelected,
            onDelete: _onPinDelete,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _finishOnboarding,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded),
                        SizedBox(width: 8),
                        Text(
                          'Finalizar y Entrar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
