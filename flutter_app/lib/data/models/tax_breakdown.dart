import 'package:json_annotation/json_annotation.dart';

part 'tax_breakdown.g.dart';

/// Represents a tax breakdown entry with rate and amount
@JsonSerializable()
class TaxBreakdown {
  const TaxBreakdown({
    required this.rate,
    required this.amount,
  });

  /// Tax rate as percentage (e.g., 14.0 for 14%)
  final double rate;

  /// Tax amount for this rate
  final double amount;

  /// Creates TaxBreakdown from JSON
  factory TaxBreakdown.fromJson(Map<String, dynamic> json) => _$TaxBreakdownFromJson(json);

  /// Converts TaxBreakdown to JSON
  Map<String, dynamic> toJson() => _$TaxBreakdownToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaxBreakdown &&
          runtimeType == other.runtimeType &&
          rate == other.rate &&
          amount == other.amount;

  @override
  int get hashCode => rate.hashCode ^ amount.hashCode;

  @override
  String toString() => 'TaxBreakdown(rate: $rate%, amount: $amount)';
}

