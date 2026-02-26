import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'receipt_item.g.dart';

/// Represents an individual item on a receipt
@JsonSerializable()
class ReceiptItem {
  const ReceiptItem({
    required this.id,
    required this.name,
    required this.totalPrice,
    this.quantity = 1,
    this.unitPrice,
    this.category,
    this.taxRate,
    this.description,
    this.sku,
    this.barcode,
  });
  
  /// Unique identifier for the item
  final String id;
  
  /// Name/description of the item
  final String name;
  
  /// Quantity purchased
  final int quantity;
  
  /// Price per unit (if available)
  final double? unitPrice;
  
  /// Total price for this item (quantity * unit price)
  final double totalPrice;
  
  /// Category of the item (food, beverage, etc.)
  final String? category;
  
  /// Tax rate applied to this item (as percentage, e.g., 24.0 for 24%)
  final double? taxRate;
  
  /// Additional description or details
  final String? description;
  
  /// Stock Keeping Unit identifier
  final String? sku;
  
  /// Product barcode if available
  final String? barcode;
  
  // ========== COMPUTED PROPERTIES ==========
  
  /// Calculated unit price (total / quantity)
  double get calculatedUnitPrice => totalPrice / quantity;
  
  /// Whether unit price matches the calculated value
  bool get hasUnitPriceDiscrepancy {
    if (unitPrice == null) return false;
    return (unitPrice! - calculatedUnitPrice).abs() > 0.01;
  }
  
  /// Tax amount for this item (if tax rate is known)
  double? get taxAmount {
    if (taxRate == null) return null;
    return totalPrice * (taxRate! / (100 + taxRate!));
  }
  
  /// Price before tax (if tax rate is known)
  double? get priceBeforeTax {
    final tax = taxAmount;
    if (tax == null) return null;
    return totalPrice - tax;
  }
  
  // ========== FACTORY CONSTRUCTORS ==========
  
  /// Creates a new receipt item with generated ID
  factory ReceiptItem.create({
    required String name,
    required double totalPrice,
    int quantity = 1,
    double? unitPrice,
    String? category,
    double? taxRate,
    String? description,
    String? sku,
    String? barcode,
  }) {
    return ReceiptItem(
      id: const Uuid().v4(),
      name: name,
      quantity: quantity,
      unitPrice: unitPrice,
      totalPrice: totalPrice,
      category: category,
      taxRate: taxRate,
      description: description,
      sku: sku,
      barcode: barcode,
    );
  }
  
  /// Creates ReceiptItem from JSON
  factory ReceiptItem.fromJson(Map<String, dynamic> json) => _$ReceiptItemFromJson(json);
  
  /// Converts ReceiptItem to JSON
  Map<String, dynamic> toJson() => _$ReceiptItemToJson(this);
  
  // ========== COPY WITH METHOD ==========
  
  /// Creates a copy of this item with updated fields
  ReceiptItem copyWith({
    String? id,
    String? name,
    int? quantity,
    double? unitPrice,
    double? totalPrice,
    String? category,
    double? taxRate,
    String? description,
    String? sku,
    String? barcode,
  }) {
    return ReceiptItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      category: category ?? this.category,
      taxRate: taxRate ?? this.taxRate,
      description: description ?? this.description,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
    );
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReceiptItem &&
          runtimeType == other.runtimeType &&
          id == other.id;
  
  @override
  int get hashCode => id.hashCode;
  
  @override
  String toString() => 'ReceiptItem(name: $name, qty: $quantity, total: $totalPrice)';
}

/// Categories for common receipt items
class ItemCategory {
  static const String food = 'food';
  static const String beverage = 'beverage';
  static const String alcohol = 'alcohol';
  static const String tobacco = 'tobacco';
  static const String clothing = 'clothing';
  static const String electronics = 'electronics';
  static const String books = 'books';
  static const String medicine = 'medicine';
  static const String fuel = 'fuel';
  static const String services = 'services';
  static const String other = 'other';
  
