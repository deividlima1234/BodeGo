import 'package:flutter/material.dart';
import 'package:bodego/data/local/isar/collections/product.dart';
import 'package:bodego/data/local/isar/collections/customer.dart';
import 'package:bodego/data/models/cart_item.dart';
import 'package:bodego/data/models/sale_ticket.dart';
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

/// Módulo de Caja (Punto de Venta) con catálogo a pantalla completa,
/// carrito flotante, emisión de tickets con bordes dentados y gestión de fiados.
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
  final List<CartItem> _cart = [];
  final TextEditingController _searchController = TextEditingController();

  /// Cliente seleccionado para la venta actual (`null` representa Público General / Al Contado).
  Customer? _selectedCustomer;

  String _businessName = 'BodeGo';
  String _cashierName = 'Cajero de Turno';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _loadSessionData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  /// Carga los productos de Isar y los asigna a las listas de catálogo.
  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final products = await _inventoryRepository.getProducts();

    if (mounted) {
      setState(() {
        _allProducts = products;
        _filteredProducts = products;
        _isLoading = false;
      });
    }
  }

  /// Filtra los productos por nombre o código de barras en tiempo real.
  void _onSearchChanged(String query) {
    final cleanQuery = query.trim().toLowerCase();
    setState(() {
      if (cleanQuery.isEmpty) {
        _filteredProducts = _allProducts;
      } else {
        _filteredProducts = _allProducts.where((product) {
          final matchesName = product.name.toLowerCase().contains(cleanQuery);
          final matchesBarcode =
              product.barcode?.toLowerCase().contains(cleanQuery) ?? false;
          return matchesName || matchesBarcode;
        }).toList();
      }
    });
  }

  /// Agrega un producto al carrito de compras y actualiza la UI.
  void _addToCart(Product product) {
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
        if (_cart[index].quantity < product.stock) {
          _cart[index].quantity++;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Stock máximo alcanzado (${product.stock} und)'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else {
        _cart.add(CartItem(product: product));
      }
    });
  }

  /// Getter que calcula el total acumulado de todos los ítems en el carrito.
  double get _cartTotal => _cart.fold(0.0, (sum, item) => sum + item.subtotal);

  // ==========================================
  // OPERACIONES DE COBRO (CONTADO VS FIADO) Y EMISIÓN DE TICKET
  // ==========================================

  /// Procesa la venta al Contado (Público General):
  /// Descuenta stock en Isar, persiste el ticket y abre el modal del ticket con bordes dentados.
  Future<void> _processCashCheckout(BuildContext modalContext) async {
    if (_cart.isEmpty) return;

    Navigator.pop(modalContext);

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
            ))
        .toList();

    // 3. Crear y persistir el ticket en el historial local
    final ticket = await _ticketRepository.createTicket(
      total: total,
      isCredit: false,
      cashierName: _cashierName,
      businessName: _businessName,
      items: ticketItems,
    );

    setState(() {
      _cart.clear();
      _selectedCustomer = null;
    });
    _loadProducts();

    // Impresión automática en ticketera si está vinculada y activa
    final printerConfig = await PrinterRepository().getConfig();
    if (printerConfig.isConnected && printerConfig.autoPrintOnSale) {
      PrinterRepository().printTestTicket(printerConfig);
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
            ))
        .toList();

    // 4. Crear y persistir el ticket de fiado en el historial
    final ticket = await _ticketRepository.createTicket(
      total: total,
      isCredit: true,
      customerId: customer.id,
      customerName: customer.name,
      previousDebt: previousDebt,
      newDebt: newDebt,
      cashierName: _cashierName,
      businessName: _businessName,
      items: ticketItems,
    );

    setState(() {
      _cart.clear();
      _selectedCustomer = null;
    });
    _loadProducts();

    // Impresión automática en ticketera si está vinculada y activa
    final printerConfig = await PrinterRepository().getConfig();
    if (printerConfig.isConnected && printerConfig.autoPrintOnSale) {
      PrinterRepository().printTestTicket(printerConfig);
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

        // Controles de cantidad (- y +)
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
                  setModalState(() {
                    if (item.quantity > 1) {
                      item.quantity--;
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  '${item.quantity}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_rounded, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                splashRadius: 18,
                onPressed: () {
                  if (item.quantity < item.product.stock) {
                    setModalState(() {
                      item.quantity++;
                    });
                    setState(() {});
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Stock límite (${item.product.stock} und)'),
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
            // 1. Buscador de productos con botón de acceso al Historial de Tickets
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Buscar producto o código de barras...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
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

            // 2. Cuadrícula de productos a pantalla completa
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
                            childAspectRatio: 0.95,
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
    final theme = Theme.of(context);
    final bool isOutOfStock = product.stock <= 0;
    final bool isLowStock = product.stock <= product.minStock;

    // Cantidad actual de este producto en el carrito para feedback visual
    final cartIndex = _cart.indexWhere((item) => item.product.id == product.id);
    final int quantityInCart = cartIndex >= 0 ? _cart[cartIndex].quantity : 0;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      shadowColor: Colors.black.withOpacity(0.08),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isOutOfStock ? null : () => _addToCart(product),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Fila superior: Indicador de stock y badge de cantidad en carrito
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOutOfStock
                          ? Colors.grey.withOpacity(0.2)
                          : isLowStock
                              ? Colors.redAccent.withOpacity(0.15)
                              : Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isOutOfStock ? 'Agotado' : '${product.stock} disp.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isOutOfStock
                            ? Colors.grey[700]
                            : isLowStock
                                ? Colors.redAccent
                                : Colors.green[800],
                      ),
                    ),
                  ),
                  if (quantityInCart > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$quantityInCart',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 8),

              // Nombre del producto
              Expanded(
                child: Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(height: 8),

              // Precio y botón de agregar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Precio',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      Text(
                        'S/ ${product.salePrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isOutOfStock
                          ? Colors.grey.withOpacity(0.2)
                          : theme.colorScheme.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add_shopping_cart_rounded,
                      size: 18,
                      color: isOutOfStock ? Colors.grey : theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Estado vacío si no hay productos en el catálogo.
  Widget _buildEmptyCatalogState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.storefront_outlined, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          const Text(
            'Catálogo vacío',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'No se encontraron productos registrados o que coincidan con la búsqueda.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadProducts,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Recargar Catálogo'),
          ),
        ],
      ),
    );
  }
}
