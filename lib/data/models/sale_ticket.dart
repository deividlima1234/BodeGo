/// Modelo de datos para un ítem dentro de un ticket de venta.
class SaleTicketItem {
  final int productId;
  final String name;
  final int quantity;
  final double unitPrice;
  final double subtotal;

  SaleTicketItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'name': name,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'subtotal': subtotal,
      };

  factory SaleTicketItem.fromJson(Map<String, dynamic> json) => SaleTicketItem(
        productId: json['productId'] as int? ?? 0,
        name: json['name'] as String? ?? 'Producto',
        quantity: json['quantity'] as int? ?? 1,
        unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
        subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      );
}

/// Modelo inmutable de Comprobante / Ticket de Venta emitido en el Punto de Venta.
class SaleTicket {
  final String id;
  final String ticketNumber;
  final DateTime date;
  final double total;
  final bool isCredit;
  final int? customerId;
  final String? customerName;
  final double? previousDebt;
  final double? newDebt;
  final String cashierName;
  final String businessName;
  final List<SaleTicketItem> items;

  SaleTicket({
    required this.id,
    required this.ticketNumber,
    required this.date,
    required this.total,
    required this.isCredit,
    this.customerId,
    this.customerName,
    this.previousDebt,
    this.newDebt,
    required this.cashierName,
    required this.businessName,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'ticketNumber': ticketNumber,
        'date': date.toIso8601String(),
        'total': total,
        'isCredit': isCredit,
        'customerId': customerId,
        'customerName': customerName,
        'previousDebt': previousDebt,
        'newDebt': newDebt,
        'cashierName': cashierName,
        'businessName': businessName,
        'items': items.map((i) => i.toJson()).toList(),
      };

  factory SaleTicket.fromJson(Map<String, dynamic> json) => SaleTicket(
        id: json['id'] as String,
        ticketNumber: json['ticketNumber'] as String? ?? 'TKT-0000',
        date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
        total: (json['total'] as num?)?.toDouble() ?? 0.0,
        isCredit: json['isCredit'] as bool? ?? false,
        customerId: json['customerId'] as int?,
        customerName: json['customerName'] as String?,
        previousDebt: (json['previousDebt'] as num?)?.toDouble(),
        newDebt: (json['newDebt'] as num?)?.toDouble(),
        cashierName: json['cashierName'] as String? ?? 'Cajero de Turno',
        businessName: json['businessName'] as String? ?? 'BodeGo',
        items: (json['items'] as List<dynamic>?)
                ?.map((item) => SaleTicketItem.fromJson(item as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

