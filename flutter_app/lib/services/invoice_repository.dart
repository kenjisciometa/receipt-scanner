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

  /// Cached organization ID
  static String? _cachedOrganizationId;
  static String? _cachedForUserId;

  /// Get organization ID from users table in auth Supabase
  Future<String?> _getOrganizationId() async {
    final userId = _userId;
    if (userId == null) return null;

    // Return cached value if for same user
    if (_cachedForUserId == userId && _cachedOrganizationId != null) {
      return _cachedOrganizationId;
    }

    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('organization_id')
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        _cachedOrganizationId = response['organization_id'] as String?;
        _cachedForUserId = userId;
        return _cachedOrganizationId;
      }
    } catch (e) {
      // Log error but don't fail - organization_id is optional
      print('Error fetching organization_id: $e');
    }
    return null;
  }

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
    String? paymentMethod,
    String? originalImageUrl,
    double? confidence,
  }) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final organizationId = await _getOrganizationId();

    final data = {
      'user_id': userId,
      'organization_id': organizationId,
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
      'payment_method': paymentMethod,
      'original_image_url': originalImageUrl,
      'confidence': confidence,
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
  }) async {
    final userId = _userId;
    if (userId == null) {
      return [];
    }

    final response = await _client
        .from('invoices')
        .select()
        .eq('user_id', userId)
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

  /// Get invoice statistics for current user
  Future<Map<String, dynamic>> getStatistics() async {
    final invoices = await getInvoices(limit: 1000);

    double totalAmount = 0;
    double totalTax = 0;
    int invoiceCount = invoices.length;

    for (final invoice in invoices) {
      totalAmount += (invoice['total_amount'] as num?)?.toDouble() ?? 0;
      totalTax += (invoice['tax_amount'] as num?)?.toDouble() ?? 0;
    }

    return {
      'total_amount': totalAmount,
      'total_tax': totalTax,
      'invoice_count': invoiceCount,
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
    String? paymentMethod,
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
    if (paymentMethod != null) data['payment_method'] = paymentMethod;

    if (data.isEmpty) return null;

    final response = await _client
        .from('invoices')
        .update(data)
        .eq('id', id)
        .select()
        .single();

    return response;
  }

  /// Delete invoice
  Future<void> deleteInvoice(String id) async {
    await _client.from('invoices').delete().eq('id', id);
  }
}
