import 'package:flutter/material.dart';

/// Teclado numérico reutilizable táctil estilo POS de mostrador.
class NumericPad extends StatelessWidget {
  final void Function(String) onNumberSelected;
  final VoidCallback onDelete;

  const NumericPad({
    super.key,
    required this.onNumberSelected,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRow(context, ['1', '2', '3']),
        const SizedBox(height: 12),
        _buildRow(context, ['4', '5', '6']),
        const SizedBox(height: 12),
        _buildRow(context, ['7', '8', '9']),
        const SizedBox(height: 12),
        _buildBottomRow(context),
      ],
    );
  }

  Widget _buildRow(BuildContext context, List<String> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers.map((n) => _buildNumberButton(context, n)).toList(),
    );
  }

  Widget _buildBottomRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Espacio vacío para equilibrar el grid 3x4
        const SizedBox(width: 72, height: 72),
        _buildNumberButton(context, '0'),
        _buildDeleteButton(context),
      ],
    );
  }

  Widget _buildNumberButton(BuildContext context, String number) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => onNumberSelected(number),
        splashColor: theme.colorScheme.primary.withOpacity(0.2),
        child: SizedBox(
          width: 72,
          height: 72,
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onDelete,
        splashColor: theme.colorScheme.primary.withOpacity(0.2),
        child: SizedBox(
          width: 72,
          height: 72,
          child: Center(
            child: Icon(
              Icons.backspace_outlined,
              size: 26,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

