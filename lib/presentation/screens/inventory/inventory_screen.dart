import 'package:flutter/material.dart';
import 'package:bodego/data/local/isar/collections/category.dart';
import 'package:bodego/data/local/isar/collections/product.dart';
import 'package:bodego/data/repositories/inventory_repository.dart';

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

  /// Modal BottomSheet para registrar un nuevo producto
  void _showAddProductModal() {
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

    final nameController = TextEditingController();
    final barcodeController = TextEditingController();
    final costController = TextEditingController();
    final saleController = TextEditingController();
    final stockController = TextEditingController();
    final minStockController = TextEditingController(text: '5');
    int selectedCategoryId = _categories.first.id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
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
                        const Text(
                          'Nuevo Producto',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Nombre del Producto *',
                        hintText: 'Ej. Arroz Costeño 1kg',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Código de Barras con ícono de escáner
                    TextField(
                      controller: barcodeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Código de Barras (Opcional)',
                        hintText: 'Ej. 7750182001018',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        suffixIcon: const Icon(Icons.qr_code_scanner_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Dropdown de Categoría
                    DropdownButtonFormField<int>(
                      value: selectedCategoryId,
                      decoration: InputDecoration(
                        labelText: 'Categoría *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.category_outlined),
                      ),
                      items: _categories.map((cat) {
                        return DropdownMenuItem<int>(
                          value: cat.id,
                          child: Text(cat.name),
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
                              labelText: 'P. Venta *',
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
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Stock Actual *',
                              hintText: '0',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: minStockController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Stock Mínimo',
                              hintText: '5',
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
                        final stock = int.tryParse(stockController.text.trim());

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
                        final minStock = int.tryParse(minStockController.text.trim()) ?? 5;
                        final barcode = barcodeController.text.trim();

                        await _inventoryRepository.addProduct(
                          name,
                          barcode.isEmpty ? null : barcode,
                          costPrice,
                          salePrice,
                          stock,
                          minStock,
                          selectedCategoryId,
                        );

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
                        'Guardar Producto',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
        final bool isLowStock = product.stock <= product.minStock;
        final categoryName = product.category.value?.name ?? 'Sin categoría';

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                    'S/ ${product.salePrice.toStringAsFixed(2)}  •  ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Stock: ${product.stock}',
                    style: TextStyle(
                      color: isLowStock ? Colors.redAccent : Colors.grey[800],
                      fontWeight: isLowStock ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                  if (isLowStock) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.redAccent),
                  ],
                  const SizedBox(width: 8),
                  Text(
                    '[$categoryName]',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Eliminar Producto',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Eliminar Producto'),
                    content: Text('¿Deseas eliminar "${product.name}"?'),
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
              },
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
