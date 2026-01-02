// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'receipt_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReceiptItem _$ReceiptItemFromJson(Map<String, dynamic> json) => ReceiptItem(
      id: json['id'] as String,
      name: json['name'] as String,
      totalPrice: (json['totalPrice'] as num).toDouble(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (json['unitPrice'] as num?)?.toDouble(),
      category: json['category'] as String?,
      taxRate: (json['taxRate'] as num?)?.toDouble(),
      description: json['description'] as String?,
      sku: json['sku'] as String?,
      barcode: json['barcode'] as String?,
    );

Map<String, dynamic> _$ReceiptItemToJson(ReceiptItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'quantity': instance.quantity,
      'unitPrice': instance.unitPrice,
      'totalPrice': instance.totalPrice,
      'category': instance.category,
      'taxRate': instance.taxRate,
      'description': instance.description,
      'sku': instance.sku,
      'barcode': instance.barcode,
    };
