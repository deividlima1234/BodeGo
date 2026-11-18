import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Modal táctil para aplicar descuentos a la venta actual por monto fijo (S/) o porcentaje (%).
class DiscountDialog extends StatefulWidget {
  final double currentSubtotal;
  final double initialDiscount;

  const DiscountDialog({
    super.key,
    required this.currentSubtotal,
    this.initialDiscount = 0.0,
  });

  /// Abre el diálogo y retorna el monto final de descuento en Soles (S/), o null si se cancela.
  static Future<double?> show(
    BuildContext context, {
    required double currentSubtotal,
    double initialDiscount = 0.0,
  }) {
    return showDialog<double>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DiscountDialog(
        currentSubtotal: currentSubtotal,
        initialDiscount: initialDiscount,
      ),
    );
  }

  @override
  State<DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends State<DiscountDialog> {
  // 0 = Monto en Soles (S/), 1 = Porcentaje (%)
  int _selectedMode = 0;
  late TextEditingController _inputController;

  final List<double> _quickAmounts = [0.50, 1.00, 2.00, 5.00];
  final List<int> _quickPercentages = [5, 10, 15, 20];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDiscount;
    if (initial > 0) {
      _inputController = TextEditingController(
        text: initial % 1 == 0 ? initial.toInt().toString() : initial.toStringAsFixed(2),
      );
    } else {
      _inputController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  /// Calcula el monto de descuento efectivo en Soles
  double get _calculatedDiscount {
    final text = _inputController.text.trim();
    final val = double.tryParse(text) ?? 0.0;
    if (val <= 0) return 0.0;

    if (_selectedMode == 0) {
      // Monto fijo en Soles
      return val > widget.currentSubtotal ? widget.currentSubtotal : val;
    } else {
      // Porcentaje (%)
      final pct = val > 100 ? 100.0 : val;
      return (widget.currentSubtotal * (pct / 100.0));
    }
  }

  /// Calcula el total resultante a pagar
  double get _resultTotal {
    final disc = _calculatedDiscount;
    final total = widget.currentSubtotal - disc;
    return total < 0 ? 0.0 : total;
  }

  void _applyQuickValue(double val, bool isPercentage) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedMode = isPercentage ? 1 : 0;
      _inputController.text = val % 1 == 0 ? val.toInt().toString() : val.toStringAsFixed(2);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final discountAmount = _calculatedDiscount;
    final finalTotal = _resultTotal;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E2235) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Cabecera
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.local_offer_rounded,
                          color: Colors.green,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Descuento al Cliente',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 2. Selector de Modo: Soles (S/) vs Porcentaje (%)
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedMode = 0;
                            _inputController.clear();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _selectedMode == 0
                                ? (isDark ? const Color(0xFF2C324B) : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: _selectedMode == 0
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'En Soles (S/)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _selectedMode == 0 ? FontWeight.bold : FontWeight.w500,
                              color: _selectedMode == 0
                                  ? theme.colorScheme.primary
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedMode = 1;
                            _inputController.clear();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _selectedMode == 1
                                ? (isDark ? const Color(0xFF2C324B) : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: _selectedMode == 1
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'En Porcentaje (%)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _selectedMode == 1 ? FontWeight.bold : FontWeight.w500,
                              color: _selectedMode == 1
                                  ? theme.colorScheme.primary
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 3. Campo de entrada numérico
              TextField(
                controller: _inputController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
                decoration: InputDecoration(
                  prefixText: _selectedMode == 0 ? 'S/ ' : '',
                  suffixText: _selectedMode == 1 ? ' %' : '',
                  prefixStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey),
                  suffixStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey),
                  hintText: '0.00',
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  filled: true,
                  fillColor: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8F9FE),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: theme.colorScheme.primary.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 12),

              // 4. Chips rápidos de sugerencia
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: _selectedMode == 0
                    ? _quickAmounts.map((amt) {
                        final isSelected = _inputController.text.trim() == amt.toStringAsFixed(2) ||
                            _inputController.text.trim() == amt.toInt().toString();
                        return ActionChip(
                          label: Text('S/ ${amt.toStringAsFixed(amt % 1 == 0 ? 0 : 2)}'),
                          backgroundColor: isSelected
                              ? theme.colorScheme.primary.withOpacity(0.15)
                              : isDark
                                  ? Colors.white.withOpacity(0.06)
                                  : Colors.grey[100],
                          side: BorderSide(
                            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                          ),
                          onPressed: () => _applyQuickValue(amt, false),
                        );
                      }).toList()
                    : _quickPercentages.map((pct) {
                        final isSelected = _inputController.text.trim() == pct.toString();
                        return ActionChip(
                          label: Text('$pct%'),
                          backgroundColor: isSelected
                              ? theme.colorScheme.primary.withOpacity(0.15)
                              : isDark
                                  ? Colors.white.withOpacity(0.06)
                                  : Colors.grey[100],
                          side: BorderSide(
                            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                          ),
                          onPressed: () => _applyQuickValue(pct.toDouble(), true),
                        );
                      }).toList(),
              ),

              const SizedBox(height: 16),

              // 5. Resumen del cálculo en vivo
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withOpacity(0.2) : const Color(0xFFF4F6FC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Subtotal:',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          'S/ ${widget.currentSubtotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Descuento:',
                          style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '- S/ ${discountAmount.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Nuevo Total:',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'S/ ${finalTotal.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 6. Botones de Acción (Quitar / Aplicar)
              Row(
                children: [
                  if (widget.initialDiscount > 0)
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(context, 0.0);
                        },
                        child: const Text('Quitar', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  if (widget.initialDiscount > 0) const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        Navigator.pop(context, discountAmount);
                      },
                      child: Text(
                        discountAmount > 0
                            ? 'Aplicar (- S/ ${discountAmount.toStringAsFixed(2)})'
                            : 'Cerrar sin Descuento',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
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
}

