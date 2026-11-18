import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bodego/data/local/isar/collections/category.dart';
import 'package:bodego/data/local/isar/collections/product.dart';
import 'package:bodego/data/local/isar/collections/customer.dart';
import 'package:bodego/data/models/cart_item.dart';
import 'package:bodego/data/models/sale_ticket.dart';
import 'package:bodego/data/repositories/category_repository.dart';
import 'package:bodego/data/repositories/inventory_repository.dart';
import 'package:bodego/data/repositories/customer_repository.dart';
import 'package:bodego/data/repositories/ticket_repository.dart';
import 'package:bodego/data/repositories/app_settings_repository.dart';
import 'package:bodego/data/repositories/business_config_repository.dart';
import 'package:bodego/data/repositories/printer_repository.dart';
import 'package:bodego/data/repositories/user_repository.dart';
import 'package:bodego/presentation/screens/pos/sales_history_screen.dart';
import 'package:bodego/presentation/screens/pos/widgets/customer_picker_modal.dart';
import 'package:bodego/presentation/screens/pos/widgets/ticket_preview_modal.dart';
import 'package:bodego/presentation/screens/pos/widgets/pos_product_card.dart';
import 'package:bodego/presentation/screens/pos/widgets/discount_dialog.dart';
import 'package:bodego/presentation/widgets/modern_barcode_scanner.dart';
import 'package:bodego/core/services/sound_service.dart';
import 'package:bodego/core/services/device_pairing_service.dart';

/// Módulo de Caja (Punto de Venta) con catálogo reactivo en tiempo real,
/// filtros por categoría, carrito flotante, emisión de tickets y gestión de fiados.
class PosModuleScreen extends StatefulWidget {
  const PosModuleScreen({super.key});

  @override
  State<PosModuleScreen> createState() => _PosModuleScreenState();
}

class _PosModuleScreenState extends State<PosModuleScreen> {
  final InventoryRepository _inventoryRepository = InventoryRepository();
  final CustomerRepository _customerRepository = CustomerRepository();
  final TicketRepository _ticketRepository = TicketRepository();
  final AppSettingsRepository _settingsRepository = AppSettingsRepository();
  final UserRepository _userRepository = UserRepository();

  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  List<Category> _categories = [];
  int? _selectedCategoryId; // null = Todas las categorías
  final List<CartItem> _cart = [];
  double _discount = 0.0;
  final TextEditingController _searchController = TextEditingController();

  StreamSubscription<void>? _productsSubscription;
  StreamSubscription<void>? _categoriesSubscription;

  /// Cliente seleccionado para la venta actual (`null` representa Público General / Al Contado).
  Customer? _selectedCustomer;

