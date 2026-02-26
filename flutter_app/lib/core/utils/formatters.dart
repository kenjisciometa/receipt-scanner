/// Utility class for formatting values
class Formatters {
  /// Format date as DD/MM/YYYY
  static String formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Format date as YYYY-MM-DD (ISO format)
  static String formatDateIso(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Format amount with 2 decimal places
  static String formatAmount(double amount) {
    return amount.toStringAsFixed(2);
  }

  /// Format amount with currency symbol
  static String formatCurrency(double amount, {String symbol = '€'}) {
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  /// Format percentage
  static String formatPercent(double value) {
    return '${value.toStringAsFixed(1)}%';
  }
}
