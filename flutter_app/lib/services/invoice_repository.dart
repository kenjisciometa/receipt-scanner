import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

class InvoiceRepository {
  static SupabaseClient? _accountAppClient;

  /// Get AccountApp Supabase client (separate from auth client)
  SupabaseClient get _client {
    _accountAppClient ??= SupabaseClient(
      AppConfig.accountAppSupabaseUrl,
      AppConfig.accountAppSupabaseAnonKey,
    );
    return _accountAppClient!;
  }

  /// Get user ID from the auth client (sciometa-pos)
  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  /// Save invoice to Supabase
  Future<Map<String, dynamic>?> saveInvoice({
    required String? merchantName,
    String? vendorAddress,
    String? vendorTaxId,
    String? customerName,
    String? customerAddress,
    String? customerTaxId,
    String? invoiceNumber,
    DateTime? invoiceDate,
    DateTime? dueDate,
    double? subtotalAmount,
    double? taxAmount,
    double? totalAmount,
    String? currency,
    List<Map<String, dynamic>>? taxBreakdown,
    List<Map<String, dynamic>>? items,
    String? paymentMethod,
    String? paymentStatus,
    String? originalImageUrl,
    double? confidence,
    String? detectedLanguage,
    String? notes,
  }) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final data = {
      'user_id': userId,
      'merchant_name': merchantName,
      'vendor_address': vendorAddress,
      'vendor_tax_id': vendorTaxId,
      'customer_name': customerName,
      'customer_address': customerAddress,
      'customer_tax_id': customerTaxId,
      'invoice_number': invoiceNumber,
      'invoice_date': invoiceDate?.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'subtotal_amount': subtotalAmount,
      'tax_amount': taxAmount,
      'total_amount': totalAmount,
      'currency': currency ?? 'EUR',
      'tax_breakdown': taxBreakdown,
      'items': items,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus ?? 'unpaid',
      'original_image_url': originalImageUrl,
      'confidence': confidence,
      'detected_language': detectedLanguage,
      'notes': notes,
    };

    final response = await _client
        .from('invoices')
        .insert(data)
        .select()
        .single();

    return response;
  }

  /// Get all invoices for current user
  Future<List<Map<String, dynamic>>> getInvoices({
    int limit = 50,
    int offset = 0,
    String? paymentStatus,
  }) async {
    final userId = _userId;
    if (userId == null) {
      return [];
    }

    var query = _client
        .from('invoices')
        .select()
        .eq('user_id', userId);

    if (paymentStatus != null) {
      query = query.eq('payment_status', paymentStatus);
    }

    final response = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get invoice by ID
  Future<Map<String, dynamic>?> getInvoiceById(String id) async {
    final response = await _client
        .from('invoices')
        .select()
        .eq('id', id)
        .maybeSingle();

    return response;
  }

  /// Get overdue invoices
  Future<List<Map<String, dynamic>>> getOverdueInvoices() async {
    final userId = _userId;
    if (userId == null) {
      return [];
    }

    final now = DateTime.now().toIso8601String();

    final response = await _client
        .from('invoices')
        .select()
        .eq('user_id', userId)
        .eq('payment_status', 'unpaid')
        .lt('due_date', now)
        .order('due_date', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get invoice statistics for current user
  Future<Map<String, dynamic>> getStatistics() async {
    final invoices = await getInvoices(limit: 1000);

    double totalAmount = 0;
    double totalTax = 0;
    double unpaidAmount = 0;
    int invoiceCount = invoices.length;
    int unpaidCount = 0;
    int overdueCount = 0;

    final now = DateTime.now();

    for (final invoice in invoices) {
      final amount = (invoice['total_amount'] as num?)?.toDouble() ?? 0;
      totalAmount += amount;
      totalTax += (invoice['tax_amount'] as num?)?.toDouble() ?? 0;

      if (invoice['payment_status'] == 'unpaid') {
        unpaidAmount += amount;
        unpaidCount++;

        final dueDate = invoice['due_date'] != null
            ? DateTime.tryParse(invoice['due_date'])
            : null;
        if (dueDate != null && dueDate.isBefore(now)) {
          overdueCount++;
        }
      }
    }

    return {
      'total_amount': totalAmount,
      'total_tax': totalTax,
      'unpaid_amount': unpaidAmount,
      'invoice_count': invoiceCount,
      'unpaid_count': unpaidCount,
      'overdue_count': overdueCount,
    };
  }

  /// Update invoice
  Future<Map<String, dynamic>?> updateInvoice({
    required String id,
    String? merchantName,
    String? vendorAddress,
    String? vendorTaxId,
    String? customerName,
    String? customerAddress,
    String? customerTaxId,
    String? invoiceNumber,
    DateTime? invoiceDate,
    DateTime? dueDate,
    double? subtotalAmount,
    double? taxAmount,
    double? totalAmount,
    String? currency,
    List<Map<String, dynamic>>? taxBreakdown,
    List<Map<String, dynamic>>? items,
    String? paymentMethod,
    String? paymentStatus,
    DateTime? paidDate,
    String? notes,
  }) async {
    final data = <String, dynamic>{};

    if (merchantName != null) data['merchant_name'] = merchantName;
    if (vendorAddress != null) data['vendor_address'] = vendorAddress;
    if (vendorTaxId != null) data['vendor_tax_id'] = vendorTaxId;
    if (customerName != null) data['customer_name'] = customerName;
    if (customerAddress != null) data['customer_address'] = customerAddress;
    if (customerTaxId != null) data['customer_tax_id'] = customerTaxId;
    if (invoiceNumber != null) data['invoice_number'] = invoiceNumber;
    if (invoiceDate != null) data['invoice_date'] = invoiceDate.toIso8601String();
    if (dueDate != null) data['due_date'] = dueDate.toIso8601String();
    if (subtotalAmount != null) data['subtotal_amount'] = subtotalAmount;
    if (taxAmount != null) data['tax_amount'] = taxAmount;
    if (totalAmount != null) data['total_amount'] = totalAmount;
    if (currency != null) data['currency'] = currency;
    if (taxBreakdown != null) data['tax_breakdown'] = taxBreakdown;
    if (items != null) data['items'] = items;
    if (paymentMethod != null) data['payment_method'] = paymentMethod;
    if (paymentStatus != null) data['payment_status'] = paymentStatus;
    if (paidDate != null) data['paid_date'] = paidDate.toIso8601String();
    if (notes != null) data['notes'] = notes;

    if (data.isEmpty) return null;

    final response = await _client
        .from('invoices')
        .update(data)
        .eq('id', id)
        .select()
        .single();

    return response;
  }

  /// Mark invoice as paid
  Future<Map<String, dynamic>?> markAsPaid(String id, {DateTime? paidDate}) async {
    return updateInvoice(
      id: id,
      paymentStatus: 'paid',
      paidDate: paidDate ?? DateTime.now(),
    );
  }

  /// Delete invoice
  Future<void> deleteInvoice(String id) async {
    await _client.from('invoices').delete().eq('id', id);
  }
}
