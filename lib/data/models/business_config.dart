import 'package:flutter/material.dart';

/// Modelo de Configuración de Identidad y Ticket de la Bodega.
class BusinessConfig {
  final String businessName;
  final String ruc;
  final String address;
  final String phone;
  final String logoType; // 'preset' o 'file'
  final String logoValue; // Nombre del preset o ruta de archivo local
  final String ticketFooterMessage;
  final int paperWidthMm; // 58 o 80
  final bool showRucOnTicket;
  final bool showAddressOnTicket;
  final bool showPhoneOnTicket;
  final bool showBarcodeOnTicket;
  final bool showEddamCoreBranding;

  const BusinessConfig({
    this.businessName = '',
    this.ruc = '',
    this.address = '',
    this.phone = '',
    this.logoType = 'preset',
    this.logoValue = 'storefront',
    this.ticketFooterMessage = '¡GRACIAS POR SU COMPRA!\nVUELVA PRONTO',
    this.paperWidthMm = 58,
    this.showRucOnTicket = true,
    this.showAddressOnTicket = true,
    this.showPhoneOnTicket = true,
    this.showBarcodeOnTicket = true,
    this.showEddamCoreBranding = true,
  });

  /// Lista de iconos predeterminados de alta nitidez para comprobantes térmicos
  static const Map<String, ({IconData icon, String label})> presets = {
    'storefront': (icon: Icons.storefront_rounded, label: 'Bodega Clásica'),
    'shopping_cart': (icon: Icons.shopping_cart_rounded, label: 'Minimarket'),
    'local_grocery': (icon: Icons.local_grocery_store_rounded, label: 'Abarrotes'),
    'shopping_bag': (icon: Icons.shopping_bag_rounded, label: 'Tienda'),
    'fastfood': (icon: Icons.fastfood_rounded, label: 'Snacks y Bebidas'),
    'eco': (icon: Icons.eco_rounded, label: 'Frutas y Verduras'),
    'liquor': (icon: Icons.liquor_rounded, label: 'Licores y Bebidas'),
    'cake': (icon: Icons.cake_rounded, label: 'Panadería y Dulces'),
  };

  BusinessConfig copyWith({
    String? businessName,
    String? ruc,
    String? address,
    String? phone,
    String? logoType,
    String? logoValue,
    String? ticketFooterMessage,
    int? paperWidthMm,
    bool? showRucOnTicket,
    bool? showAddressOnTicket,
    bool? showPhoneOnTicket,
    bool? showBarcodeOnTicket,
    bool? showEddamCoreBranding,
  }) {
    return BusinessConfig(
      businessName: businessName ?? this.businessName,
      ruc: ruc ?? this.ruc,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      logoType: logoType ?? this.logoType,
      logoValue: logoValue ?? this.logoValue,
      ticketFooterMessage: ticketFooterMessage ?? this.ticketFooterMessage,
      paperWidthMm: paperWidthMm ?? this.paperWidthMm,
      showRucOnTicket: showRucOnTicket ?? this.showRucOnTicket,
      showAddressOnTicket: showAddressOnTicket ?? this.showAddressOnTicket,
      showPhoneOnTicket: showPhoneOnTicket ?? this.showPhoneOnTicket,
      showBarcodeOnTicket: showBarcodeOnTicket ?? this.showBarcodeOnTicket,
      showEddamCoreBranding: showEddamCoreBranding ?? this.showEddamCoreBranding,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'businessName': businessName,
      'ruc': ruc,
      'address': address,
      'phone': phone,
      'logoType': logoType,
      'logoValue': logoValue,
      'ticketFooterMessage': ticketFooterMessage,
      'paperWidthMm': paperWidthMm,
      'showRucOnTicket': showRucOnTicket,
      'showAddressOnTicket': showAddressOnTicket,
      'showPhoneOnTicket': showPhoneOnTicket,
      'showBarcodeOnTicket': showBarcodeOnTicket,
      'showEddamCoreBranding': showEddamCoreBranding,
    };
  }

  factory BusinessConfig.fromJson(Map<String, dynamic> json) {
    return BusinessConfig(
      businessName: json['businessName'] as String? ?? '',
      ruc: json['ruc'] as String? ?? '',
      address: json['address'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      logoType: json['logoType'] as String? ?? 'preset',
      logoValue: json['logoValue'] as String? ?? 'storefront',
      ticketFooterMessage: json['ticketFooterMessage'] as String? ??
          '¡GRACIAS POR SU COMPRA!\nVUELVA PRONTO',
      paperWidthMm: json['paperWidthMm'] as int? ?? 58,
      showRucOnTicket: json['showRucOnTicket'] as bool? ?? true,
      showAddressOnTicket: json['showAddressOnTicket'] as bool? ?? true,
      showPhoneOnTicket: json['showPhoneOnTicket'] as bool? ?? true,
      showBarcodeOnTicket: json['showBarcodeOnTicket'] as bool? ?? true,
      showEddamCoreBranding: json['showEddamCoreBranding'] as bool? ?? true,
    );
  }
}

