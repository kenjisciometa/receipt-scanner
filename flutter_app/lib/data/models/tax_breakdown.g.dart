// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tax_breakdown.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TaxBreakdown _$TaxBreakdownFromJson(Map<String, dynamic> json) => TaxBreakdown(
      rate: (json['rate'] as num).toDouble(),
      amount: (json['amount'] as num).toDouble(),
      taxableAmount: (json['taxableAmount'] as num?)?.toDouble(),
      grossAmount: (json['grossAmount'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$TaxBreakdownToJson(TaxBreakdown instance) =>
    <String, dynamic>{
      'rate': instance.rate,
      'amount': instance.amount,
      'taxableAmount': instance.taxableAmount,
      'grossAmount': instance.grossAmount,
    };
