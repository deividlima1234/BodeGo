import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bodego/data/models/business_config.dart';
import 'package:bodego/data/repositories/app_settings_repository.dart';
import 'package:bodego/data/repositories/business_config_repository.dart';
import 'package:bodego/data/repositories/user_repository.dart';
import 'package:bodego/presentation/screens/clients/clients_screen.dart';
import 'package:bodego/presentation/screens/inventory/inventory_screen.dart';
import 'package:bodego/presentation/screens/pos/pos_module_screen.dart';
import 'package:bodego/presentation/screens/reports/reports_screen.dart';
import 'package:bodego/presentation/screens/settings/settings_screen.dart';
import 'package:bodego/presentation/widgets/bodego_sidebar.dart';

/// Dashboard Principal de BodeGo responsive con gestión inteligente del botón "Atrás":
/// Permite retroceder secuencialmente por las secciones hasta llegar a la Caja,
/// y protege contra salidas accidentales mediante confirmación de doble toque en la Caja.
class MainPosScreen extends StatefulWidget {
  const MainPosScreen({super.key});

  @override
  State<MainPosScreen> createState() => _MainPosScreenState();
}

class _MainPosScreenState extends State<MainPosScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final AppSettingsRepository _settingsRepository = AppSettingsRepository();
  final UserRepository _userRepository = UserRepository();

  int _currentIndex = 0;
  bool _isSidebarExpanded = true;
  String _businessName = 'BodeGo';
  String _userName = 'Cajero';

  /// Pila de historial de secciones visitadas (inicia en 0: Caja)
  final List<int> _navigationHistory = [0];

  /// Marca de tiempo del último toque del botón Atrás en la sección Caja
  DateTime? _lastBackPressTime;

  final List<Widget> _screens = const [
    PosModuleScreen(),
    InventoryScreen(),
    ClientsScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  final List<String> _moduleTitles = const [
    'Punto de Venta',
    'Inventario',
    'Clientes',
    'Reportes',
    'Configuración',
  ];

  @override
  void initState() {
    super.initState();
    _loadSessionData();
    BusinessConfigRepository().configNotifier.addListener(_onConfigChanged);
  }

  @override
  void dispose() {
    BusinessConfigRepository().configNotifier.removeListener(_onConfigChanged);
    super.dispose();
  }

  void _onConfigChanged() {
    final config = BusinessConfigRepository().configNotifier.value;
    if (config != null && mounted) {
      setState(() {
        _businessName = config.businessName;
      });
    }
  }

  Future<void> _loadSessionData() async {
    final businessConfig = await BusinessConfigRepository().getConfig();
    final cashier = await _userRepository.getFirstCashier();

    if (mounted) {
      setState(() {
        _businessName = businessConfig.businessName.isNotEmpty
            ? businessConfig.businessName
            : 'Mi Bodega';
        _userName = cashier?.name ?? 'Cajero de Turno';
      });
    }
  }

  /// Cambia de sección registrando la navegación en la pila de historial
  void _onSectionSelected(int index) {
    if (_currentIndex == index) return;

    setState(() {
      _currentIndex = index;
      if (index == 0) {
        // Al regresar a Caja, reiniciamos la pila a la base principal
        _navigationHistory.clear();
        _navigationHistory.add(0);
      } else {
        // Evitamos duplicar el mismo índice de manera consecutiva
        if (_navigationHistory.isEmpty || _navigationHistory.last != index) {
          _navigationHistory.add(index);
        }
      }
    });
  }

  /// Control del botón de navegación "Atrás" del sistema móvil
  void _handleBackNavigation(bool didPop) {
    if (didPop) return;

    // 1. Si el Drawer lateral está abierto en móvil, cerrarlo primero
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      _scaffoldKey.currentState?.closeDrawer();
      return;
    }

    // 2. Si estamos en una sección secundaria (no Caja), retroceder por el historial
    if (_currentIndex != 0) {
      setState(() {
        if (_navigationHistory.length > 1) {
          _navigationHistory.removeLast(); // Quitamos la sección actual
          _currentIndex = _navigationHistory.isNotEmpty ? _navigationHistory.last : 0;
        } else {
          // Salvaguarda: Forzamos el regreso a la sección principal "Caja"
          _currentIndex = 0;
          _navigationHistory.clear();
          _navigationHistory.add(0);
        }
      });
      return;
    }

    // 3. Si ya estamos en la sección principal "Caja" (índice 0):
    // Prevenimos cierres accidentales con un SnackBar sutil de confirmación
    final now = DateTime.now();
    if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Presiona atrás una vez más para salir de BodeGo',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E222D),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      );
    } else {
      // Segundo toque consecutivo dentro de los 2 segundos -> Salir de la app de forma segura
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 700;

    final Widget scaffoldContent = isMobile
        ? Scaffold(
            key: _scaffoldKey,
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.menu_rounded),
                tooltip: 'Abrir Menú',
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _businessName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _moduleTitles[_currentIndex],
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                          child: Icon(
                            Icons.person_rounded,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 80),
                          child: Text(
                            _userName,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            drawer: Drawer(
              child: BodeGoSidebar(
                selectedIndex: _currentIndex,
                isExpanded: true,
                isDrawer: true,
                businessName: _businessName,
                userName: _userName,
                onToggleSidebar: () => Navigator.pop(context),
                onItemSelected: (index) {
                  _onSectionSelected(index);
                  Navigator.pop(context);
                },
              ),
            ),
            body: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          )
        : Scaffold(
            body: Row(
              children: [
                BodeGoSidebar(
                  selectedIndex: _currentIndex,
                  onItemSelected: (index) => _onSectionSelected(index),
                  isExpanded: _isSidebarExpanded,
                  onToggleSidebar: () {
                    setState(() {
                      _isSidebarExpanded = !_isSidebarExpanded;
                    });
                  },
                  businessName: _businessName,
                  userName: _userName,
                ),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: _screens,
                  ),
                ),
              ],
            ),
          );

    // Envolvemos en PopScope para interceptar el botón Atrás del sistema móvil
    return PopScope(
      canPop: false,
      onPopInvoked: _handleBackNavigation,
      child: scaffoldContent,
    );
  }
}
