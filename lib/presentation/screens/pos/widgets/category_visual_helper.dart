import 'package:flutter/material.dart';
import 'package:bodego/data/local/isar/collections/category.dart';

/// Configuración visual de una categoría o producto para la UI de BodeGo.
class CategoryVisualConfig {
  /// Color primario distintivo (usado en badges, bordes e iconos).
  final Color primaryColor;

  /// Fondo suave y translúcido para el contenedor central.
  final Color containerBackground;

  /// Icono temático vectorial representativo de la categoría o producto.
  final IconData icon;

  /// Nombre de la categoría a mostrar en el pill superior.
  final String categoryName;

  const CategoryVisualConfig({
    required this.primaryColor,
    required this.containerBackground,
    required this.icon,
    required this.categoryName,
  });
}

/// Helper para inferir y estilizar categorías y productos con una identidad visual moderna.
class CategoryVisualHelper {
  CategoryVisualHelper._();

  /// Resuelve la configuración visual óptima combinando datos de categoría y palabras clave del producto.
  static CategoryVisualConfig resolve({
    Category? category,
    required String productName,
    bool allowsDecimals = false,
    bool isDark = false,
  }) {
    final catName = category?.name.trim() ?? '';
    final prodNameLower = productName.toLowerCase();
    final catNameLower = catName.toLowerCase();

    // 1. Identificar iconografía y color temático por coincidencias semánticas
    final (IconData icon, Color defaultColor, String defaultLabel) = _matchVisualAttributes(
      catName,
      catNameLower,
      prodNameLower,
      allowsDecimals,
    );

    // 2. Respetar el color personalizado de la BD si la categoría tiene hexColor válido
    Color finalPrimary = defaultColor;
    if (category?.hexColor != null && category!.hexColor!.isNotEmpty) {
      final parsed = _parseHexColor(category.hexColor);
      if (parsed != null) {
        finalPrimary = parsed;
      }
    }

    // 3. Determinar el fondo translúcido del contenedor central según el tema
    final containerBg = isDark
        ? finalPrimary.withOpacity(0.18)
        : finalPrimary.withOpacity(0.09);

    final displayLabel = catName.isNotEmpty ? catName : defaultLabel;

    return CategoryVisualConfig(
      primaryColor: finalPrimary,
      containerBackground: containerBg,
      icon: icon,
      categoryName: displayLabel,
    );
  }

