// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'receipt.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Receipt _$ReceiptFromJson(Map<String, dynamic> json) => Receipt(
      id: json['id'] as String,
      originalImagePath: json['originalImagePath'] as String,
      processedImagePath: json['processedImagePath'] as String?,
      rawOcrText: json['rawOcrText'] as String?,
      merchantName: json['merchantName'] as String?,
      purchaseDate: json['purchaseDate'] == null
          ? null
          : DateTime.parse(json['purchaseDate'] as String),
      totalAmount: (json['totalAmount'] as num?)?.toDouble(),
      subtotalAmount: (json['subtotalAmount'] as num?)?.toDouble(),
      taxAmount: (json['taxAmount'] as num?)?.toDouble(),
      taxBreakdown: (json['taxBreakdown'] as List<dynamic>?)
              ?.map((e) => TaxBreakdown.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      taxTotal: (json['taxTotal'] as num?)?.toDouble(),
      paymentMethod:
          $enumDecodeNullable(_$PaymentMethodEnumMap, json['paymentMethod']),
      currency: $enumDecodeNullable(_$CurrencyEnumMap, json['currency']) ??
          Currency.eur,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => ReceiptItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      detectedLanguage: json['detectedLanguage'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      modifiedAt: json['modifiedAt'] == null
          ? null
          : DateTime.parse(json['modifiedAt'] as String),
      status: $enumDecodeNullable(_$ReceiptStatusEnumMap, json['status']) ??
          ReceiptStatus.pending,
      isVerified: json['isVerified'] as bool? ?? false,
      receiptNumber: json['receiptNumber'] as String?,
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$ReceiptToJson(Receipt instance) => <String, dynamic>{
      'id': instance.id,
      'originalImagePath': instance.originalImagePath,
      'processedImagePath': instance.processedImagePath,
      'rawOcrText': instance.rawOcrText,
      'merchantName': instance.merchantName,
      'purchaseDate': instance.purchaseDate?.toIso8601String(),
      'totalAmount': instance.totalAmount,
      'subtotalAmount': instance.subtotalAmount,
      'taxAmount': instance.taxAmount,
      'taxBreakdown': instance.taxBreakdown.map((e) => e.toJson()).toList(),
      'taxTotal': instance.taxTotal,
      'paymentMethod': _$PaymentMethodEnumMap[instance.paymentMethod],
      'currency': _$CurrencyEnumMap[instance.currency]!,
      'items': instance.items.map((e) => e.toJson()).toList(),
      'confidence': instance.confidence,
      'detectedLanguage': instance.detectedLanguage,
      'createdAt': instance.createdAt.toIso8601String(),
      'modifiedAt': instance.modifiedAt?.toIso8601String(),
      'status': _$ReceiptStatusEnumMap[instance.status]!,
      'isVerified': instance.isVerified,
      'receiptNumber': instance.receiptNumber,
      'notes': instance.notes,
    };

const _$PaymentMethodEnumMap = {
  PaymentMethod.cash: 'cash',
  PaymentMethod.creditCard: 'credit_card',
  PaymentMethod.debitCard: 'debit_card',
  PaymentMethod.card: 'card',
  PaymentMethod.mobilePayment: 'mobile_payment',
  PaymentMethod.contactless: 'contactless',
  PaymentMethod.bankTransfer: 'bank_transfer',
  PaymentMethod.unknown: 'unknown',
};

const _$CurrencyEnumMap = {
  Currency.eur: 'EUR',
  Currency.sek: 'SEK',
  Currency.nok: 'NOK',
  Currency.dkk: 'DKK',
  Currency.usd: 'USD',
  Currency.gbp: 'GBP',
};

const _$ReceiptStatusEnumMap = {
  ReceiptStatus.pending: 'pending',
  ReceiptStatus.processing: 'processing',
  ReceiptStatus.completed: 'completed',
  ReceiptStatus.failed: 'failed',
  ReceiptStatus.needsVerification: 'needs_verification',
};
