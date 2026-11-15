import 'package:flutter/material.dart';
import 'package:bodego/data/local/isar/collections/category.dart';
import 'package:bodego/data/local/isar/collections/product.dart';
import 'package:bodego/data/repositories/category_repository.dart';
import 'package:bodego/data/repositories/product_repository.dart';
import 'package:bodego/presentation/widgets/modern_barcode_scanner.dart';

/// Diálogo para registrar o editar un producto en el inventario.
class ProductFormDialog extends StatefulWidget {
  final Product? productToEdit;
  final VoidCallback onSaved;

  const ProductFormDialog({
    super.key,
    this.productToEdit,
    required this.onSaved,
  });

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final ProductRepository _productRepository = ProductRepository();
  final CategoryRepository _categoryRepository = CategoryRepository();

  late TextEditingController _nameController;
  late TextEditingController _barcodeController;
  late TextEditingController _costPriceController;
  late TextEditingController _salePriceController;
  late TextEditingController _stockController;
  late TextEditingController _minStockController;

  List<Category> _categories = [];
  Category? _selectedCategory;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.productToEdit;
    _nameController = TextEditingController(text: p?.name ?? '');
    _barcodeController = TextEditingController(text: p?.barcode ?? '');
    _costPriceController = TextEditingController(text: p != null ? p.costPrice.toStringAsFixed(2) : '');
    _salePriceController = TextEditingController(text: p != null ? p.salePrice.toStringAsFixed(2) : '');
    _stockController = TextEditingController(text: p != null ? p.stock.toString() : '');
    _minStockController = TextEditingController(text: p != null ? p.minStock.toString() : '5');

    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _costPriceController.dispose();
    _salePriceController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final list = await _categoryRepository.getAllCategories();
    if (mounted) {
      setState(() {
        _categories = list;
        if (widget.productToEdit?.category.value != null) {
          _selectedCategory = list.firstWhere(
            (c) => c.id == widget.productToEdit!.category.value!.id,
            orElse: () => list.first,
          );
        } else if (_categories.isNotEmpty) {
          _selectedCategory = _categories.first;
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final isEditing = widget.productToEdit != null;
      final product = isEditing ? widget.productToEdit! : Product();

      product.name = _nameController.text.trim();
      product.barcode = _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim();
      product.costPrice = double.tryParse(_costPriceController.text.trim()) ?? 0.0;
      product.salePrice = double.tryParse(_salePriceController.text.trim()) ?? 0.0;
      product.stock = double.tryParse(_stockController.text.trim()) ?? 0.0;
      product.minStock = double.tryParse(_minStockController.text.trim()) ?? 5.0;

      await _productRepository.saveProduct(product, category: _selectedCategory);

      if (!mounted) return;
      widget.onSaved();
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar producto: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.productToEdit != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _isLoading
              ? const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                )
              : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isEditing ? Icons.edit_note_rounded : Icons.add_box_rounded,
                              color: theme.colorScheme.primary,
                              size: 28,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              isEditing ? 'Editar Producto' : 'Nuevo Producto',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Nombre del Producto
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: 'Nombre del Producto *',
                            hintText: 'Ej. Leche Gloria 400g',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                          ),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty) ? 'Requerido' : null,
                        ),
                        const SizedBox(height: 14),

                        // Código de Barras
                        TextFormField(
                          controller: _barcodeController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Código de Barras (Opcional)',
                            hintText: 'Ej. 7750151000103',
                            prefixIcon: const Icon(Icons.qr_code_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                Icons.qr_code_scanner_rounded,
                                color: theme.colorScheme.primary,
                              ),
                              tooltip: 'Escanear con Cámara',
                              onPressed: () async {
                                final scanned = await ModernBarcodeScanner.scanSingle(
                                  context,
                                  title: 'Escanear Código de Barras',
                                );
                                if (scanned != null && scanned.isNotEmpty) {
                                  setState(() {
                                    _barcodeController.text = scanned;
                                  });
                                }
                              },
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Categoría
                        if (_categories.isNotEmpty)
                          DropdownButtonFormField<Category>(
                            value: _selectedCategory,
                            decoration: InputDecoration(
                              labelText: 'Categoría',
                              prefixIcon: const Icon(Icons.category_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: theme.colorScheme.surface,
                            ),
                            items: _categories.map((cat) {
                              return DropdownMenuItem<Category>(
                                value: cat,
                                child: Text(cat.name),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedCategory = val;
                              });
                            },
                          ),
                        const SizedBox(height: 14),

                        // Fila Precios: Costo y Venta
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _costPriceController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'P. Compra',
                                  hintText: '0.00',
                                  prefixText: 'S/ ',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  filled: true,
                                  fillColor: theme.colorScheme.surface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _salePriceController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'P. Venta *',
                                  hintText: '0.00',
                                  prefixText: 'S/ ',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  filled: true,
                                  fillColor: theme.colorScheme.surface,
                                ),
                                validator: (val) =>
                                    (val == null || val.trim().isEmpty) ? 'Requerido' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Fila Stock: Actual y Mínimo
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _stockController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Stock Actual *',
                                  hintText: '0',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  filled: true,
                                  fillColor: theme.colorScheme.surface,
                                ),
                                validator: (val) =>
                                    (val == null || val.trim().isEmpty) ? 'Requerido' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _minStockController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Stock Mínimo',
                                  hintText: '5',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  filled: true,
                                  fillColor: theme.colorScheme.surface,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Botones de acción
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _isSaving ? null : _save,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text(isEditing ? 'Actualizar' : 'Guardar'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

