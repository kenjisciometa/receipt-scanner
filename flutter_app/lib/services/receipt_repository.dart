import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

class ReceiptRepository {
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

  /// Save receipt to Supabase
  Future<Map<String, dynamic>?> saveReceipt({
    required String? merchantName,
    required DateTime? purchaseDate,
    required double? subtotalAmount,
    required double? taxAmount,
    required double? totalAmount,
    String? currency,
    String? paymentMethod,
    double? confidence,
    String? originalImageUrl,
    List<Map<String, dynamic>>? taxBreakdown,
  }) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final data = {
      'user_id': userId,
      'merchant_name': merchantName,
      'purchase_date': purchaseDate?.toIso8601String(),
      'subtotal_amount': subtotalAmount,
      'tax_amount': taxAmount,
      'total_amount': totalAmount,
      'currency': currency ?? 'EUR',
      'payment_method': paymentMethod,
      'confidence': confidence,
      'original_image_url': originalImageUrl,
      'tax_breakdown': taxBreakdown,
    };

    final response = await _client
        .from('receipts')
        .insert(data)
        .select()
        .single();

    return response;
  }

  /// Get all receipts for current user
  Future<List<Map<String, dynamic>>> getReceipts({
    int limit = 50,
    int offset = 0,
  }) async {
    final userId = _userId;
    if (userId == null) {
      return [];
    }

    final response = await _client
        .from('receipts')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get receipt by ID
  Future<Map<String, dynamic>?> getReceiptById(String id) async {
    final response = await _client
        .from('receipts')
        .select()
        .eq('id', id)
        .maybeSingle();

    return response;
  }

  /// Get receipt statistics for current user
  Future<Map<String, dynamic>> getStatistics() async {
    final receipts = await getReceipts(limit: 1000);

    double totalSpent = 0;
    double totalTax = 0;
    int receiptCount = receipts.length;

    for (final receipt in receipts) {
      totalSpent += (receipt['total_amount'] as num?)?.toDouble() ?? 0;
      totalTax += (receipt['tax_amount'] as num?)?.toDouble() ?? 0;
    }

    return {
      'total_spent': totalSpent,
      'total_tax': totalTax,
      'receipt_count': receiptCount,
    };
  }

  /// Delete receipt
  Future<void> deleteReceipt(String id) async {
    await _client.from('receipts').delete().eq('id', id);
  }
}
