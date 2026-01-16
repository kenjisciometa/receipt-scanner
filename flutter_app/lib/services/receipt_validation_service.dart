import '../data/models/tax_breakdown.dart';

/// Service for receipt data validation
class ReceiptValidationService {
  /// Tolerance for currency amount comparisons (2 cents)
  static const double _tolerance = 0.02;

  /// Validate that total matches sum of gross amounts from tax breakdown
  /// Returns error message string if validation fails, null if valid
  static String? validateTotals(
    List<TaxBreakdown> taxBreakdown,
    double? totalAmount,
  ) {
    if (taxBreakdown.isEmpty || totalAmount == null) {
      return null;
    }

    // Calculate sum of gross amounts
    double sumGross = 0;
    bool hasGrossAmounts = false;

    for (final tax in taxBreakdown) {
      if (tax.grossAmount != null) {
        sumGross += tax.grossAmount!;
        hasGrossAmounts = true;
      }
    }

    if (!hasGrossAmounts) {
      return null; // No gross amounts to validate
    }

    final difference = (sumGross - totalAmount).abs();

    if (difference > _tolerance) {
      return 'Total mismatch: Sum of tax categories (${sumGross.toStringAsFixed(2)}) ≠ Total (${totalAmount.toStringAsFixed(2)}). Difference: ${difference.toStringAsFixed(2)}';
    }

    return null;
  }

  /// Validate tax breakdown against totals
  /// Returns list of validation error messages (empty if valid)
  static List<String> validateTaxBreakdown(
    List<dynamic> taxBreakdown,
    double? total,
    double? taxTotal,
  ) {
    final errors = <String>[];
    double grossSum = 0;
    double taxSum = 0;

    for (final item in taxBreakdown) {
      final rate = (item['rate'] as num?)?.toDouble() ?? 0;
      final taxAmount = (item['tax_amount'] as num?)?.toDouble() ?? 0;
      final grossAmount = (item['gross_amount'] as num?)?.toDouble() ?? 0;

      grossSum += grossAmount;
      taxSum += taxAmount;

      // Validate individual item: tax = gross * rate / (100 + rate)
      if (grossAmount > 0 && rate > 0) {
        final expectedTax = grossAmount * rate / (100 + rate);
        if ((taxAmount - expectedTax).abs() > _tolerance) {
          errors.add(
              '$rate%: tax ${taxAmount.toStringAsFixed(2)} != expected ${expectedTax.toStringAsFixed(2)}');
        }
      }
    }

    // Validate gross sum equals total
    if (total != null && grossSum > 0) {
      if ((grossSum - total).abs() > _tolerance) {
        errors.add(
            'Gross sum ${grossSum.toStringAsFixed(2)} != Total ${total.toStringAsFixed(2)}');
      }
    }

    // Validate tax sum equals tax total
    if (taxTotal != null && taxSum > 0) {
      if ((taxSum - taxTotal).abs() > _tolerance) {
        errors.add(
            'Tax sum ${taxSum.toStringAsFixed(2)} != Tax ${taxTotal.toStringAsFixed(2)}');
      }
    }

    return errors;
  }

  /// Validate individual tax breakdown item
  /// Returns true if the item is valid
  static bool validateTaxItem(Map<String, dynamic> item) {
    final rate = (item['rate'] as num?)?.toDouble() ?? 0;
    final taxAmount = (item['tax_amount'] as num?)?.toDouble() ?? 0;
    final grossAmount = (item['gross_amount'] as num?)?.toDouble() ?? 0;

    if (grossAmount > 0 && taxAmount > 0 && rate > 0) {
      final expectedTax = grossAmount * rate / (100 + rate);
      return (taxAmount - expectedTax).abs() < _tolerance;
    }
    return true;
  }
}
