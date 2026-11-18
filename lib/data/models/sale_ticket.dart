/// Modelo de datos para un ítem dentro de un ticket de venta.
class SaleTicketItem {
  final int productId;
  final String name;
  final double quantity;
  final double unitPrice;
  final double subtotal;
  final String unit;

  SaleTicketItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.unit = 'und',
  });

  /// Formato legible de la cantidad en tickets
  String get formattedQuantity {
    if (unit != 'und') {
      if (quantity % 1 == 0) {
        return '${quantity.toInt()} $unit';
      }
      return '${quantity.toStringAsFixed(unit == 'kg' ? 3 : 2)} $unit';
    }
    return '${quantity.toInt()} $unit';
  }

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'name': name,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'subtotal': subtotal,
        'unit': unit,
      };

  factory SaleTicketItem.fromJson(Map<String, dynamic> json) => SaleTicketItem(
        productId: json['productId'] as int? ?? 0,
        name: json['name'] as String? ?? 'Producto',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
        unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
        subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
        unit: json['unit'] as String? ?? 'und',
      );
}

/// Modelo inmutable de Comprobante / Ticket de Venta emitido en el Punto de Venta.
class SaleTicket {
  final String id;
  final String ticketNumber;
  final DateTime date;
  final double subtotal;
  final double discount;
  final double total;
  final bool isCredit;
  final int? customerId;
  final String? customerName;
  final double? previousDebt;
  final double? newDebt;
  final String cashierName;
  final String businessName;
  final List<SaleTicketItem> items;
  final bool isSynced;

  SaleTicket({
    required this.id,
    required this.ticketNumber,
    required this.date,
    double? subtotal,
    this.discount = 0.0,
    required this.total,
    required this.isCredit,
    this.customerId,
    this.customerName,
    this.previousDebt,
    this.newDebt,
    required this.cashierName,
    required this.businessName,
    required this.items,
    this.isSynced = false,
  }) : subtotal = subtotal ?? (total + discount);

  SaleTicket copyWith({
    String? id,
    String? ticketNumber,
    DateTime? date,
    double? subtotal,
    double? discount,
    double? total,
    bool? isCredit,
    int? customerId,
    String? customerName,
    double? previousDebt,
    double? newDebt,
    String? cashierName,
    String? businessName,
    List<SaleTicketItem>? items,
    bool? isSynced,
  }) {
    return SaleTicket(
      id: id ?? this.id,
      ticketNumber: ticketNumber ?? this.ticketNumber,
      date: date ?? this.date,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      total: total ?? this.total,
      isCredit: isCredit ?? this.isCredit,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      previousDebt: previousDebt ?? this.previousDebt,
      newDebt: newDebt ?? this.newDebt,
      cashierName: cashierName ?? this.cashierName,
      businessName: businessName ?? this.businessName,
      items: items ?? this.items,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ticketNumber': ticketNumber,
        'date': date.toIso8601String(),
        'subtotal': subtotal,
        'discount': discount,
        'total': total,
        'isCredit': isCredit,
        'customerId': customerId,
        'customerName': customerName,
        'previousDebt': previousDebt,
        'newDebt': newDebt,
        'cashierName': cashierName,
        'businessName': businessName,
        'items': items.map((i) => i.toJson()).toList(),
        'isSynced': isSynced,
      };

  factory SaleTicket.fromJson(Map<String, dynamic> json) {
    final discount = (json['discount'] as num?)?.toDouble() ?? 0.0;
    final total = (json['total'] as num?)?.toDouble() ?? 0.0;
    final subtotal = (json['subtotal'] as num?)?.toDouble() ?? (total + discount);

    return SaleTicket(
      id: json['id'] as String,
      ticketNumber: json['ticketNumber'] as String? ?? 'TKT-0000',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      subtotal: subtotal,
      discount: discount,
      total: total,
      isCredit: json['isCredit'] as bool? ?? false,
      customerId: json['customerId'] as int?,
      customerName: json['customerName'] as String?,
      previousDebt: (json['previousDebt'] as num?)?.toDouble(),
      newDebt: (json['newDebt'] as num?)?.toDouble(),
      cashierName: json['cashierName'] as String? ?? 'Cajero de Turno',
      businessName: json['businessName'] as String? ?? 'BodeGo',
      isSynced: json['isSynced'] as bool? ?? true,
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => SaleTicketItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

