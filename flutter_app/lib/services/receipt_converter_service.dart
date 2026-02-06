import 'package:flutter/foundation.dart';
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
    if (kDebugMode) {
      print('[ReceiptConverter] START - Converting LLM result');
      print('[ReceiptConverter] llmResult.documentType: ${llmResult.documentType}');
      print('[ReceiptConverter] llmResult.vendorAddress: ${llmResult.vendorAddress}');
    }

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

    // Parse due date for invoices
    DateTime? dueDate;
    if (llmResult.dueDate != null) {
      try {
        dueDate = DateTime.parse(llmResult.dueDate!);
      } catch (e) {
        // Ignore parsing errors for due date
      }
    }

    if (kDebugMode) {
      print('[ReceiptConverter] Converting LLM result to Receipt');
      print('[ReceiptConverter] documentType: ${llmResult.documentType}');
      print('[ReceiptConverter] vendorAddress: ${llmResult.vendorAddress}');
      print('[ReceiptConverter] customerName: ${llmResult.customerName}');
      print('[ReceiptConverter] invoiceNumber: ${llmResult.invoiceNumber}');
      print('[ReceiptConverter] dueDate: $dueDate');
    }

    return Receipt.create(
      originalImagePath: imagePath,
      merchantName: llmResult.merchantName,
      purchaseDate: purchaseDate,
      totalAmount: llmResult.total,
      subtotalAmount: llmResult.subtotal,
      taxAmount: llmResult.taxTotal,
      taxBreakdown: taxBreakdownList,
      taxTotal: llmResult.taxTotal,
      documentType: llmResult.documentType,
      // Invoice-specific fields
      vendorAddress: llmResult.vendorAddress,
      vendorTaxId: llmResult.vendorTaxId,
      customerName: llmResult.customerName,
      invoiceNumber: llmResult.invoiceNumber,
      dueDate: dueDate,
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
