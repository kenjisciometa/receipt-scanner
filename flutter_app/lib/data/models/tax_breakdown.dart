import 'package:json_annotation/json_annotation.dart';

part 'tax_breakdown.g.dart';

/// Represents a tax breakdown entry with rate, amounts, and gross total
@JsonSerializable()
class TaxBreakdown {
  const TaxBreakdown({
    required this.rate,
    required this.amount,
    this.taxableAmount,
    this.grossAmount,
  });

  /// Tax rate as percentage (e.g., 14.0 for 14%)
  final double rate;

  /// Tax amount for this rate
  final double amount;

  /// Taxable amount (net amount before tax) for this rate
  final double? taxableAmount;

  /// Gross amount (taxable + tax) for this rate - the subtotal for this tax category
  final double? grossAmount;

  /// Creates TaxBreakdown from JSON
  factory TaxBreakdown.fromJson(Map<String, dynamic> json) => _$TaxBreakdownFromJson(json);

  /// Converts TaxBreakdown to JSON
  Map<String, dynamic> toJson() => _$TaxBreakdownToJson(this);

  /// Copy with new values
  TaxBreakdown copyWith({
    double? rate,
    double? amount,
    double? taxableAmount,
    double? grossAmount,
  }) {
    return TaxBreakdown(
      rate: rate ?? this.rate,
      amount: amount ?? this.amount,
      taxableAmount: taxableAmount ?? this.taxableAmount,
      grossAmount: grossAmount ?? this.grossAmount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaxBreakdown &&
          runtimeType == other.runtimeType &&
          rate == other.rate &&
          amount == other.amount &&
          taxableAmount == other.taxableAmount &&
          grossAmount == other.grossAmount;

  @override
  int get hashCode => rate.hashCode ^ amount.hashCode ^ taxableAmount.hashCode ^ grossAmount.hashCode;

  @override
  String toString() => 'TaxBreakdown(rate: $rate%, amount: $amount, taxable: $taxableAmount, gross: $grossAmount)';
}

