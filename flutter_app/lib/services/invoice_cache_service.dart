import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../data/models/invoice_summary.dart';
import 'auth_service.dart';

/// State for invoice cache
class InvoiceCacheState {
  final List<InvoiceSummary> invoices;
  final bool isLoading;
  final String? error;
  final DateTime? lastFetched;

  const InvoiceCacheState({
    this.invoices = const [],
    this.isLoading = false,
    this.error,
    this.lastFetched,
  });

  InvoiceCacheState copyWith({
    List<InvoiceSummary>? invoices,
    bool? isLoading,
    String? error,
    DateTime? lastFetched,
    bool clearError = false,
  }) {
    return InvoiceCacheState(
      invoices: invoices ?? this.invoices,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      lastFetched: lastFetched ?? this.lastFetched,
    );
  }

  /// Check if cache is fresh (less than 5 minutes old)
  bool get isFresh {
    if (lastFetched == null) return false;
    return DateTime.now().difference(lastFetched!) < const Duration(minutes: 5);
  }

  /// Check if cache has data
  bool get hasData => invoices.isNotEmpty;
}

/// Service for caching invoice summaries for duplicate detection.
///
/// This service:
/// - Fetches lightweight invoice data from the server
/// - Caches it locally for instant duplicate detection
/// - Provides findDuplicates() for local comparison without API calls
class InvoiceCacheService extends StateNotifier<InvoiceCacheState> {
  final Ref _ref;

  InvoiceCacheService(this._ref) : super(const InvoiceCacheState());

  /// Ensure cache is fresh, fetching if needed.
  /// Call this on screen load for instant duplicate detection.
  /// If already loading, waits for the loading to complete.
  Future<void> ensureFresh() async {
    // If already loading, wait for it to complete
    if (state.isLoading) {
      debugPrint('[InvoiceCacheService] Already loading, waiting for completion...');
      while (state.isLoading) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      debugPrint('[InvoiceCacheService] Loading completed, cache has ${state.invoices.length} invoices');
      return;
    }

    if (state.isFresh) {
      debugPrint('[InvoiceCacheService] Cache is fresh, skipping refresh');
      return;
    }
    await refresh();
  }