  /// Mapeo semántico de categorías y palabras clave a IconData y Color.
  static (IconData, Color, String) _matchVisualAttributes(
    String catOriginalName,
    String catLower,
    String prodLower,
    bool allowsDecimals,
  ) {
    // Abarrotes / Granos / Balanza
    if (catLower.contains('abarrote') ||
        prodLower.contains('arroz') ||
        prodLower.contains('azucar') ||
        prodLower.contains('azúcar') ||
        prodLower.contains('fideo') ||
        prodLower.contains('harina') ||
        prodLower.contains('aceite') ||
        prodLower.contains('avena') ||
        prodLower.contains('sal ') ||
        prodLower.contains('lenteja') ||
        prodLower.contains('menestra') ||
        prodLower.contains('atun') ||
        prodLower.contains('atún') ||
        prodLower.contains('conserva')) {
      return (
        allowsDecimals ? Icons.scale_rounded : Icons.shopping_basket_rounded,
        const Color(0xFF3B82F6), // Azul Royal
        'Abarrotes',
      );
    }

    // Bebidas / Refrescos / Aguas
    if (catLower.contains('bebida') ||
        catLower.contains('refresco') ||
        prodLower.contains('gaseosa') ||
        prodLower.contains('agua') ||
        prodLower.contains('inka') ||
        prodLower.contains('coca') ||
        prodLower.contains('fanta') ||
        prodLower.contains('sprite') ||
        prodLower.contains('jugo') ||
        prodLower.contains('cifrut') ||
        prodLower.contains('pulp') ||
        prodLower.contains('frugos') ||
        prodLower.contains('chicha') ||
        prodLower.contains('rehidratante') ||
        prodLower.contains('powerade') ||
        prodLower.contains('gatorade') ||
        prodLower.contains('monster') ||
        prodLower.contains('red bull')) {
      return (
        Icons.local_drink_rounded,
        const Color(0xFF00B4D8), // Cyan / Turquesa vibrante
        'Bebidas',
      );
    }

    // Lácteos & Huevos
    if (catLower.contains('lacteo') ||
        catLower.contains('lácteo') ||
        prodLower.contains('leche') ||
        prodLower.contains('yogurt') ||
        prodLower.contains('queso') ||
        prodLower.contains('mantequilla') ||
        prodLower.contains('margarina') ||
        prodLower.contains('gloria') ||
        prodLower.contains('pura vida') ||
        prodLower.contains('laive') ||
        prodLower.contains('huevo')) {
      return (
        Icons.breakfast_dining_rounded,
        const Color(0xFFF59E0B), // Ámbar cálido / Dorado
        'Lácteos',
      );
    }

    // Snacks & Golosinas / Galletas
    if (catLower.contains('snack') ||
        catLower.contains('golosina') ||
        catLower.contains('dulce') ||
        prodLower.contains('galleta') ||
        prodLower.contains('oreo') ||
        prodLower.contains('chocolate') ||
        prodLower.contains('sublime') ||
        prodLower.contains('triangulo') ||
        prodLower.contains('wafer') ||
        prodLower.contains('caramelo') ||
        prodLower.contains('chupetin') ||
        prodLower.contains('chupetín') ||
        prodLower.contains('chizito') ||
        prodLower.contains('lays') ||
        prodLower.contains('dorito') ||
        prodLower.contains('piqueo') ||
        prodLower.contains('gomita') ||
        prodLower.contains('mani') ||
        prodLower.contains('maní')) {
      return (
        Icons.cookie_rounded,
        const Color(0xFFEC4899), // Rosa / Fucsia suave
        'Snacks',
      );
    }

    // Limpieza del Hogar
    if (catLower.contains('limpieza') ||
        catLower.contains('hogar') ||
        prodLower.contains('detergente') ||
        prodLower.contains('patito') ||
        prodLower.contains('ariel') ||
        prodLower.contains('ace') ||
        prodLower.contains('bolivar') ||
        prodLower.contains('opal') ||
        prodLower.contains('lejia') ||
        prodLower.contains('lejía') ||
        prodLower.contains('cloro') ||
        prodLower.contains('clorox') ||
        prodLower.contains('poett') ||
        prodLower.contains('sapolio') ||
        prodLower.contains('ayudin') ||
        prodLower.contains('ayudín') ||
        prodLower.contains('lavavajilla') ||
        prodLower.contains('suavizante') ||
        prodLower.contains('escoba') ||
        prodLower.contains('trapeador') ||
        prodLower.contains('desinfectante')) {
      return (
        Icons.cleaning_services_rounded,
        const Color(0xFF8B5CF6), // Violeta moderno
        'Limpieza',
      );
    }

    // Cuidado Personal & Farmacia
    if (catLower.contains('cuidado') ||
        catLower.contains('personal') ||
        catLower.contains('farmacia') ||
        catLower.contains('salud') ||
        prodLower.contains('pasta dental') ||
        prodLower.contains('colgate') ||
        prodLower.contains('kolynos') ||
        prodLower.contains('dento') ||
        prodLower.contains('cepillo') ||
        prodLower.contains('shampoo') ||
        prodLower.contains('jabon') ||
        prodLower.contains('jabón') ||
        prodLower.contains('protex') ||
        prodLower.contains('desodorante') ||
        prodLower.contains('rexona') ||
        prodLower.contains('agua oxigenada') ||
        prodLower.contains('alcohol') ||
        prodLower.contains('algodon') ||
        prodLower.contains('algodón') ||
        prodLower.contains('toalla') ||
        prodLower.contains('panal') ||
        prodLower.contains('pañal') ||
        prodLower.contains('papel higienico') ||
        prodLower.contains('papel higiénico')) {
      return (
        Icons.health_and_safety_rounded,
        const Color(0xFF10B981), // Menta / Esmeralda
        'Cuidado Personal',
      );
    }

    // Carnes & Embutidos
    if (catLower.contains('carne') ||
        catLower.contains('embutido') ||
        prodLower.contains('pollo') ||
        prodLower.contains('hot dog') ||
        prodLower.contains('hotdog') ||
        prodLower.contains('salchicha') ||
        prodLower.contains('jamon') ||
        prodLower.contains('jamón') ||
        prodLower.contains('chorizo') ||
        prodLower.contains('res') ||
        prodLower.contains('pescado')) {
      return (
        Icons.restaurant_rounded,
        const Color(0xFFEF4444), // Rojo carmesí
        'Carnes & Embutidos',
      );
    }

    // Frutas & Verduras
    if (catLower.contains('fruta') ||
        catLower.contains('verdura') ||
        prodLower.contains('manzana') ||
        prodLower.contains('platano') ||
        prodLower.contains('plátano') ||
        prodLower.contains('naranja') ||
        prodLower.contains('limon') ||
        prodLower.contains('limón') ||
        prodLower.contains('papa') ||
        prodLower.contains('cebolla') ||
        prodLower.contains('tomate')) {
      return (
        Icons.eco_rounded,
        const Color(0xFF22C55E), // Verde natural
        'Frutas & Verduras',
      );
    }

    // Panadería & Pastelería
    if (catLower.contains('pan') ||
        catLower.contains('pasteler') ||
        prodLower.contains('pan ') ||
        prodLower.contains('torta') ||
        prodLower.contains('keke') ||
        prodLower.contains('pastel')) {
      return (
        Icons.bakery_dining_rounded,
        const Color(0xFFD97706), // Dorado ámbar
        'Panadería',
      );
    }

    // Licores & Cervezas
    if (catLower.contains('licor') ||
        catLower.contains('cerveza') ||
        catLower.contains('alcohol') ||
        prodLower.contains('cerveza') ||
        prodLower.contains('pilsen') ||
        prodLower.contains('cristal') ||
        prodLower.contains('cusqueña') ||
        prodLower.contains('vino') ||
        prodLower.contains('ron') ||
        prodLower.contains('pisco') ||
        prodLower.contains('whisky') ||
        prodLower.contains('vodka')) {
      return (
        Icons.sports_bar_rounded,
        const Color(0xFF7C3AED), // Índigo profundo
        'Licores',
      );
    }

    // Fallback general elegante
    return (
      allowsDecimals ? Icons.scale_rounded : Icons.inventory_2_rounded,
      const Color(0xFF4353FF), // Azul BodeGo por defecto
      catOriginalName.isNotEmpty ? catOriginalName : 'General',
    );
  }

  /// Parsea un código hexadecimal a Color con seguridad ante excepciones.
  static Color? _parseHexColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return null;
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return null;
    }
  }
}
