import '../data/models/receipt.dart';
import '../data/models/receipt_item.dart';
import '../data/models/tax_breakdown.dart';
import 'llm/llama_cpp_service.dart';

/// Service for converting extraction results to Receipt models
class ReceiptConverterService {
  /// Convert LLM extraction result to Receipt model
  ///
  /// [llmResult] - The extraction result from LLM
  /// [imagePath] - Path to the original image file
  /// [onDateParseError] - Optional callback for date parsing errors
  static Receipt fromLLMResult(
    LLMExtractionResult llmResult, {
    required String imagePath,
    void Function(String dateString)? onDateParseError,
  }) {
    // Parse date
    DateTime? purchaseDate;
    if (llmResult.date != null) {
      try {
        purchaseDate = DateTime.parse(llmResult.date!);
      } catch (e) {
        onDateParseError?.call(llmResult.date!);
      }
    }

    // Convert tax breakdown with full details
    final taxBreakdownList = llmResult.taxBreakdown
        .map((item) => TaxBreakdown(
              rate: item.rate,
              amount: item.taxAmount,
              taxableAmount: item.taxableAmount,
              grossAmount: item.grossAmount,
            ))
        .toList();

    // Detect currency
    Currency currency = Currency.eur;
    if (llmResult.currency != null) {
      currency = Currency.fromCode(llmResult.currency!);
    }

    // Convert items
    final items = llmResult.items.asMap().entries.map((entry) {
      final item = entry.value;
      return ReceiptItem(
        id: 'item_${entry.key}',
        name: item.name,
        quantity: item.quantity,
        unitPrice: item.price / item.quantity,
        totalPrice: item.price,
        taxRate: item.taxRate,
      );
    }).toList();

    return Receipt.create(
      originalImagePath: imagePath,
      merchantName: llmResult.merchantName,
      purchaseDate: purchaseDate,
      totalAmount: llmResult.total,
      subtotalAmount: llmResult.subtotal,
      taxAmount: llmResult.taxTotal,
      taxBreakdown: taxBreakdownList,
      taxTotal: llmResult.taxTotal,
      paymentMethod: llmResult.paymentMethod != null
          ? PaymentMethod.fromString(llmResult.paymentMethod)
          : null,
      currency: currency,
      items: items,
      confidence: llmResult.confidence,
      receiptNumber: llmResult.receiptNumber,
      rawOcrText: llmResult.rawResponse,
      status: ReceiptStatus.completed,
    );
  }
}