  /// Force refresh the cache from server
  Future<void> refresh() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final authHeaders =
          await _ref.read(authServiceProvider.notifier).getAuthHeaders();
      if (authHeaders['Authorization'] == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Not authenticated',
        );
        return;
      }

      final response = await http.get(
        Uri.parse(AppConfig.invoiceSummaryUrl),
        headers: authHeaders,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['invoices'] != null) {
          final invoices = (data['invoices'] as List)
              .map((json) =>
                  InvoiceSummary.fromJson(json as Map<String, dynamic>))
              .toList();

          state = InvoiceCacheState(
            invoices: invoices,
            lastFetched: DateTime.now(),
          );
          debugPrint(
              '[InvoiceCacheService] Loaded ${invoices.length} invoices into cache');
        } else {
          state = state.copyWith(
            isLoading: false,
            error: data['error'] as String? ?? 'Failed to load invoices',
          );
        }
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        state = state.copyWith(
          isLoading: false,
          error: data['error'] as String? ?? 'Failed to load invoices',
        );
      }
    } catch (e) {
      debugPrint('[InvoiceCacheService] Error refreshing cache: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load invoices: ${e.toString()}',
      );
    }
  }

  /// Find potential duplicates for the given invoice data.
  ///
  /// Returns matches where 2 or more of these fields match:
  /// - total_amount (exact match)
  /// - invoice_date (date only, ignoring time)
  /// - invoice_number (case-insensitive, trimmed)
  ///
  /// null/empty fields are excluded from matching.
  /// Currency is not considered - same amount in different currencies is still a match.
  List<DuplicateMatch> findDuplicates({
    double? totalAmount,
    DateTime? invoiceDate,
    String? invoiceNumber,
    String? excludeId, // Exclude this invoice from results (for edits)
  }) {
    final matches = <DuplicateMatch>[];

    for (final inv in state.invoices) {
      // Skip if same invoice (for edit scenarios)
      if (excludeId != null && inv.id == excludeId) continue;

      final matchedFields = <String>[];

      // Check total_amount (exact match)
      if (totalAmount != null && inv.totalAmount != null) {
        if (inv.totalAmount == totalAmount) {
          matchedFields.add('total_amount');
        }
      }

      // Check invoice_date (date only comparison)
      if (invoiceDate != null && inv.invoiceDate != null) {
        if (inv.invoiceDate!.year == invoiceDate.year &&
            inv.invoiceDate!.month == invoiceDate.month &&
            inv.invoiceDate!.day == invoiceDate.day) {
          matchedFields.add('invoice_date');
        }
      }

      // Check invoice_number (case-insensitive, trimmed)
      if (invoiceNumber != null && invoiceNumber.isNotEmpty) {
        if (inv.invoiceNumber != null && inv.invoiceNumber!.isNotEmpty) {
          if (inv.invoiceNumber!.toLowerCase().trim() ==
              invoiceNumber.toLowerCase().trim()) {
            matchedFields.add('invoice_number');
          }
        }
      }

      // Only include if 2+ fields match
      if (matchedFields.length >= 2) {
        matches.add(DuplicateMatch(
          invoice: inv,
          matchedFields: matchedFields,
        ));
      }
    }

    // Sort by match score (highest first)
    matches.sort((a, b) => b.matchScore.compareTo(a.matchScore));

    return matches;
  }

  /// Add a new invoice to the cache after successful save.
  /// This keeps the cache fresh without needing a full refresh.
  void addToCache(InvoiceSummary invoice) {
    final updated = [invoice, ...state.invoices];
    state = state.copyWith(invoices: updated);
    debugPrint('[InvoiceCacheService] Added invoice ${invoice.id} to cache');
  }

  /// Create an InvoiceSummary from invoice save data.
  /// Use this after saving to add to cache.
  InvoiceSummary createSummaryFromSaveData({
    required String id,
    String? merchantName,
    String? invoiceNumber,
    DateTime? invoiceDate,
    double? totalAmount,
    String currency = 'EUR',
    InvoiceSource source = InvoiceSource.manual,
  }) {
    return InvoiceSummary(
      id: id,
      merchantName: merchantName,
      invoiceNumber: invoiceNumber,
      invoiceDate: invoiceDate,
      totalAmount: totalAmount,
      currency: currency,
      source: source,
    );
  }
}

// Riverpod provider
final invoiceCacheServiceProvider =
    StateNotifierProvider<InvoiceCacheService, InvoiceCacheState>((ref) {
  return InvoiceCacheService(ref);
});

// Convenience provider for checking if duplicates exist
final hasDuplicatesProvider = Provider.family<bool, DuplicateCheckParams>((ref, params) {
  // Watch for cache updates
  ref.watch(invoiceCacheServiceProvider);
  final service = ref.read(invoiceCacheServiceProvider.notifier);

  final duplicates = service.findDuplicates(
    totalAmount: params.totalAmount,
    invoiceDate: params.invoiceDate,
    invoiceNumber: params.invoiceNumber,
    excludeId: params.excludeId,
  );

  return duplicates.isNotEmpty;
});

/// Parameters for duplicate checking
class DuplicateCheckParams {
  final double? totalAmount;
  final DateTime? invoiceDate;
  final String? invoiceNumber;
  final String? excludeId;

  const DuplicateCheckParams({
    this.totalAmount,
    this.invoiceDate,
    this.invoiceNumber,
    this.excludeId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DuplicateCheckParams &&
          runtimeType == other.runtimeType &&
          totalAmount == other.totalAmount &&
          invoiceDate == other.invoiceDate &&
          invoiceNumber == other.invoiceNumber &&
          excludeId == other.excludeId;

  @override
  int get hashCode =>
      totalAmount.hashCode ^
      invoiceDate.hashCode ^
      invoiceNumber.hashCode ^
      excludeId.hashCode;
}
