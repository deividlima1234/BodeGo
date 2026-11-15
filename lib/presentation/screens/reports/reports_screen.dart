import 'package:flutter/material.dart';
import 'package:bodego/data/repositories/app_settings_repository.dart';
import 'package:bodego/data/repositories/business_config_repository.dart';
import 'package:bodego/data/repositories/user_repository.dart';
import 'package:bodego/data/repositories/report_repository.dart';
import 'package:bodego/presentation/screens/pos/sales_history_screen.dart';
import 'package:bodego/presentation/widgets/z_report_receipt_widget.dart';

/// Pantalla del Módulo de Reportes, Arqueo de Caja y Rendimiento Financiero
/// organizada en 3 pestañas: Arqueo de Caja, Ventas & Utilidad, y Cuentas por Cobrar.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final AppSettingsRepository _settingsRepository = AppSettingsRepository();
  final UserRepository _userRepository = UserRepository();
  final ReportRepository _reportRepository = ReportRepository();

  String _cashierName = 'Cargando...';
  String _businessName = 'BodeGo';
  bool _isLoading = true;

  ShiftReportData? _reportData;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    final businessConfig = await BusinessConfigRepository().getConfig();
    final cashier = await _userRepository.getFirstCashier();
    final report = await _reportRepository.getShiftReport();

    if (mounted) {
      setState(() {
        _businessName = businessConfig.businessName.isNotEmpty
            ? businessConfig.businessName
            : 'BodeGo';
        _cashierName = cashier?.name ?? 'Cajero de Turno';
        _reportData = report;
        _isLoading = false;
      });
    }
  }

  /// Diálogo para modificar el Fondo Inicial de Apertura en la gaveta
  void _showEditInitialCashDialog() {
    if (_reportData == null) return;
    final controller = TextEditingController(
      text: _reportData!.initialCash.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text('Fondo Inicial de Caja'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dinero inicial colocado en la gaveta al abrir turno para dar vuelto:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Monto de Apertura (S/)',
                prefixText: 'S/ ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(controller.text.trim());
              if (val != null && val >= 0) {
                await _reportRepository.setInitialCash(val);
                Navigator.pop(ctx);
                _loadAllData();
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  /// Modal para realizar el Arqueo físico de dinero y Cierre Z
  void _showCloseShiftModal() {
    if (_reportData == null) return;
    final data = _reportData!;
    final countedCashController = TextEditingController();
    double countedCash = 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final difference = countedCash - data.expectedCashInDrawer;
            final hasEnteredCash = countedCashController.text.isNotEmpty;

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
                        const Row(
                          children: [
                            Icon(Icons.receipt_long_rounded, color: Colors.blueAccent),
                            SizedBox(width: 8),
                            Text(
                              'Arqueo y Cierre Z',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Text(
                      'Cajero: $_cashierName  •  Negocio: $_businessName',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 14),

                    // Resumen de saldo esperado en efectivo
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _buildSummaryRow('Fondo Inicial de Apertura:', 'S/ ${data.initialCash.toStringAsFixed(2)}'),
                          const SizedBox(height: 6),
                          _buildSummaryRow('Ventas Totales en Efectivo:', '+ S/ ${data.cashSales.toStringAsFixed(2)}'),
                          const Divider(height: 14),
                          _buildSummaryRow(
                            'Total Esperado en Gaveta:',
                            'S/ ${data.expectedCashInDrawer.toStringAsFixed(2)}',
                            isBold: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Entrada de dinero físico contado
                    TextField(
                      controller: countedCashController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Dinero Físico Contado en Gaveta (S/) *',
                        hintText: '0.00',
                        prefixText: 'S/ ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (val) {
                        setModalState(() {
                          countedCash = double.tryParse(val.trim()) ?? 0.0;
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // Indicador de diferencia / cuadre en tiempo real
                    if (hasEnteredCash) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: (difference.abs() < 0.01)
                              ? Colors.green.withOpacity(0.15)
                              : difference > 0
                                  ? Colors.blue.withOpacity(0.15)
                                  : Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              (difference.abs() < 0.01)
                                  ? '¡Cuadre Exacto!'
                                  : difference > 0
                                      ? 'Sobrante en Caja:'
                                      : 'Faltante en Caja:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: (difference.abs() < 0.01)
                                    ? Colors.green[800]
                                    : difference > 0
                                        ? Colors.blue[800]
                                        : Colors.red[800],
                              ),
                            ),
                            Text(
                              'S/ ${difference.abs().toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: (difference.abs() < 0.01)
                                    ? Colors.green[800]
                                    : difference > 0
                                        ? Colors.blue[800]
                                        : Colors.red[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        // Creamos el modelo oficial del Cierre Z y abrimos el comprobante térmico
                        final zTicket = ZReportTicket(
                          businessName: _businessName,
                          cashierName: _cashierName,
                          closureDate: DateTime.now(),
                          initialCash: data.initialCash,
                          cashSales: data.cashSales,
                          creditSales: data.creditSales,
                          totalSales: data.totalSales,
                          transactionCount: data.transactionCount,
                          itemsSoldCount: data.itemsSoldCount,
                          expectedCash: data.expectedCashInDrawer,
                          countedCash: countedCash,
                          difference: difference,
                        );

                        ZReportModal.show(context, zTicket);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.assignment_turned_in_rounded, color: Colors.white),
                      label: const Text(
                        'Generar Ticket Z y Cerrar Turno',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.w600),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final data = _reportData!;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Arqueo y Reportes'),
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.receipt_long_rounded),
              tooltip: 'Historial de Tickets',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SalesHistoryScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Actualizar Datos',
              onPressed: _loadAllData,
            ),
          ],
          bottom: TabBar(
            isScrollable: false,
            indicatorColor: theme.colorScheme.primary,
            indicatorWeight: 3,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [
              Tab(icon: Icon(Icons.point_of_sale_rounded, size: 20), text: 'Arqueo'),
              Tab(icon: Icon(Icons.trending_up_rounded, size: 20), text: 'Ventas'),
              Tab(icon: Icon(Icons.handshake_rounded, size: 20), text: 'Fiados'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              // ==========================================
              // PESTAÑA 1: ARQUEO DE CAJA Y CIERRE Z
              // ==========================================
              _buildCashDrawerTab(context, data),

              // ==========================================
              // PESTAÑA 2: VENTAS Y GANANCIA NETA REAL
              // ==========================================
              _buildFinancialSalesTab(context, data),

              // ==========================================
              // PESTAÑA 3: CUENTAS POR COBRAR (FIADOS)
              // ==========================================
              _buildCreditReceivablesTab(context, data),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // VISTA PESTAÑA 1: ARQUEO Y CIERRE Z
  // ==========================================
  Widget _buildCashDrawerTab(BuildContext context, ShiftReportData data) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // Cabecera informativa del turno actual
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withOpacity(0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        _businessName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.greenAccent),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: Colors.greenAccent, size: 8),
                        SizedBox(width: 4),
                        Text(
                          'Caja Abierta',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Cajero a cargo: $_cashierName',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Balance de Efectivo en Gaveta
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Balance en Gaveta de Efectivo',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: _showEditInitialCashDialog,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Fondo Inicial'),
            ),
          ],
        ),
        const SizedBox(height: 6),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildSummaryRow(
                'Fondo Inicial de Apertura:',
                'S/ ${data.initialCash.toStringAsFixed(2)}',
              ),
              const SizedBox(height: 8),
              _buildSummaryRow(
                'Ingresos Efectivo (Ventas de Hoy):',
                '+ S/ ${data.cashSales.toStringAsFixed(2)}',
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Esperado en Gaveta:',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'S/ ${data.expectedCashInDrawer.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Tarjetas resumen rápidas de tickets
        Row(
          children: [
            Expanded(
              child: _buildSimpleCard(
                title: 'Tickets Cobrados',
                value: '${data.transactionCount} emitidos',
                icon: Icons.receipt_rounded,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSimpleCard(
                title: 'Despachados',
                value: '${data.itemsSoldCount % 1 == 0 ? data.itemsSoldCount.toInt() : data.itemsSoldCount.toStringAsFixed(2)} ítems',
                icon: Icons.inventory_2_rounded,
                color: Colors.purpleAccent,
              ),
            ),
          ],
        ),

        const SizedBox(height: 22),

        // Botón Cierre de Turno y Arqueo Z
        ElevatedButton.icon(
          onPressed: _showCloseShiftModal,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.assignment_turned_in_rounded, size: 22),
          label: const Text(
            'Realizar Arqueo y Cierre Z',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // VISTA PESTAÑA 2: VENTAS & GANANCIAS REALES
  // ==========================================
  Widget _buildFinancialSalesTab(BuildContext context, ShiftReportData data) {
    final theme = Theme.of(context);
    final double marginPercent =
        data.totalSales > 0 ? (data.estimatedProfit / data.totalSales) * 100 : 0.0;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        Text(
          'Rendimiento y Ganancias de Hoy',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        // KPIs Financieros
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                context,
                title: 'Ventas Totales Hoy',
                value: 'S/ ${data.totalSales.toStringAsFixed(2)}',
                icon: Icons.payments_rounded,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKpiCard(
                context,
                title: 'Ganancia Neta Real',
                value: 'S/ ${data.estimatedProfit.toStringAsFixed(2)}',
                icon: Icons.trending_up_rounded,
                color: Colors.green,
                subtitle: '${marginPercent.toStringAsFixed(1)}% margen est.',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                context,
                title: 'Ticket Promedio',
                value: 'S/ ${data.averageTicket.toStringAsFixed(2)}',
                icon: Icons.analytics_outlined,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKpiCard(
                context,
                title: 'Ventas Contado',
                value: 'S/ ${data.cashSales.toStringAsFixed(2)}',
                icon: Icons.account_balance_wallet_rounded,
                color: Colors.teal,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Top 5 Productos más Vendidos
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Top 5 Productos Estrella',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              'Rotación de hoy',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (data.topProducts.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.withOpacity(0.15)),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.insights_rounded, size: 38, color: Colors.grey.withOpacity(0.4)),
                  const SizedBox(height: 8),
                  const Text(
                    'Sin ventas registradas hoy',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Los productos que vendas en Caja se posicionarán en este ranking automáticamente.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: data.topProducts.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final product = data.topProducts[index];
                final medals = ['🥇', '🥈', '🥉', '4°', '5°'];

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: index < 3
                        ? Colors.amber.withOpacity(0.18)
                        : Colors.grey.withOpacity(0.15),
                    child: Text(
                      medals[index],
                      style: TextStyle(
                        fontSize: index < 3 ? 16 : 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${product.quantity % 1 == 0 ? product.quantity.toInt() : product.quantity.toStringAsFixed(2)} despachados',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: Text(
                    'S/ ${product.revenue.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ==========================================
  // VISTA PESTAÑA 3: CUENTAS POR COBRAR (FIADOS)
  // ==========================================
  Widget _buildCreditReceivablesTab(BuildContext context, ShiftReportData data) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // Tarjeta destacada de Deuda Total en la Calle
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total por Cobrar (Deuda en la Calle):',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.redAccent,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${data.debtorCount} deudores',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'S/ ${data.totalReceivable.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Fiados otorgados hoy: S/ ${data.creditSales.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Clientes con Mayor Deuda',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Text(
              'Top 5 pendientes',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (data.topDebtors.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text(
                '¡Excelente! No tienes cuentas por cobrar pendientes.',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: data.topDebtors.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final customer = data.topDebtors[index];
                final availableCredit =
                    (customer.creditLimit - customer.currentDebt).clamp(0.0, double.infinity);

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.withOpacity(0.18),
                    child: Text(
                      customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'C',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[900],
                      ),
                    ),
                  ),
                  title: Text(
                    customer.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    'Límite: S/ ${customer.creditLimit.toStringAsFixed(2)}  •  Disp: S/ ${availableCredit.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  trailing: Text(
                    'S/ ${customer.currentDebt.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildKpiCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSimpleCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
