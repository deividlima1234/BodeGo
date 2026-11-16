import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bodego/data/local/isar/collections/product.dart';
import 'package:bodego/data/repositories/product_repository.dart';
import 'package:bodego/core/services/device_pairing_service.dart';

/// Item de compra planificado dentro del Modo Mayorista
class WholesaleCartItem {
  final Product product;
  double quantityToBuy;
  double customCostPrice;

  WholesaleCartItem({
    required this.product,
    required this.quantityToBuy,
    required this.customCostPrice,
  });

  double get subtotal => quantityToBuy * customCostPrice;
}

/// Pantalla optimizada para cuando el dueño o encargado asiste al Mercado Mayorista / Distribuidora.
/// - Filtra productos en Stock Crítico (stock <= minStock o stock == 0).
/// - Calculadora de presupuesto de compra en tiempo real con precios de costo.
/// - Registro directo de recepción de nuevos lotes de mercadería.
class WholesaleStockScreen extends StatefulWidget {
  const WholesaleStockScreen({super.key});

  @override
  State<WholesaleStockScreen> createState() => _WholesaleStockScreenState();
}

class _WholesaleStockScreenState extends State<WholesaleStockScreen> {
  final ProductRepository _productRepo = ProductRepository();
  final DevicePairingService _pairingService = DevicePairingService();

  List<Product> _allProducts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _activeFilter = 'all_critical'; // 'all_critical', 'out_of_stock', 'low_stock'

