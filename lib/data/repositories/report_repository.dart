import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:bodego/data/local/isar/collections/customer.dart';
import 'package:bodego/data/repositories/customer_repository.dart';
import 'package:bodego/data/repositories/inventory_repository.dart';
import 'package:bodego/data/repositories/ticket_repository.dart';

/// Modelo de estadísticas de ventas de un producto específico.
class TopProductStat {
  final String name;
  final int quantity;
  final double revenue;

  TopProductStat({
    required this.name,
    required this.quantity,
    required this.revenue,
  });
}

/// Consolidado de métricas reales para el módulo de Reportes y Arqueo de Caja.
class ShiftReportData {
  final double initialCash;
  final double totalSales;
  final double cashSales;
  final double creditSales;
  final int transactionCount;
  final int itemsSoldCount;
  final double estimatedProfit;
  final double averageTicket;
  final double expectedCashInDrawer;
  final List<TopProductStat> topProducts;
  final double totalReceivable;
  final int debtorCount;
  final List<Customer> topDebtors;

  ShiftReportData({
    required this.initialCash,
    required this.totalSales,
    required this.cashSales,
    required this.creditSales,
    required this.transactionCount,
    required this.itemsSoldCount,
    required this.estimatedProfit,
    required this.averageTicket,
    required this.expectedCashInDrawer,
    required this.topProducts,
    required this.totalReceivable,
    required this.debtorCount,
    required this.topDebtors,
  });
}

/// Modelo del comprobante de Cierre de Caja (Ticket Z).
class ZReportTicket {
  final String businessName;
  final String cashierName;
  final DateTime closureDate;
  final double initialCash;
  final double cashSales;
  final double creditSales;
  final double totalSales;
  final int transactionCount;
  final int itemsSoldCount;
  final double expectedCash;
  final double countedCash;
  final double difference;

  ZReportTicket({
    required this.businessName,
    required this.cashierName,
    required this.closureDate,
    required this.initialCash,
    required this.cashSales,
    required this.creditSales,
    required this.totalSales,
    required this.transactionCount,
    required this.itemsSoldCount,
    required this.expectedCash,
    required this.countedCash,
    required this.difference,
  });
}

/// Repositorio que orquesta y computa las métricas reales del negocio para Reportes.
class ReportRepository {
  final TicketRepository _ticketRepository = TicketRepository();
  final CustomerRepository _customerRepository = CustomerRepository();
  final InventoryRepository _inventoryRepository = InventoryRepository();

  static const String _configFile = 'shift_config.json';

  Future<File> _getConfigFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_configFile');
  }

  /// Obtiene el fondo inicial configurado para la gaveta.
  Future<double> getInitialCash() async {
    try {
      final file = await _getConfigFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        return (json['initialCash'] as num?)?.toDouble() ?? 50.0;
      }
    } catch (_) {}
    return 50.0;
  }

  /// Actualiza y persiste el fondo inicial de apertura.
  Future<void> setInitialCash(double amount) async {
    final file = await _getConfigFile();
    final jsonString = jsonEncode({'initialCash': amount});
    await file.writeAsString(jsonString);
  }

  /// Computa el informe completo del turno y finanzas con datos 100% reales.
  Future<ShiftReportData> getShiftReport() async {
    final double initialCash = await getInitialCash();
    final tickets = await _ticketRepository.getTickets();
    final now = DateTime.now();

    // Filtramos tickets del día de hoy
    final todayTickets = tickets.where((t) =>
        t.date.year == now.year &&
        t.date.month == now.month &&
        t.date.day == now.day).toList();

    double totalSales = 0.0;
    double cashSales = 0.0;
    double creditSales = 0.0;
    int itemsSoldCount = 0;

    for (final t in todayTickets) {
      totalSales += t.total;
      if (t.isCredit) {
        creditSales += t.total;
      } else {
        cashSales += t.total;
      }
      for (final item in t.items) {
        itemsSoldCount += item.quantity;
      }
    }

    final int transactionCount = todayTickets.length;
    final double averageTicket =
        transactionCount > 0 ? (totalSales / transactionCount) : 0.0;
    final double expectedCashInDrawer = initialCash + cashSales;

    // Cálculo de ganancia neta real basada en costos de productos en Isar
    final products = await _inventoryRepository.getProducts();
    final Map<int, double> productCostMap = {for (var p in products) p.id: p.costPrice};
    final Map<String, double> productNameCostMap = {
      for (var p in products) p.name.trim().toLowerCase(): p.costPrice
    };

    double estimatedProfit = 0.0;
    final Map<String, TopProductStat> productSalesMap = {};

    for (final t in todayTickets) {
      for (final item in t.items) {
        final double cost = productCostMap[item.productId] ??
            productNameCostMap[item.name.trim().toLowerCase()] ??
            (item.unitPrice * 0.70); // Margen estimado del 30% como salvaguarda

        estimatedProfit += (item.unitPrice - cost) * item.quantity;

        // Acumular ventas por producto para el Top Ranking
        if (productSalesMap.containsKey(item.name)) {
          final current = productSalesMap[item.name]!;
          productSalesMap[item.name] = TopProductStat(
            name: item.name,
            quantity: current.quantity + item.quantity,
            revenue: current.revenue + item.subtotal,
          );
        } else {
          productSalesMap[item.name] = TopProductStat(
            name: item.name,
            quantity: item.quantity,
            revenue: item.subtotal,
          );
        }
      }
    }

    final topProducts = productSalesMap.values.toList()
      ..sort((a, b) => b.quantity.compareTo(a.quantity));

    // Métricas de fiados y clientes
    final customers = await _customerRepository.getCustomers();
    final double totalReceivable =
        customers.fold(0.0, (sum, c) => sum + c.currentDebt);
    final debtors = customers.where((c) => c.currentDebt > 0).toList()
      ..sort((a, b) => b.currentDebt.compareTo(a.currentDebt));
    final int debtorCount = debtors.length;
    final List<Customer> topDebtors = debtors.take(5).toList();

    return ShiftReportData(
      initialCash: initialCash,
      totalSales: totalSales,
      cashSales: cashSales,
      creditSales: creditSales,
      transactionCount: transactionCount,
      itemsSoldCount: itemsSoldCount,
      estimatedProfit: estimatedProfit,
      averageTicket: averageTicket,
      expectedCashInDrawer: expectedCashInDrawer,
      topProducts: topProducts.take(5).toList(),
      totalReceivable: totalReceivable,
      debtorCount: debtorCount,
      topDebtors: topDebtors,
    );
  }
}

