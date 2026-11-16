import 'package:flutter/material.dart';
import 'package:bodego/data/local/isar/collections/category.dart';
import 'package:bodego/data/local/isar/collections/product.dart';
import 'package:bodego/data/repositories/inventory_repository.dart';
import 'package:bodego/presentation/widgets/modern_barcode_scanner.dart';
import 'package:bodego/presentation/screens/inventory/wholesale_stock_screen.dart';

/// Pantalla principal del Módulo de Inventario con pestañas de Productos y Categorías.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  final InventoryRepository _inventoryRepository = InventoryRepository();
  late TabController _tabController;

  List<Product> _products = [];
  List<Category> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {}); // Actualiza el FloatingActionButton según el tab activo
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final categories = await _inventoryRepository.getCategories();
    final products = await _inventoryRepository.getProducts();

    if (mounted) {
      setState(() {
        _categories = categories;
        _products = products;
        _isLoading = false;
      });
    }
  }

  /// Formatea el stock protegiendo contra valores nulos o legados NaN.
  String _formatStock(double stock, String unit) {
    final clean = (stock.isNaN || stock.isInfinite) ? 0.0 : stock;
    final u = unit.trim().isEmpty ? 'und' : unit.trim();
    if (clean % 1 == 0) {
      return '${clean.toInt()} $u';
    }
    return '${clean.toStringAsFixed(u == 'kg' ? 3 : 2)} $u';
  }

  // ==========================================
  // TAREA 4: FORMULARIOS (BOTTOMSHEETS)
  // ==========================================

  /// Modal BottomSheet para agregar una nueva categoría
  void _showAddCategoryModal() {
    final nameController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Nueva Categoría',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Nombre de la Categoría *',
                  hintText: 'Ej. Abarrotes, Bebidas, Lácteos',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.category_outlined),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;

                  await _inventoryRepository.addCategory(name, null);
                  if (mounted) {
                    Navigator.pop(ctx);
                    _loadData();
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Guardar Categoría',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Modal BottomSheet para registrar un nuevo producto o editar uno existente
  void _showAddProductModal() {
    _showProductModal();
  }

  void _showProductModal({Product? productToEdit}) {
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Crea al menos una categoría antes de registrar un producto.'),
          backgroundColor: Colors.orange,
        ),
      );
      _tabController.animateTo(1);
      return;
    }

    final bool isEditing = productToEdit != null;

    final nameController = TextEditingController(text: productToEdit?.name ?? '');
    final barcodeController = TextEditingController(text: productToEdit?.barcode ?? '');
    final costController = TextEditingController(
      text: (productToEdit != null && productToEdit.costPrice > 0)
          ? (productToEdit.costPrice % 1 == 0
              ? productToEdit.costPrice.toInt().toString()
              : productToEdit.costPrice.toStringAsFixed(2))
          : '',
    );
    final saleController = TextEditingController(
      text: productToEdit != null
          ? (productToEdit.salePrice % 1 == 0
              ? productToEdit.salePrice.toInt().toString()
              : productToEdit.salePrice.toStringAsFixed(2))
          : '',
    );
    final stockController = TextEditingController(
      text: productToEdit != null
          ? (productToEdit.stock % 1 == 0
              ? productToEdit.stock.toInt().toString()
              : productToEdit.stock.toString())
          : '',
    );
    final minStockController = TextEditingController(
      text: productToEdit != null
          ? (productToEdit.minStock % 1 == 0
              ? productToEdit.minStock.toInt().toString()
              : productToEdit.minStock.toString())
          : '5',
    );
    int selectedCategoryId = productToEdit?.category.value?.id ?? _categories.first.id;
    if (!_categories.any((c) => c.id == selectedCategoryId)) {
      selectedCategoryId = _categories.first.id;
    }
    String selectedUnit = (productToEdit != null && productToEdit.unit.isNotEmpty)
        ? productToEdit.unit
        : 'und';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final bool isDecimalUnit = selectedUnit == 'kg' ||
                selectedUnit == 'g' ||
                selectedUnit == 'm' ||
                selectedUnit == 'L';

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isEditing ? Icons.edit_note_rounded : Icons.add_circle_outline_rounded,
                              color: Theme.of(context).colorScheme.primary,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isEditing ? 'Editar Producto' : 'Nuevo Producto',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Nombre del Producto
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      autofocus: !isEditing,
                      decoration: InputDecoration(
                        labelText: 'Nombre del Producto *',
                        hintText: 'Ej. Arroz Costeño a granel',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Código de Barras con ícono de escáner moderno
                    TextField(
                      controller: barcodeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Código de Barras (Opcional)',
                        hintText: 'Ej. 7750182001018',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            Icons.qr_code_scanner_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          tooltip: 'Escanear Código de Barras con Cámara',
                          onPressed: () async {
                            final scanned = await ModernBarcodeScanner.scanSingle(
                              context,
                              title: 'Escanear Código de Barras',
                              subtitle: 'Enfoca el código de barras dentro del marco',
                            );
                            if (scanned != null && scanned.isNotEmpty) {
                              setModalState(() {
                                barcodeController.text = scanned;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Dropdown de Categoría (ancho completo con isExpanded)
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      value: selectedCategoryId,
                      decoration: InputDecoration(
                        labelText: 'Categoría *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.category_outlined),
                      ),
                      items: _categories.map((cat) {
                        return DropdownMenuItem<int>(
                          value: cat.id,
                          child: Text(cat.name, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            selectedCategoryId = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Dropdown de Unidad de Medida (ancho completo con isExpanded)
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: selectedUnit,
                      decoration: InputDecoration(
                        labelText: 'Unidad de Medida *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.scale_rounded),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'und', child: Text('Unidad (und) - Por pieza')),
                        DropdownMenuItem(value: 'kg', child: Text('Kilogramos (kg) - Venta por peso')),
                        DropdownMenuItem(value: 'g', child: Text('Gramos (g) - Venta por gramos')),
                        DropdownMenuItem(value: 'm', child: Text('Metros (m) - Venta por longitud')),
                        DropdownMenuItem(value: 'L', child: Text('Litros (L) - Venta por volumen')),
                        DropdownMenuItem(value: 'paq', child: Text('Paquete (paq) - Empaque')),
                        DropdownMenuItem(value: 'caja', child: Text('Caja (caja) - Por caja')),
                        DropdownMenuItem(value: 'doc', child: Text('Docena (doc) - 12 unidades')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            selectedUnit = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Fila de Precios: Costo y Venta
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: costController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'P. Costo',
                              prefixText: 'S/ ',
                              hintText: '0.00',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: saleController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: selectedUnit == 'und'
                                  ? 'P. Venta *'
                                  : 'P. Venta ($selectedUnit) *',
                              prefixText: 'S/ ',
                              hintText: '0.00',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Fila de Stock: Actual y Mínimo
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: stockController,
                            keyboardType: TextInputType.numberWithOptions(decimal: isDecimalUnit),
                            decoration: InputDecoration(
                              labelText: 'Stock ($selectedUnit) *',
                              hintText: isDecimalUnit ? '0.00' : '0',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: minStockController,
                            keyboardType: TextInputType.numberWithOptions(decimal: isDecimalUnit),
                            decoration: InputDecoration(
                              labelText: 'Mínimo ($selectedUnit)',
                              hintText: isDecimalUnit ? '5.0' : '5',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Botón Guardar
                    ElevatedButton(
                      onPressed: () async {
                        final name = nameController.text.trim();
                        final salePrice = double.tryParse(saleController.text.trim());
                        final stock = double.tryParse(stockController.text.trim());

                        if (name.isEmpty || salePrice == null || stock == null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Por favor completa los campos requeridos (*).'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                          return;
                        }

                        final costPrice = double.tryParse(costController.text.trim()) ?? 0.0;
                        final minStock = double.tryParse(minStockController.text.trim()) ?? 5.0;
                        final barcode = barcodeController.text.trim();
                        final messenger = ScaffoldMessenger.of(context);
                        final nav = Navigator.of(ctx);
                        final primaryColor = Theme.of(context).colorScheme.primary;

                        if (isEditing) {
                          await _inventoryRepository.updateProduct(
                            productToEdit.id,
                            name: name,
                            barcode: barcode.isEmpty ? null : barcode,
                            costPrice: costPrice,
                            salePrice: salePrice,
                            stock: stock,
                            minStock: minStock,
                            categoryId: selectedCategoryId,
                            unit: selectedUnit,
                          );
                        } else {
                          await _inventoryRepository.addProduct(
                            name,
                            barcode.isEmpty ? null : barcode,
                            costPrice,
                            salePrice,
                            stock,
                            minStock,
                            selectedCategoryId,
                            unit: selectedUnit,
                          );
                        }

                        if (mounted) {
                          nav.pop();
                          _loadData();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                isEditing
                                    ? '¡Producto "$name" actualizado con éxito!'
                                    : '¡Producto "$name" registrado con éxito!',
                              ),
                              backgroundColor: isEditing
                                  ? primaryColor
                                  : Colors.green[700],
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        isEditing ? 'Guardar Cambios' : 'Guardar Producto',
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

  /// Modal BottomSheet para ingreso rápido de lotes de mercadería (+Stock)
  void _showReplenishStockModal(Product product) {
    final bool isDecimalUnit = product.allowsDecimals;
    final qtyController = TextEditingController();
    final newCostController = TextEditingController();
    final newSaleController = TextEditingController();
    bool showPriceAdjustments = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final double currentStock =
                (product.stock.isNaN || product.stock < 0) ? 0.0 : product.stock;
            final double enteredQty = double.tryParse(qtyController.text.trim()) ?? 0.0;
            final double resultingStock = currentStock + enteredQty;

            List<double> quickChips;
            if (product.unit == 'kg') {
              quickChips = [5.0, 10.0, 25.0, 50.0];
            } else if (product.unit == 'g') {
              quickChips = [250.0, 500.0, 1000.0, 2500.0];
            } else if (product.unit == 'm' || product.unit == 'L') {
              quickChips = [5.0, 10.0, 20.0, 50.0];
            } else {
              quickChips = [6.0, 12.0, 24.0, 48.0, 100.0];
            }

            void addChipValue(double val) {
              final currentVal = double.tryParse(qtyController.text.trim()) ?? 0.0;
              final newVal = currentVal + val;
              setModalState(() {
                qtyController.text = (newVal % 1 == 0)
                    ? newVal.toInt().toString()
                    : newVal.toStringAsFixed(2);
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Encabezado
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.teal.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.add_box_rounded, color: Colors.teal, size: 22),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Ingreso de Lote / Stock',
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  product.name,
                                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Tarjeta de Estado Actual
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Stock Actual',
                                  style: TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 2),
                              Text(
                                _formatStock(currentStock, product.unit),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Container(height: 24, width: 1, color: Colors.grey.withOpacity(0.3)),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Precios Actuales',
                                  style: TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 2),
                              Text(
                                'C: S/ ${product.costPrice.toStringAsFixed(2)}  |  V: S/ ${product.salePrice.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Campo de Cantidad Recibida
                    TextField(
                      controller: qtyController,
                      autofocus: true,
                      keyboardType: TextInputType.numberWithOptions(decimal: isDecimalUnit),
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Cantidad que ingresa (${product.unit}) *',
                        hintText: isDecimalUnit ? 'Ej. 25.0' : 'Ej. 24',
                        prefixIcon: const Icon(Icons.playlist_add_rounded, color: Colors.teal),
                        suffixText: product.unit,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Chips de Acceso Rápido
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: quickChips.map((val) {
                        final label = (val % 1 == 0)
                            ? '+${val.toInt()} ${product.unit}'
                            : '+$val ${product.unit}';
                        return ActionChip(
                          avatar: const Icon(Icons.add, size: 14, color: Colors.teal),
                          label: Text(label,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          backgroundColor: Colors.teal.withOpacity(0.08),
                          side: BorderSide(color: Colors.teal.withOpacity(0.25)),
                          onPressed: () => addChipValue(val),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Tarjeta de Previsualización de Nuevo Stock
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: enteredQty > 0
                            ? Colors.teal.withOpacity(0.10)
                            : Colors.grey.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: enteredQty > 0
                              ? Colors.teal.withOpacity(0.4)
                              : Colors.grey.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Nuevo Stock resultante:',
                            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                          ),
                          Row(
                            children: [
                              Text(
                                _formatStock(currentStock, product.unit),
                                style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                    decoration: TextDecoration.lineThrough),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.teal),
                              const SizedBox(width: 8),
                              Text(
                                _formatStock(resultingStock, product.unit),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: enteredQty > 0 ? Colors.teal[800] : Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Toggle: ¿Cambió el costo de compra de este lote?
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        setModalState(() {
                          showPriceAdjustments = !showPriceAdjustments;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Icon(
                              showPriceAdjustments
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '¿Cambió el costo o precio de este lote? (Opcional)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (showPriceAdjustments) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: newCostController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Nuevo P. Costo',
                                hintText: product.costPrice.toStringAsFixed(2),
                                prefixText: 'S/ ',
                                border:
                                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: newSaleController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Nuevo P. Venta',
                                hintText: product.salePrice.toStringAsFixed(2),
                                prefixText: 'S/ ',
                                border:
                                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Botón Confirmar Ingreso
                    ElevatedButton.icon(
                      onPressed: enteredQty <= 0
                          ? null
                          : () async {
                              final double? updatedCost =
                                  double.tryParse(newCostController.text.trim());
                              final double? updatedSale =
                                  double.tryParse(newSaleController.text.trim());
                              final messenger = ScaffoldMessenger.of(context);
                              final nav = Navigator.of(ctx);

                              await _inventoryRepository.replenishStock(
                                product.id,
                                enteredQty,
                                newCostPrice: updatedCost,
                                newSalePrice: updatedSale,
                              );

                              if (mounted) {
                                nav.pop();
                                _loadData();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '¡Lote registrado! Se sumaron ${_formatStock(enteredQty, product.unit)} a ${product.name}.',
                                    ),
                                    backgroundColor: Colors.teal[700],
                                  ),
                                );
                              }
                            },
                      icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                      label: Text(
                        enteredQty > 0
                            ? 'Confirmar (+${_formatStock(enteredQty, product.unit)})'
                            : 'Ingresa una cantidad',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        disabledBackgroundColor: Colors.grey[300],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  /// Diálogo de confirmación para eliminar un producto
  Future<void> _confirmDeleteProduct(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Producto'),
        content: Text('¿Deseas eliminar "${product.name}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _inventoryRepository.deleteProduct(product.id);
      _loadData();
    }
  }

  // ==========================================
  // TAREA 3: VISTAS DE LISTADO
  // ==========================================

  /// Vista de Productos
  Widget _buildProductsView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'No hay productos en inventario',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Toca el botón inferior para agregar tu primer producto.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        final bool isLowStock = !product.stock.isNaN &&
            product.stock <= (product.minStock.isNaN ? 5.0 : product.minStock);
        final categoryName = product.category.value?.name ?? 'Sin categoría';

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            onTap: () => _showProductModal(productToEdit: product),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
              child: Icon(
                Icons.inventory_2_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            title: Text(
              product.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                children: [
                  Text(
                    'S/ ${product.salePrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 13,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5.0),
                    child: Text(
                      '•',
                      style: TextStyle(color: Colors.grey[400], fontSize: 11),
                    ),
                  ),
                  Text(
                    'Stock: ${_formatStock(product.stock, product.unit)}',
                    style: TextStyle(
                      color: isLowStock ? Colors.redAccent : Colors.grey[800],
                      fontWeight: isLowStock ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                  if (isLowStock) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.redAccent),
                  ],
                  if (categoryName.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '[$categoryName]',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _showReplenishStockModal(product),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.teal.withOpacity(0.35)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_box_rounded, color: Colors.teal, size: 15),
                          SizedBox(width: 4),
                          Text(
                            '+ Lote',
                            style: TextStyle(
                              color: Colors.teal,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.grey, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onSelected: (val) {
                    if (val == 'edit') {
                      _showProductModal(productToEdit: product);
                    } else if (val == 'replenish') {
                      _showReplenishStockModal(product);
                    } else if (val == 'delete') {
                      _confirmDeleteProduct(product);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'replenish',
                      child: Row(
                        children: [
                          Icon(Icons.add_box_rounded, color: Colors.teal, size: 18),
                          SizedBox(width: 10),
                          Text('Ingresar Lote (+Stock)'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 18),
                          SizedBox(width: 10),
                          Text('Editar Producto'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                          SizedBox(width: 10),
                          Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Vista de Categorías
  Widget _buildCategoriesView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.category_outlined, size: 60, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'No hay categorías registradas',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Toca el botón inferior para crear una categoría.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
              child: Icon(
                Icons.folder_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            title: Text(
              category.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Eliminar Categoría',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Eliminar Categoría'),
                    content: Text('¿Deseas eliminar la categoría "${category.name}"?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await _inventoryRepository.deleteCategory(category.id);
                  _loadData();
                }
              },
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // TAREA 2: INTERFAZ PRINCIPAL CON TABS & FAB
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isProductsTab = _tabController.index == 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario y Catálogo'),
        centerTitle: false,
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4353FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.shopping_bag_rounded, size: 16),
            label: const Text('Modo Mayorista', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WholesaleStockScreen()),
              );
            },
          ),
          const SizedBox(width: 12),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
          tabs: const [
            Tab(
              icon: Icon(Icons.inventory_2_rounded),
              text: 'Productos',
            ),
            Tab(
              icon: Icon(Icons.category_rounded),
              text: 'Categorías',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProductsView(),
          _buildCategoriesView(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: theme.colorScheme.primary,
        onPressed: isProductsTab ? _showAddProductModal : _showAddCategoryModal,
        icon: Icon(
          isProductsTab ? Icons.add_shopping_cart_rounded : Icons.create_new_folder_rounded,
          color: Colors.white,
        ),
        label: Text(
          isProductsTab ? 'Nuevo Producto' : 'Nueva Categoría',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