  /// Common categories list
  static const List<String> common = [
    food,
    beverage,
    alcohol,
    clothing,
    electronics,
    services,
    other,
  ];
  
  /// Get localized category name
  static String getLocalizedName(String category, String languageCode) {
    final categoryNames = <String, Map<String, String>>{
      food: {
        'en': 'Food',
        'fi': 'Ruoka',
        'sv': 'Mat',
        'fr': 'Nourriture',
        'de': 'Lebensmittel',
        'it': 'Cibo',
        'es': 'Comida',
      },
      beverage: {
        'en': 'Beverage',
        'fi': 'Juoma',
        'sv': 'Dryck',
        'fr': 'Boisson',
        'de': 'Getränk',
        'it': 'Bevanda',
        'es': 'Bebida',
      },
      clothing: {
        'en': 'Clothing',
        'fi': 'Vaatteet',
        'sv': 'Kläder',
        'fr': 'Vêtements',
        'de': 'Kleidung',
        'it': 'Abbigliamento',
        'es': 'Ropa',
      },
      electronics: {
        'en': 'Electronics',
        'fi': 'Elektroniikka',
        'sv': 'Elektronik',
        'fr': 'Électronique',
        'de': 'Elektronik',
        'it': 'Elettronica',
        'es': 'Electrónicos',
      },
      services: {
        'en': 'Services',
        'fi': 'Palvelut',
        'sv': 'Tjänster',
        'fr': 'Services',
        'de': 'Dienstleistungen',
        'it': 'Servizi',
        'es': 'Servicios',
      },
      other: {
        'en': 'Other',
        'fi': 'Muu',
        'sv': 'Annat',
        'fr': 'Autre',
        'de': 'Sonstiges',
        'it': 'Altro',
        'es': 'Otro',
      },
    };
    
    return categoryNames[category]?[languageCode] ?? category;
  }
  
  /// Auto-detect category from item name
  static String? detectCategory(String itemName) {
    final lowerName = itemName.toLowerCase();
    
    // Food keywords in multiple languages
    final foodKeywords = [
      'bread', 'milk', 'cheese', 'meat', 'fish', 'fruit', 'vegetable',
      'leipä', 'maito', 'juusto', 'liha', 'kala', 'hedelmä', 'vihannes',
      'bröd', 'mjölk', 'ost', 'kött', 'fisk', 'frukt', 'grönsak',
      'pain', 'lait', 'fromage', 'viande', 'poisson', 'fruit', 'légume',
      'brot', 'milch', 'käse', 'fleisch', 'fisch', 'obst', 'gemüse',
      'pane', 'latte', 'formaggio', 'carne', 'pesce', 'frutta', 'verdura',
      'pan', 'leche', 'queso', 'carne', 'pescado', 'fruta', 'verdura',
    ];
    
    // Beverage keywords
    final beverageKeywords = [
      'coffee', 'tea', 'water', 'juice', 'soda', 'beer', 'wine',
      'kahvi', 'tee', 'vesi', 'mehu', 'limsa', 'olut', 'viini',
      'kaffe', 'te', 'vatten', 'juice', 'läsk', 'öl', 'vin',
      'café', 'thé', 'eau', 'jus', 'soda', 'bière', 'vin',
      'kaffee', 'tee', 'wasser', 'saft', 'limonade', 'bier', 'wein',
      'caffè', 'tè', 'acqua', 'succo', 'bibita', 'birra', 'vino',
      'café', 'té', 'agua', 'zumo', 'refresco', 'cerveza', 'vino',
    ];
    
    for (final keyword in foodKeywords) {
      if (lowerName.contains(keyword)) return food;
    }
    
    for (final keyword in beverageKeywords) {
      if (lowerName.contains(keyword)) return beverage;
    }
    
    return null; // Unable to determine
  }
}