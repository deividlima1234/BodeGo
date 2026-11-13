import 'package:flutter/material.dart';
import 'package:bodego/data/local/isar/collections/customer.dart';
import 'package:bodego/data/repositories/customer_repository.dart';

/// Modal interactivo para seleccionar o crear un cliente al momento de fiar en Caja.
class CustomerPickerModal extends StatefulWidget {
  final Customer? currentSelected;

  const CustomerPickerModal({
    super.key,
    this.currentSelected,
  });

  /// Muestra el modal y retorna el [Customer] seleccionado o `null` si se elige "Público General".
  static Future<Customer?> show(
    BuildContext context, {
    Customer? currentSelected,
  }) {
    return showModalBottomSheet<Customer?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CustomerPickerModal(currentSelected: currentSelected),
    );
  }

  @override
  State<CustomerPickerModal> createState() => _CustomerPickerModalState();
}

class _CustomerPickerModalState extends State<CustomerPickerModal> {
  final CustomerRepository _customerRepository = CustomerRepository();
  final TextEditingController _searchController = TextEditingController();

  List<Customer> _allCustomers = [];
  List<Customer> _filteredCustomers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    final customers = await _customerRepository.getCustomers();

    if (mounted) {
      setState(() {
        _allCustomers = customers;
        _isLoading = false;
        _applyFilter();
      });
    }
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filteredCustomers = _allCustomers;
    } else {
      final q = _searchQuery.toLowerCase();
      _filteredCustomers = _allCustomers.where((c) {
        final matchesName = c.name.toLowerCase().contains(q);
        final matchesPhone = c.phone?.toLowerCase().contains(q) ?? false;
        return matchesName || matchesPhone;
      }).toList();
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.trim();
      _applyFilter();
    });
  }

  /// Modal rápido para registrar un cliente en caliente si no existe aún en la libreta.
  void _showQuickAddCustomerDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final limitCtrl = TextEditingController(text: '100.00');

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.person_add_rounded, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Text('Registrar Cliente'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Nombre y Apellido *',
                  hintText: 'Ej. Don Lucho',
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Teléfono / WhatsApp',
                  hintText: '987654321',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: limitCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Límite de Crédito (S/)',
                  prefixText: 'S/ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final limit = double.tryParse(limitCtrl.text.trim()) ?? 100.0;

              await _customerRepository.addCustomer(
                name,
                phoneCtrl.text.trim(),
                null,
                limit,
              );

              if (mounted) {
                Navigator.pop(dialogCtx);
                // Recargamos clientes y seleccionamos al recién creado
                final updated = await _customerRepository.getCustomers();
                final created = updated.firstWhere(
                  (c) => c.name.toLowerCase() == name.toLowerCase(),
                  orElse: () => updated.last,
                );
                if (mounted) {
                  Navigator.pop(context, created);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Guardar y Seleccionar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle superior
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Encabezado
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people_alt_rounded, color: Colors.orange, size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'Vincular Cliente (Fiado)',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(context, widget.currentSelected),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Buscador de clientes
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre o teléfono...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.person_add_rounded, color: Colors.orange),
                  tooltip: 'Registrar nuevo cliente',
                  onPressed: _showQuickAddCustomerDialog,
                ),
              ],
            ),
          ),

          // Opción 1: Público General (Volver a contado)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Material(
              color: widget.currentSelected == null
                  ? theme.colorScheme.primary.withOpacity(0.12)
                  : theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.pop(context, null), // null = Público general
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: widget.currentSelected == null
                            ? theme.colorScheme.primary
                            : Colors.grey.withOpacity(0.2),
                        child: Icon(
                          Icons.storefront_rounded,
                          size: 18,
                          color: widget.currentSelected == null ? Colors.white : Colors.grey[700],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Público General (Venta al Contado)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: widget.currentSelected == null
                                    ? theme.colorScheme.primary
                                    : null,
                              ),
                            ),
                            const Text(
                              'Sin registro de deuda • Cobro inmediato',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      if (widget.currentSelected == null)
                        Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: Row(
              children: [
                Text(
                  'O SELECCIONA UN CLIENTE CON CUENTA:',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // Lista de Clientes
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCustomers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.person_search_rounded, size: 40, color: Colors.grey),
                            const SizedBox(height: 8),
                            const Text(
                              'No se encontraron clientes',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            TextButton.icon(
                              onPressed: _showQuickAddCustomerDialog,
                              icon: const Icon(Icons.person_add_rounded, size: 16),
                              label: const Text('Registrar nuevo cliente'),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: _filteredCustomers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final customer = _filteredCustomers[index];
                          final isSelected = widget.currentSelected?.id == customer.id;
                          final availableCredit =
                              (customer.creditLimit - customer.currentDebt).clamp(0.0, double.infinity);
                          final bool isNearLimit = customer.currentDebt >= customer.creditLimit;

                          return Material(
                            color: isSelected
                                ? Colors.orange.withOpacity(0.12)
                                : theme.scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => Navigator.pop(context, customer),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: isSelected
                                          ? Colors.orange
                                          : Colors.orange.withOpacity(0.15),
                                      child: Text(
                                        customer.name.isNotEmpty
                                            ? customer.name[0].toUpperCase()
                                            : 'C',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isSelected ? Colors.white : Colors.orange[800],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            customer.name,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Text(
                                                'Debe: S/ ${customer.currentDebt.toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: customer.currentDebt > 0
                                                      ? Colors.redAccent
                                                      : Colors.green,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '• Disp: S/ ${availableCredit.toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isNearLimit
                                                      ? Colors.redAccent
                                                      : Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(Icons.check_circle_rounded, color: Colors.orange, size: 20)
                                    else
                                      const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