  // Mapa de productos seleccionados para compra: productId -> WholesaleCartItem
  final Map<int, WholesaleCartItem> _purchaseList = {};

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final prods = await _productRepo.getAllProducts();
    if (mounted) {
      setState(() {
        _allProducts = prods;
        _isLoading = false;
        _autoPopulateSuggestedPurchases(prods);
      });
    }
  }

  /// Sugiere automáticamente cantidades de compra para productos críticos
  void _autoPopulateSuggestedPurchases(List<Product> products) {
    for (final p in products) {
      final isLow = p.stock <= p.minStock;
      if (isLow && !_purchaseList.containsKey(p.id)) {
        final double needed = (p.minStock * 2 - p.stock);
        final double suggested = needed > 0 ? (needed < 1 ? 1.0 : needed) : 5.0;
        _purchaseList[p.id] = WholesaleCartItem(
          product: p,
          quantityToBuy: suggested,
          customCostPrice: p.costPrice,
        );
      }
    }
  }

  List<Product> get _filteredProducts {
    return _allProducts.where((p) {
      final matchesSearch = p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (p.barcode != null && p.barcode!.contains(_searchQuery));

      if (!matchesSearch) return false;

      final isOutOfStock = p.stock <= 0;
      final isLowStock = p.stock > 0 && p.stock <= p.minStock;

      if (_activeFilter == 'out_of_stock') return isOutOfStock;
      if (_activeFilter == 'low_stock') return isLowStock;
      // 'all_critical':
      return isOutOfStock || isLowStock;
    }).toList();
  }

  double get _totalEstimatedBudget {
    double total = 0.0;
    for (final item in _purchaseList.values) {
      if (item.quantityToBuy > 0) {
        total += item.subtotal;
      }
    }
    return total;
  }

  int get _itemsToBuyCount {
    return _purchaseList.values.where((item) => item.quantityToBuy > 0).length;
  }

  void _confirmBatchReceipt() async {
    final itemsToReceive = _purchaseList.values.where((item) => item.quantityToBuy > 0).toList();
    if (itemsToReceive.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No has seleccionado cantidades de compra.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.inventory_rounded, color: Color(0xFF4353FF)),
            SizedBox(width: 10),
            Text('Confirmar Compra'),
          ],
        ),
        content: Text(
          '¿Deseas registrar el ingreso de $_itemsToBuyCount productos al inventario?\n\nPresupuesto estimado: S/ ${_totalEstimatedBudget.toStringAsFixed(2)}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4353FF),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('INGRESAR AL STOCK'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final batchList = itemsToReceive.map((item) {
        return {
          'barcode': item.product.barcode,
          'name': item.product.name,
          'addedStock': item.quantityToBuy,
          'newCost': item.customCostPrice,
        };
      }).toList();

      await _pairingService.applyWholesaleBatch(batchList);
      HapticFeedback.heavyImpact();

      await _loadProducts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Stock actualizado correctamente en el equipo!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _sharePurchaseListViaWhatsApp() {
    final itemsToReceive = _purchaseList.values.where((item) => item.quantityToBuy > 0).toList();
    if (itemsToReceive.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln('🛒 *LISTA DE COMPRAS MAYORISTA - BODEGO*');
    buffer.writeln('📅 ${DateTime.now().toString().split('.')[0]}\n');

    for (final item in itemsToReceive) {
      final qtyStr = item.quantityToBuy % 1 == 0
          ? item.quantityToBuy.toInt().toString()
          : item.quantityToBuy.toStringAsFixed(2);
      buffer.writeln('• ${item.product.name} [x$qtyStr ${item.product.unit}] (Costo: S/ ${item.customCostPrice.toStringAsFixed(2)}) = S/ ${item.subtotal.toStringAsFixed(2)}');
    }

    buffer.writeln('\n💰 *PRESUPUESTO TOTAL ESTIMADO: S/ ${_totalEstimatedBudget.toStringAsFixed(2)}*');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Lista de compras copiada para compartir por WhatsApp.'),
        backgroundColor: Color(0xFF25D366),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filtered = _filteredProducts;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Modo Mayorista & Compras',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Reposición de Stock Crítico y Presupuesto',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Color(0xFF25D366)),
            tooltip: 'Compartir lista por WhatsApp',
            onPressed: _sharePurchaseListViaWhatsApp,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar catálogo',
            onPressed: _loadProducts,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Barra de Búsqueda
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar producto por nombre o código...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),

                // Filtros de Estado
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: Row(
                    children: [
                      _buildFilterChip('all_critical', 'Todos los Críticos (${_allProducts.where((p) => p.stock <= p.minStock).length})'),
                      const SizedBox(width: 8),
                      _buildFilterChip('out_of_stock', 'Agotados (Stock 0) (${_allProducts.where((p) => p.stock <= 0).length})'),
                      const SizedBox(width: 8),
                      _buildFilterChip('low_stock', 'Stock Bajo (<= Mínimo) (${_allProducts.where((p) => p.stock > 0 && p.stock <= p.minStock).length})'),
                    ],
                  ),
                ),
                const Divider(height: 16),

                // Lista de Productos Críticos
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_outline_rounded, size: 54, color: Colors.green),
                              const SizedBox(height: 12),
                              const Text(
                                '¡Excelente! No hay productos con stock crítico',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Todo el inventario está por encima del stock mínimo.',
                                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final product = filtered[index];
                            final item = _purchaseList[product.id] ??
                                WholesaleCartItem(
                                  product: product,
                                  quantityToBuy: 0,
                                  customCostPrice: product.costPrice,
                                );
                            return _buildProductCard(product, item, theme, isDark);
                          },
                        ),
                ),

                // Barra Flotante Inferior: Presupuesto y Confirmación
                _buildBottomBudgetBar(theme, isDark),
              ],
            ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _activeFilter == key;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      selectedColor: const Color(0xFF4353FF).withOpacity(0.18),
      onSelected: (_) => setState(() => _activeFilter = key),
    );
  }

  Widget _buildProductCard(Product product, WholesaleCartItem item, ThemeData theme, bool isDark) {
    final isOutOfStock = product.stock <= 0;
    final unit = product.unit;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOutOfStock
              ? Colors.redAccent.withOpacity(0.5)
              : Colors.orange.withOpacity(0.4),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isOutOfStock
                                ? Colors.red.withOpacity(0.15)
                                : Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isOutOfStock ? 'AGOTADO (0 $unit)' : 'STOCK: ${product.stock} $unit (Mín: ${product.minStock})',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: isOutOfStock ? Colors.redAccent : Colors.orange,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Costo: S/ ${item.customCostPrice.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Subtotal de este producto
              if (item.quantityToBuy > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Subtotal', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(
                      'S/ ${item.subtotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF4353FF),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Stepper de Cantidad a Comprar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Comprar:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Row(
                children: [
                  IconButton.filledTonal(
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.remove_rounded),
                    onPressed: item.quantityToBuy > 0
                        ? () {
                            setState(() {
                              item.quantityToBuy = (item.quantityToBuy - 1).clamp(0, 9999);
                              _purchaseList[product.id] = item;
                            });
                          }
                        : null,
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.quantityToBuy % 1 == 0
                          ? item.quantityToBuy.toInt().toString()
                          : item.quantityToBuy.toStringAsFixed(2),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: const Color(0xFF4353FF)),
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.add_rounded, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        item.quantityToBuy += 1.0;
                        _purchaseList[product.id] = item;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBudgetBar(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_itemsToBuyCount productos marcados',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Row(
                    children: [
                      const Text(
                        'Presupuesto: ',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        'S/ ${_totalEstimatedBudget.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Color(0xFF4353FF),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4353FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
              label: const Text(
                'REGISTRAR LOTE',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: _itemsToBuyCount > 0 ? _confirmBatchReceipt : null,
            ),
          ],
        ),
      ),
    );
  }
}