  String _businessName = 'BodeGo';
  String _cashierName = 'Cajero de Turno';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _loadSessionData();
    _initRealtimeSubscriptions();
  }

  @override
  void dispose() {
    _productsSubscription?.cancel();
    _categoriesSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Inicializa las suscripciones reactivas en tiempo real a la base de datos Isar.
  void _initRealtimeSubscriptions() {
    _productsSubscription = _inventoryRepository.watchProducts().listen((_) {
      _reloadProductsSilently();
    });

    _categoriesSubscription = _inventoryRepository.watchCategories().listen((_) {
      _reloadCategoriesSilently();
    });
  }

  Future<void> _loadSessionData() async {
    final businessConfig = await BusinessConfigRepository().getConfig();
    final cashier = await _userRepository.getFirstCashier();
    if (mounted) {
      setState(() {
        _businessName = businessConfig.businessName.isNotEmpty
            ? businessConfig.businessName
            : 'BodeGo';
        _cashierName = cashier?.name ?? 'Cajero de Turno';
      });
    }
  }

  /// Carga inicial de productos y categorías con feedback de carga.
  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchProducts(),
      _fetchCategories(),
    ]);

    if (mounted) {
      setState(() {
        _applyFilters();
        _isLoading = false;
      });
    }
  }

  /// Obtiene los productos cargando sus relaciones de categoría.
  Future<void> _fetchProducts() async {
    final products = await _inventoryRepository.getProducts();
    _allProducts = products;
  }

  /// Obtiene las categorías de la base de datos (poblando iniciales si está vacía).
  Future<void> _fetchCategories() async {
    var categories = await _inventoryRepository.getCategories();
    if (categories.isEmpty) {
      await CategoryRepository().seedInitialCategories();
      categories = await _inventoryRepository.getCategories();
    }
    _categories = categories;
  }

  /// Actualización silenciosa de productos tras cambios en Isar DB (sin parpadeo en UI).
  Future<void> _reloadProductsSilently() async {
    await _fetchProducts();
    if (mounted) {
      setState(() {
        _syncCartWithUpdatedProducts();
        _applyFilters();
      });
    }
  }

  /// Actualización silenciosa de categorías tras cambios en Isar DB.
  Future<void> _reloadCategoriesSilently() async {
    await _fetchCategories();
    if (mounted) {
      if (_selectedCategoryId != null &&
          !_categories.any((c) => c.id == _selectedCategoryId)) {
        _selectedCategoryId = null;
      }
      setState(() {
        _applyFilters();
      });
    }
  }

  /// Mantiene la integridad del carrito si un producto cambió de existencias o fue eliminado.
  void _syncCartWithUpdatedProducts() {
    for (int i = _cart.length - 1; i >= 0; i--) {
      final cartItem = _cart[i];
      final matchingProduct = _allProducts
          .where((p) => p.id == cartItem.product.id)
          .firstOrNull;

      if (matchingProduct == null) {
        _cart.removeAt(i);
      } else {
        cartItem.product = matchingProduct;
        if (matchingProduct.stock <= 0) {
          _cart.removeAt(i);
        } else if (cartItem.quantity > matchingProduct.stock) {
          cartItem.quantity = matchingProduct.stock;
        }
      }
    }
  }

  /// Aplica los filtros combinados de búsqueda textual y categoría activa.
  void _applyFilters() {
    final cleanQuery = _searchController.text.trim().toLowerCase();

    _filteredProducts = _allProducts.where((product) {
      // 1. Filtro por categoría seleccionada
      if (_selectedCategoryId != null) {
        if (product.category.value?.id != _selectedCategoryId) {
          return false;
        }
      }

      // 2. Filtro por coincidencia de texto (nombre o código de barras)
      if (cleanQuery.isNotEmpty) {
        final matchesName = product.name.toLowerCase().contains(cleanQuery);
        final matchesBarcode =
            product.barcode?.toLowerCase().contains(cleanQuery) ?? false;
        if (!matchesName && !matchesBarcode) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// Evento al escribir en la barra de búsqueda.
  void _onSearchChanged(String query) {
    setState(() {
      _applyFilters();
    });
  }

  /// Evento al seleccionar un filtro de categoría.
  void _onCategorySelected(int? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
      _applyFilters();
    });
  }

  /// Abre el escáner moderno e inteligente en modo continuo para la Caja.
  Future<void> _openPOSScanner() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (scannerCtx) {
          return StatefulBuilder(
            builder: (ctx, setScannerState) {
              final theme = Theme.of(context);
              final colorScheme = theme.colorScheme;
              final cartCount = _cart.length;
              final cartTotal = _cartTotal;

              return ModernBarcodeScanner(
                isContinuousMode: true,
                title: 'Caja - Escáner Continuo',
                subtitle: 'Apunta a los productos para agregarlos al carrito',
                onBarcodeScanned: (scannedCode) async {
                  return await _processScannedBarcodeInPOS(
                    scannedCode,
                    onCartUpdated: () {
                      setScannerState(() {});
                      if (mounted) setState(() {});
                    },
                  );
                },
                bottomBar: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$cartCount ${cartCount == 1 ? 'producto' : 'productos'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                          Text(
                            'S/ ${cartTotal.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 18),
                        label: const Text(
                          'Ver Carrito',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          Navigator.pop(scannerCtx);
                          if (_cart.isNotEmpty) {
                            _showCartBottomSheet(context);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Procesa un código de barras detectado (vía cámara o pistola física).
  Future<String?> _processScannedBarcodeInPOS(
    String barcode, {
    VoidCallback? onCartUpdated,
  }) async {
    final cleanCode = barcode.trim();
    if (cleanCode.isEmpty) return null;

    // Buscar en la lista en memoria o en la base de datos Isar
    Product? product;
    try {
      product = _allProducts.firstWhere(
        (p) => p.barcode != null && p.barcode!.trim() == cleanCode,
      );
    } catch (_) {
      product = await _inventoryRepository.getProductByBarcode(cleanCode);
    }

    if (product == null) {
      SoundService.playErrorBeep();
      return 'Código "$cleanCode" no encontrado en catálogo';
    }

    if (product.stock <= 0) {
      SoundService.playErrorBeep();
      return 'Sin existencias de "${product.name}"';
    }

    // Si es producto a granel (kg, m, L, etc.), abrir modal de pesaje/importe
    if (product.allowsDecimals) {
      if (mounted) {
        await _showBulkMeasurementModal(product);
        onCartUpdated?.call();
        return 'Pesaje completado: ${product.name}';
      }
      return null;
    }

    // Si es unitario, agregar +1 al carrito
    _addToCart(product, quantity: 1.0);
    onCartUpdated?.call();
    return '✓ ${product.name} (+1)';
  }

  /// Soporte para lectores de barras físicos USB/Bluetooth conectados a la Caja.
  Future<void> _handleHardwareBarcodeScan(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    final result = await _processScannedBarcodeInPOS(clean);
    if (mounted && result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    _searchController.clear();
    _onSearchChanged('');
  }

  /// Agrega o actualiza la cantidad de un producto en el carrito de compras.
  void _addToCart(Product product, {double quantity = 1.0, bool replaceQuantity = false}) {
    if (product.stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sin existencias disponibles de "${product.name}"'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }

    setState(() {
      final index = _cart.indexWhere((item) => item.product.id == product.id);
      if (index >= 0) {
        final newQuantity = replaceQuantity ? quantity : _cart[index].quantity + quantity;
        if (newQuantity <= product.stock) {
          _cart[index].quantity = newQuantity;
        } else {
          _cart[index].quantity = product.stock;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Stock máximo alcanzado (${_formatStock(product.stock, product.unit)})'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else {
        final initialQty = quantity <= product.stock ? quantity : product.stock;
        _cart.add(CartItem(product: product, quantity: initialQty));
      }
    });
  }

  /// Gestiona la selección de un producto en el catálogo:
  /// Si es pesable/medible (kg, m, L) abre el modal de pesaje; si es unitario suma +1.
  void _onProductCardTapped(Product product) {
    if (product.allowsDecimals) {
      _showBulkMeasurementModal(product);
    } else {
      _addToCart(product, quantity: 1.0);
    }
  }

  /// Getter que calcula el subtotal bruto acumulado de todos los ítems en el carrito.
  double get _cartSubtotal => _cart.fold(0.0, (sum, item) => sum + item.subtotal);

  /// Getter que calcula el total neto a cobrar aplicando el descuento activo.
  double get _cartTotal {
    final sub = _cartSubtotal;
    final disc = _discount > sub ? sub : _discount;
    return (sub - disc).clamp(0.0, double.infinity);
  }

  // ==========================================
  // OPERACIONES DE COBRO (CONTADO VS FIADO) Y EMISIÓN DE TICKET
  // ==========================================

  /// Procesa la venta al Contado (Público General):
  /// Descuenta stock en Isar, persiste el ticket y abre el modal del ticket con bordes dentados.
  Future<void> _processCashCheckout(BuildContext modalContext) async {
    if (_cart.isEmpty) return;

    Navigator.pop(modalContext);

    final subtotal = _cartSubtotal;
    final discount = _discount > subtotal ? subtotal : _discount;
    final total = _cartTotal;

    // 1. Descontar existencias en Isar
    for (final item in _cart) {
      await _inventoryRepository.updateStock(item.product.id, item.quantity);
    }

    // 2. Mapear ítems del carrito al modelo de ticket
    final ticketItems = _cart
        .map((item) => SaleTicketItem(
              productId: item.product.id,
              name: item.product.name,
              quantity: item.quantity,
              unitPrice: item.product.salePrice,
              subtotal: item.subtotal,
              unit: item.product.unit,
            ))
        .toList();

    // 3. Crear y persistir el ticket en el historial local
    final isSec = await DevicePairingService().isSecondaryDevice();
    final ticket = await _ticketRepository.createTicket(
      subtotal: subtotal,
      discount: discount,
      total: total,
      isCredit: false,
      cashierName: _cashierName,
      businessName: _businessName,
      items: ticketItems,
      isSynced: !isSec,
    );

    setState(() {
      _cart.clear();
      _discount = 0.0;
      _selectedCustomer = null;
    });
    _reloadProductsSilently();

    // Impresión automática en ticketera si está vinculada y activa
    final printerConfig = await PrinterRepository().getConfig();
    if (printerConfig.isReadyToPrint && printerConfig.autoPrintOnSale) {
      PrinterRepository().printSaleTicket(ticket, config: printerConfig);
    }

    if (!mounted) return;

    // 4. Mostrar el ticket digital con formato térmico y bordes dentados
    await TicketPreviewModal.show(context, ticket);
  }

  /// Procesa la venta al Fiado (Asignada a un Cliente):
  /// Valida crédito, descuenta stock, incrementa deuda en Isar, persiste ticket y abre comprobante.
  Future<void> _processCreditCheckout(BuildContext modalContext) async {
    if (_cart.isEmpty || _selectedCustomer == null) return;

    final customer = _selectedCustomer!;
    final total = _cartTotal;
    final availableCredit = (customer.creditLimit - customer.currentDebt).clamp(0.0, double.infinity);

    // Advertencia si sobrepasa el límite de crédito
    if (total > availableCredit) {
      final bool? proceed = await showDialog<bool>(
        context: modalContext,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 26),
              SizedBox(width: 8),
              Text('Límite de Crédito Superado'),
            ],
          ),
          content: Text(
            '${customer.name} tiene un límite de crédito de S/ ${customer.creditLimit.toStringAsFixed(2)} '
            'y actualmente debe S/ ${customer.currentDebt.toStringAsFixed(2)}.\n\n'
            'Esta compra aumentará su deuda a S/ ${(customer.currentDebt + total).toStringAsFixed(2)} '
            '(excediendo el límite por S/ ${(total - availableCredit).toStringAsFixed(2)}).\n\n'
            '¿Deseas autorizar esta venta al fiado de todas formas?',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Autorizar Fiado'),
            ),
          ],
        ),
      );

      if (proceed != true) return;
    }

    Navigator.pop(modalContext);

    final subtotal = _cartSubtotal;
    final discount = _discount > subtotal ? subtotal : _discount;

    // 1. Descontar existencias en Isar
    for (final item in _cart) {
      await _inventoryRepository.updateStock(item.product.id, item.quantity);
    }

    // 2. Registrar la deuda en la cuenta corriente del cliente
    final double previousDebt = customer.currentDebt;
    final double newDebt = previousDebt + total;
    await _customerRepository.addDebt(customer.id, total);

    // 3. Mapear ítems del carrito al modelo de ticket
    final ticketItems = _cart
        .map((item) => SaleTicketItem(
              productId: item.product.id,
              name: item.product.name,
              quantity: item.quantity,
              unitPrice: item.product.salePrice,
              subtotal: item.subtotal,
              unit: item.product.unit,
            ))
        .toList();

    // 4. Crear y persistir el ticket de fiado en el historial
    final isSec = await DevicePairingService().isSecondaryDevice();
    final ticket = await _ticketRepository.createTicket(
      subtotal: subtotal,
      discount: discount,
      total: total,
      isCredit: true,
      customerId: customer.id,
      customerName: customer.name,
      previousDebt: previousDebt,
      newDebt: newDebt,
      cashierName: _cashierName,
      businessName: _businessName,
      items: ticketItems,
      isSynced: !isSec,
    );

    setState(() {
      _cart.clear();
      _discount = 0.0;
      _selectedCustomer = null;
    });
    _reloadProductsSilently();

    // Impresión automática en ticketera si está vinculada y activa
    final printerConfig = await PrinterRepository().getConfig();
    if (printerConfig.isReadyToPrint && printerConfig.autoPrintOnSale) {
      PrinterRepository().printSaleTicket(ticket, config: printerConfig);
    }

    if (!mounted) return;

    // 5. Mostrar el ticket digital con formato térmico y bordes dentados
    await TicketPreviewModal.show(context, ticket);
  }

  // ==========================================
  // BOTÓN FLOTANTE DEL CARRITO (PÍLDORA)
  // ==========================================
  Widget _buildFloatingCartButton(BuildContext context) {
    if (_cart.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final bool isCredit = _selectedCustomer != null;
    final primaryColor = isCredit ? Colors.orange[800]! : theme.colorScheme.primary;

    return FloatingActionButton.extended(
      onPressed: () => _showCartBottomSheet(context),
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 4,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            isCredit ? Icons.handshake_rounded : Icons.shopping_cart_rounded,
            size: 22,
          ),
          Positioned(
            top: -6,
            right: -8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: isCredit ? theme.colorScheme.primary : Colors.redAccent,
                borderRadius: const BorderRadius.all(Radius.circular(10)),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '${_cart.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 4),
          Text(
            isCredit
                ? 'Fiado: ${_selectedCustomer!.name.split(' ').first}'
                : '${_cart.length} ${_cart.length == 1 ? 'ítem' : 'ítems'}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(width: 10),
          Container(
            width: 1,
            height: 16,
            color: Colors.white.withOpacity(0.4),
          ),
          const SizedBox(width: 10),
          Text(
            'S/ ${_cartTotal.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // MODAL DEL CARRITO (BOTTOM SHEET)
  // ==========================================
  void _showCartBottomSheet(BuildContext context) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final isCredit = _selectedCustomer != null;
            final availableCredit = isCredit
                ? (_selectedCustomer!.creditLimit - _selectedCustomer!.currentDebt)
                : 0.0;
            final bool exceedsCredit = isCredit && _cartTotal > availableCredit;

            return Container(
              height: MediaQuery.of(modalContext).size.height * 0.84,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Tirador estético superior (drag handle)
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // 1. Encabezado con título y botón para cerrar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isCredit ? Icons.handshake_rounded : Icons.shopping_cart_rounded,
                              color: isCredit ? Colors.orange[800] : theme.colorScheme.primary,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isCredit ? 'Carrito de Fiado' : 'Carrito de Venta',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isCredit ? Colors.orange : theme.colorScheme.primary)
                                    .withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_cart.length}',
                                style: TextStyle(
                                  color: isCredit ? Colors.orange[800] : theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Cerrar',
                          onPressed: () => Navigator.pop(modalContext),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // 2. Expanded con ListView de los ítems del carrito
                  Expanded(
                    child: _cart.isEmpty
                        ? const SizedBox.shrink()
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            itemCount: _cart.length,
                            separatorBuilder: (_, __) => const Divider(height: 14),
                            itemBuilder: (context, index) {
                              final item = _cart[index];
                              return _buildModalCartItem(
                                context: context,
                                item: item,
                                setModalState: setModalState,
                                modalContext: modalContext,
                              );
                            },
                          ),
                  ),

                  // 3. Tarjeta selectora de Cliente (Contado vs Fiado)
                  _buildCustomerSelectorSection(
                    context: context,
                    setModalState: setModalState,
                    modalContext: modalContext,
                  ),

                  // 4. Contenedor fijo (SafeArea) con "Total" y botón dinámico
                  SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, -3),
                          ),
                        ],
                        border: Border(
                          top: BorderSide(color: theme.dividerColor.withOpacity(0.2)),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. Desglose de Subtotal y Descuento
                          if (_discount > 0) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Subtotal:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  'S/ ${_cartSubtotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.14),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.local_offer_rounded, size: 12, color: Colors.green),
                                          SizedBox(width: 4),
                                          Text(
                                            'Descuento',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () async {
                                        final newDisc = await DiscountDialog.show(
                                          context,
                                          currentSubtotal: _cartSubtotal,
                                          initialDiscount: _discount,
                                        );
                                        if (newDisc != null) {
                                          setModalState(() {
                                            setState(() {
                                              _discount = newDisc;
                                            });
                                          });
                                        }
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.all(4.0),
                                        child: Icon(Icons.edit_outlined, size: 16, color: Colors.grey),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        setModalState(() {
                                          setState(() {
                                            _discount = 0.0;
                                          });
                                        });
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.all(4.0),
                                        child: Icon(Icons.close_rounded, size: 16, color: Colors.redAccent),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '- S/ ${_discount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Divider(height: 1),
                            const SizedBox(height: 6),
                          ] else ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Subtotal:',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'S/ ${_cartSubtotal.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                InkWell(
                                  onTap: () async {
                                    final newDisc = await DiscountDialog.show(
                                      context,
                                      currentSubtotal: _cartSubtotal,
                                      initialDiscount: _discount,
                                    );
                                    if (newDisc != null && newDisc > 0) {
                                      setModalState(() {
                                        setState(() {
                                          _discount = newDisc;
                                        });
                                      });
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.local_offer_outlined, size: 14, color: Colors.green[700]),
                                        const SizedBox(width: 4),
                                        Text(
                                          '+ Agregar Descuento',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],

                          // 2. Fila de Total Final a Cobrar / Fiar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isCredit ? 'Total a Fiar:' : 'Total a Pagar:',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                'S/ ${_cartTotal.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: isCredit ? Colors.orange[800] : theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _cart.isEmpty
                                  ? null
                                  : () {
                                      if (isCredit) {
                                        _processCreditCheckout(modalContext);
                                      } else {
                                        _processCashCheckout(modalContext);
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isCredit ? Colors.orange[800] : theme.colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isCredit ? Icons.handshake_rounded : Icons.payments_rounded,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      isCredit
                                          ? 'Fiar a ${_selectedCustomer!.name} (S/ ${_cartTotal.toStringAsFixed(2)})'
                                          : 'Cobrar al Contado (S/ ${_cartTotal.toStringAsFixed(2)})',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
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
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Sección interactiva de Selección de Cliente dentro del modal del carrito.
  Widget _buildCustomerSelectorSection({
    required BuildContext context,
    required StateSetter setModalState,
    required BuildContext modalContext,
  }) {
    final theme = Theme.of(context);
    final isCredit = _selectedCustomer != null;
    final availableCredit = isCredit
        ? (_selectedCustomer!.creditLimit - _selectedCustomer!.currentDebt)
        : 0.0;
    final bool exceedsCredit = isCredit && _cartTotal > availableCredit;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCredit
            ? Colors.orange.withOpacity(0.08)
            : theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCredit
              ? (exceedsCredit ? Colors.redAccent : Colors.orange.withOpacity(0.5))
              : Colors.grey.withOpacity(0.2),
          width: isCredit ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: isCredit
                    ? Colors.orange.withOpacity(0.2)
                    : theme.colorScheme.primary.withOpacity(0.12),
                child: Icon(
                  isCredit ? Icons.person_rounded : Icons.storefront_rounded,
                  size: 18,
                  color: isCredit ? Colors.orange[800] : theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCredit
                          ? 'Venta al Fiado (A Cuenta)'
                          : 'Venta al Contado (Público General)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isCredit ? Colors.orange[900] : Colors.grey[600],
                      ),
                    ),
                    Text(
                      isCredit ? _selectedCustomer!.name : 'Sin cliente asignado',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  final customer = await CustomerPickerModal.show(
                    modalContext,
                    currentSelected: _selectedCustomer,
                  );
                  setModalState(() {
                    _selectedCustomer = customer;
                  });
                  setState(() {});
                },
                icon: Icon(
                  isCredit ? Icons.swap_horiz_rounded : Icons.person_add_alt_1_rounded,
                  size: 16,
                  color: isCredit ? Colors.orange[800] : theme.colorScheme.primary,
                ),
                label: Text(
                  isCredit ? 'Cambiar' : 'Fiar',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isCredit ? Colors.orange[800] : theme.colorScheme.primary,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: isCredit
                      ? Colors.orange.withOpacity(0.15)
                      : theme.colorScheme.primary.withOpacity(0.1),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              if (isCredit) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                  tooltip: 'Quitar cliente (volver a Contado)',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () {
                    setModalState(() {
                      _selectedCustomer = null;
                    });
                    setState(() {});
                  },
                ),
              ],
            ],
          ),

          // Resumen de Deuda y Crédito Disponible si está en modo Fiado
          if (isCredit) ...[
            const Divider(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Deuda actual: S/ ${_selectedCustomer!.currentDebt.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _selectedCustomer!.currentDebt > 0 ? Colors.redAccent : Colors.green[800],
                  ),
                ),
                Text(
                  'Crédito disponible: S/ ${availableCredit.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: availableCredit > 0 ? Colors.grey[700] : Colors.redAccent,
                  ),
                ),
              ],
            ),
            if (exceedsCredit) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.redAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Excede el crédito disponible por S/ ${(_cartTotal - availableCredit).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// Fila de ítem dentro del modal con controles (+, -, basura) y sincronización de estado.
  Widget _buildModalCartItem({
    required BuildContext context,
    required CartItem item,
    required StateSetter setModalState,
    required BuildContext modalContext,
  }) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Nombre y precio unitario / subtotal
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.product.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Unit: S/ ${item.product.salePrice.toStringAsFixed(2)}  •  Sub: S/ ${item.subtotal.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        // Controles de cantidad (- y +) con soporte para unidades fraccionarias
        Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_rounded, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                splashRadius: 18,
                onPressed: () {
                  final step = item.product.allowsDecimals
                      ? (item.product.unit == 'kg' ? 0.25 : 0.5)
                      : 1.0;
                  setModalState(() {
                    if (item.quantity > step) {
                      item.quantity -= step;
                    } else {
                      _cart.remove(item);
                    }
                  });
                  setState(() {});

                  if (_cart.isEmpty) {
                    Navigator.pop(modalContext);
                  }
                },
              ),
              InkWell(
                onTap: item.product.allowsDecimals
                    ? () {
                        Navigator.pop(modalContext);
                        _showBulkMeasurementModal(item.product, existingCartItem: item);
                      }
                    : null,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
                  child: Text(
                    item.formattedQuantity,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_rounded, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                splashRadius: 18,
                onPressed: () {
                  final step = item.product.allowsDecimals
                      ? (item.product.unit == 'kg' ? 0.25 : 0.5)
                      : 1.0;
                  if (item.quantity + step <= item.product.stock) {
                    setModalState(() {
                      item.quantity += step;
                    });
                    setState(() {});
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Stock máximo alcanzado (${_formatStock(item.product.stock, item.product.unit)})'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // Ícono de basura para remover el producto del carrito
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
          tooltip: 'Eliminar del carrito',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          splashRadius: 18,
          onPressed: () {
            setModalState(() {
              _cart.remove(item);
            });
            setState(() {});

            if (_cart.isEmpty) {
              Navigator.pop(modalContext);
            }
          },
        ),
      ],
    );
  }

  // ==========================================
  // LAYOUT PRINCIPAL (CATÁLOGO A PANTALLA COMPLETA)
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 1. Buscador de productos con escáner integrado y acceso al Historial de Tickets
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      onSubmitted: _handleHardwareBarcodeScan,
                      decoration: InputDecoration(
                        hintText: 'Buscar o escanear código...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              ),
                            IconButton(
                              icon: Icon(
                                Icons.qr_code_scanner_rounded,
                                color: theme.colorScheme.primary,
                              ),
                              tooltip: 'Escanear con Cámara (Continuo)',
                              onPressed: _openPOSScanner,
                            ),
                          ],
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.receipt_long_rounded),
                    tooltip: 'Historial de Tickets',
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.all(12),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SalesHistoryScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),

            // 2. Filtro horizontal de categorías desde la BD
            if (_categories.isNotEmpty)
              _buildCategoryFilterBar(theme),

            // 3. Cuadrícula de productos a pantalla completa
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredProducts.isEmpty
                      ? _buildEmptyCatalogState(context)
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.78,
                          ),
                          itemCount: _filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = _filteredProducts[index];
                            return _buildProductCard(context, product);
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildFloatingCartButton(context),
    );
  }

  /// Tarjeta de producto individual para el catálogo.
  Widget _buildProductCard(BuildContext context, Product product) {
    final cartIndex = _cart.indexWhere((item) => item.product.id == product.id);
    final double quantityInCart = cartIndex >= 0 ? _cart[cartIndex].quantity : 0.0;

    return PosProductCard(
      product: product,
      quantityInCart: quantityInCart,
      onTap: () => _onProductCardTapped(product),
    );
  }

  /// Despliega el modal interactivo de pesaje o metraje con dos opciones:
  /// 1. Por Peso / Cantidad (kg, m, L)
  /// 2. Por Importe de Dinero (S/)
  Future<void> _showBulkMeasurementModal(Product product, {CartItem? existingCartItem}) async {
    final theme = Theme.of(context);
    final unit = product.unit;

    // Si ya está en el carrito, precargamos su cantidad actual
    final double initialQty = existingCartItem?.quantity ??
        (_cart.where((c) => c.product.id == product.id).firstOrNull?.quantity ?? 1.0);

    final quantityController = TextEditingController(
      text: initialQty % 1 == 0 ? initialQty.toInt().toString() : initialQty.toStringAsFixed(unit == 'kg' ? 3 : 2),
    );
    final moneyController = TextEditingController(
      text: (initialQty * product.salePrice).toStringAsFixed(2),
    );

    int activeModeIndex = 0; // 0 = Cantidad, 1 = Dinero

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final double currentQty = double.tryParse(quantityController.text.trim()) ?? 0.0;
            final bool exceedsStock = currentQty > product.stock;
            final bool isValid = currentQty > 0.0 && !exceedsStock;

            void updateFromQuantity(double newQty) {
              if (newQty < 0) newQty = 0;
              setModalState(() {
                quantityController.text = newQty % 1 == 0
                    ? newQty.toInt().toString()
                    : newQty.toStringAsFixed(unit == 'kg' ? 3 : 2);
                moneyController.text = (newQty * product.salePrice).toStringAsFixed(2);
              });
            }

            void updateFromMoney(double money) {
              if (money < 0) money = 0;
              final calculatedQty = product.salePrice > 0 ? (money / product.salePrice) : 0.0;
              setModalState(() {
                moneyController.text = money.toStringAsFixed(2);
                quantityController.text = calculatedQty % 1 == 0
                    ? calculatedQty.toInt().toString()
                    : calculatedQty.toStringAsFixed(unit == 'kg' ? 3 : 2);
              });
            }

            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Barra superior con título y botón de cierre
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Precio: S/ ${product.salePrice.toStringAsFixed(2)} por $unit  •  Stock: ${_formatStock(product.stock, unit)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Selector Segmentado de Modos (Cantidad vs Dinero)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.15)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setModalState(() => activeModeIndex = 0),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: activeModeIndex == 0 ? theme.colorScheme.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.scale_rounded,
                                      size: 16,
                                      color: activeModeIndex == 0 ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Por Cantidad ($unit)',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: activeModeIndex == 0 ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setModalState(() => activeModeIndex = 1),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: activeModeIndex == 1 ? theme.colorScheme.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.payments_outlined,
                                      size: 16,
                                      color: activeModeIndex == 1 ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Por Importe (S/)',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: activeModeIndex == 1 ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Campo de entrada activo según el modo
                    if (activeModeIndex == 0) ...[
                      // Modo 1: Por Cantidad / Peso
                      TextField(
                        controller: quantityController,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: 'Ingresa la cantidad ($unit)',
                          suffixText: unit,
                          prefixIcon: const Icon(Icons.fitness_center_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          filled: true,
                        ),
                        onChanged: (val) {
                          final parsedQty = double.tryParse(val.trim()) ?? 0.0;
                          setModalState(() {
                            moneyController.text = (parsedQty * product.salePrice).toStringAsFixed(2);
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      // Chips de acceso rápido para cantidad
                      Wrap(
                        spacing: 8,
                        children: [
                          if (unit == 'kg') ...[
                            _buildQuickChip('+0.25 kg', () => updateFromQuantity(currentQty + 0.25), theme),
                            _buildQuickChip('+0.50 kg', () => updateFromQuantity(currentQty + 0.50), theme),
                            _buildQuickChip('+1.00 kg', () => updateFromQuantity(currentQty + 1.00), theme),
                            _buildQuickChip('+2.00 kg', () => updateFromQuantity(currentQty + 2.00), theme),
                          ] else if (unit == 'm') ...[
                            _buildQuickChip('+0.5 m', () => updateFromQuantity(currentQty + 0.5), theme),
                            _buildQuickChip('+1.0 m', () => updateFromQuantity(currentQty + 1.0), theme),
                            _buildQuickChip('+2.0 m', () => updateFromQuantity(currentQty + 2.0), theme),
                            _buildQuickChip('+5.0 m', () => updateFromQuantity(currentQty + 5.0), theme),
                          ] else if (unit == 'L') ...[
                            _buildQuickChip('+0.5 L', () => updateFromQuantity(currentQty + 0.5), theme),
                            _buildQuickChip('+1.0 L', () => updateFromQuantity(currentQty + 1.0), theme),
                            _buildQuickChip('+2.0 L', () => updateFromQuantity(currentQty + 2.0), theme),
                          ] else ...[
                            _buildQuickChip('+1 $unit', () => updateFromQuantity(currentQty + 1.0), theme),
                            _buildQuickChip('+5 $unit', () => updateFromQuantity(currentQty + 5.0), theme),
                          ],
                        ],
                      ),
                    ] else ...[
                      // Modo 2: Por Importe de Dinero
                      TextField(
                        controller: moneyController,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: '¿Cuánto dinero desea el cliente?',
                          prefixText: 'S/ ',
                          prefixIcon: const Icon(Icons.attach_money_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          filled: true,
                        ),
                        onChanged: (val) {
                          final parsedMoney = double.tryParse(val.trim()) ?? 0.0;
                          final calculated = product.salePrice > 0 ? (parsedMoney / product.salePrice) : 0.0;
                          setModalState(() {
                            quantityController.text = calculated % 1 == 0
                                ? calculated.toInt().toString()
                                : calculated.toStringAsFixed(unit == 'kg' ? 3 : 2);
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      // Chips de dinero rápido
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildQuickChip('S/ 1.00', () => updateFromMoney(1.00), theme),
                          _buildQuickChip('S/ 2.00', () => updateFromMoney(2.00), theme),
                          _buildQuickChip('S/ 5.00', () => updateFromMoney(5.00), theme),
                          _buildQuickChip('S/ 10.00', () => updateFromMoney(10.00), theme),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Resumen de cálculo dinámico
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: exceedsStock
                              ? Colors.redAccent
                              : theme.colorScheme.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Cantidad a despachar:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              Text(
                                _formatQuantity(currentQty, unit),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Total a cobrar:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              Text(
                                'S/ ${(currentQty * product.salePrice).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    if (exceedsStock) ...[
                      const SizedBox(height: 8),
                      Text(
                        'La cantidad supera el stock disponible (${_formatStock(product.stock, unit)}).',
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const SizedBox(height: 18),

                    // Botón para agregar al carrito
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isValid ? theme.colorScheme.primary : Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: isValid
                          ? () {
                              _addToCart(product, quantity: currentQty, replaceQuantity: existingCartItem != null);
                              Navigator.pop(ctx);
                            }
                          : null,
                      icon: const Icon(Icons.add_shopping_cart_rounded),
                      label: Text(
                        existingCartItem != null
                            ? 'Actualizar en Carrito • S/ ${(currentQty * product.salePrice).toStringAsFixed(2)}'
                            : 'Agregar al Carrito • S/ ${(currentQty * product.salePrice).toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickChip(String label, VoidCallback onTap, ThemeData theme) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
      onPressed: onTap,
    );
  }

  String _formatStock(double stock, String unit) {
    final clean = (stock.isNaN || stock.isInfinite) ? 0.0 : stock;
    final u = unit.trim().isEmpty ? 'und' : unit.trim();
    if (clean % 1 == 0) {
      return '${clean.toInt()} $u';
    }
    return '${clean.toStringAsFixed(u == 'kg' ? 3 : 2)} $u';
  }

  String _formatQuantity(double qty, String unit) {
    final clean = (qty.isNaN || qty.isInfinite) ? 0.0 : qty;
    final u = unit.trim().isEmpty ? 'und' : unit.trim();
    if (clean % 1 == 0) {
      return '${clean.toInt()} $u';
    }
    return '${clean.toStringAsFixed(u == 'kg' ? 3 : 2)} $u';
  }

  /// Barra horizontal deslizable de categorías provenientes de la BD en tiempo real.
  Widget _buildCategoryFilterBar(ThemeData theme) {
    final isAllSelected = _selectedCategoryId == null;

    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildCategoryChip(
              label: 'Todos',
              isSelected: isAllSelected,
              theme: theme,
              onTap: () => _onCategorySelected(null),
              dotColor: null,
            );
          }

          final category = _categories[index - 1];
          final isSelected = _selectedCategoryId == category.id;
          final dotColor = _parseHexColor(category.hexColor, theme.colorScheme.primary);

          return _buildCategoryChip(
            label: category.name,
            isSelected: isSelected,
            theme: theme,
            onTap: () {
              if (isSelected) {
                _onCategorySelected(null);
              } else {
                _onCategorySelected(category.id);
              }
            },
            dotColor: dotColor,
          );
        },
      ),
    );
  }

  /// Chip individual de categoría para la barra de filtros.
  Widget _buildCategoryChip({
    required String label,
    required bool isSelected,
    required ThemeData theme,
    required VoidCallback onTap,
    Color? dotColor,
  }) {
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary
                : (isDark ? colorScheme.surface : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outline.withOpacity(0.18),
              width: 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.28),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Convierte una cadena hexadecimal a Color de Flutter con salvaguarda por defecto.
  Color _parseHexColor(String? hexString, Color defaultColor) {
    if (hexString == null || hexString.isEmpty) return defaultColor;
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return defaultColor;
    }
  }

  /// Estado vacío si no hay productos en el catálogo o no hay coincidencias con los filtros.
  Widget _buildEmptyCatalogState(BuildContext context) {
    final theme = Theme.of(context);
    final hasActiveFilters =
        _searchController.text.trim().isNotEmpty || _selectedCategoryId != null;

    if (_allProducts.isEmpty) {
      // Caso 1: La base de datos no tiene ningún producto registrado aún
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.storefront_outlined,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Catálogo vacío',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Aún no hay productos registrados en el sistema.\nPuedes agregarlos desde la sección Inventario & Stock.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    // Caso 2: Hay productos en la BD, pero ninguno coincide con la búsqueda o la categoría seleccionada
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 48,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sin resultados',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              _selectedCategoryId != null && _searchController.text.trim().isNotEmpty
                  ? 'No hay productos que coincidan con la búsqueda en esta categoría.'
                  : _selectedCategoryId != null
                      ? 'No hay productos registrados en la categoría seleccionada.'
                      : 'No se encontraron productos que coincidan con la búsqueda.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
            ),
            if (hasActiveFilters) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () {
                  _searchController.clear();
                  _selectedCategoryId = null;
                  setState(() {
                    _applyFilters();
                  });
                },
                icon: const Icon(Icons.clear_all_rounded, size: 18),
                label: const Text('Limpiar filtros'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
