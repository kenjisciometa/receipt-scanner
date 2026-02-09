import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../data/models/gmail_connection.dart';
import '../data/models/gmail_extracted_invoice.dart';
import 'auth_service.dart';

// Re-export GmailConnectionState for convenience
export '../data/models/gmail_connection.dart' show GmailConnectionState;

/// Gmail service for OAuth connection and invoice extraction management.
///
/// This service handles:
/// - Gmail OAuth authentication via Google Sign-In
/// - Sending auth code to server for token exchange
/// - Managing connection status
/// - Triggering manual sync
/// - Managing extracted invoices (approve/reject)
class GmailService extends StateNotifier<GmailConnectionState> {
  final Ref _ref;

  /// Google Sign-In instance configured for Gmail readonly access
  /// Uses serverClientId to get auth code for server-side token exchange
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/gmail.readonly',
    ],
    // Web client ID for server-side token exchange
    // This allows us to get an auth code that the server can exchange for refresh token
    serverClientId: AppConfig.googleWebClientId,
  );

  GmailService(this._ref) : super(const GmailConnectionState(isLoading: true)) {
    _loadConnection();
  }

  /// Load existing Gmail connection from server
  Future<void> _loadConnection() async {
    try {
      final authHeaders = await _ref.read(authServiceProvider.notifier).getAuthHeaders();
      if (authHeaders['Authorization'] == null) {
        state = const GmailConnectionState();
        return;
      }

      final response = await http.get(
        Uri.parse(AppConfig.gmailConnectionsUrl),
        headers: authHeaders,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['connection'] != null) {
          final connection = GmailConnection.fromJson(
            data['connection'] as Map<String, dynamic>,
          );
          state = GmailConnectionState(connection: connection);
          debugPrint('Gmail connection loaded: ${connection.gmailEmail}');
        } else {
          state = const GmailConnectionState();
        }
      } else {
        state = const GmailConnectionState();
      }
    } catch (e) {
      debugPrint('Error loading Gmail connection: $e');
      state = const GmailConnectionState();
    }
  }

  /// Connect Gmail account via OAuth
  ///
  /// Returns true if connection was successful
  Future<bool> connectGmail() async {
    state = state.copyWith(isConnecting: true, clearError: true);

    try {
      // Disconnect first to ensure we get a fresh auth code
      // (If app was previously authorized, signIn won't return serverAuthCode)
      try {
        await _googleSignIn.disconnect();
      } catch (_) {
        // Ignore errors - user might not have been signed in
      }

      // Sign in with Google (will show account picker and consent screen)
      final account = await _googleSignIn.signIn();

      if (account == null) {
        // User cancelled
        state = state.copyWith(isConnecting: false);
        return false;
      }

      // Get server auth code for token exchange
      final serverAuthCode = account.serverAuthCode;

      if (serverAuthCode == null) {
        state = state.copyWith(
          isConnecting: false,
          error: 'Failed to get authorization code. Please try again.',
        );
        return false;
      }

      debugPrint('Gmail OAuth successful for: ${account.email}');
      debugPrint('Got server auth code, sending to server...');

      // Send auth code to server for token exchange
      final success = await _registerTokenWithServer(
        authCode: serverAuthCode,
        gmailEmail: account.email,
      );

      if (success) {
        // Reload connection to get the stored data
        await _loadConnection();
        debugPrint('Gmail connected successfully: ${account.email}');
      }

      state = state.copyWith(isConnecting: false);
      return success;
    } catch (e) {
      debugPrint('Gmail connection error: $e');
      state = state.copyWith(
        isConnecting: false,
        error: 'Failed to connect Gmail: ${e.toString()}',
      );
      return false;
    }
  }

  /// Send auth code to server for token exchange and storage
  Future<bool> _registerTokenWithServer({
    required String authCode,
    required String gmailEmail,
  }) async {
    try {
      final authHeaders = await _ref.read(authServiceProvider.notifier).getAuthHeaders();

      final response = await http.post(
        Uri.parse(AppConfig.gmailRegisterTokenUrl),
        headers: authHeaders,
        body: jsonEncode({
          'auth_code': authCode,
          'gmail_email': gmailEmail,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        return true;
      } else {
        final error = data['error'] as String? ?? 'Failed to register token';
        state = state.copyWith(error: error);
        debugPrint('Failed to register token: $error');
        return false;
      }
    } catch (e) {
      debugPrint('Error registering token: $e');
      state = state.copyWith(error: 'Server error: ${e.toString()}');
      return false;
    }
  }

  /// Disconnect Gmail account
  Future<bool> disconnectGmail() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Disconnect from Google (revokes app access, not just sign out)
      // This ensures next sign-in will show consent screen and provide new auth code
      await _googleSignIn.disconnect();

      // Notify server to remove connection
      final authHeaders = await _ref.read(authServiceProvider.notifier).getAuthHeaders();

      final response = await http.post(
        Uri.parse(AppConfig.gmailDisconnectUrl),
        headers: authHeaders,
      );

      if (response.statusCode == 200) {
        state = const GmailConnectionState();
        debugPrint('Gmail disconnected successfully');
        return true;
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        state = state.copyWith(
          isLoading: false,
          error: data['error'] as String? ?? 'Failed to disconnect',
        );
        return false;
      }
    } catch (e) {
      debugPrint('Error disconnecting Gmail: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to disconnect: ${e.toString()}',
      );
      return false;
    }
  }

  /// Trigger manual sync of Gmail messages
  ///
  /// Note: Sync processing can take a long time. Even if the HTTP request
  /// times out, the server may still be processing. We handle this gracefully
  /// by reloading invoices after any error.
  Future<bool> triggerSync() async {
    if (state.connection == null) return false;

    state = state.copyWith(isSyncing: true, clearError: true);

    bool syncSuccess = false;

    try {
      final authHeaders = await _ref.read(authServiceProvider.notifier).getAuthHeaders();

      // Use longer timeout for sync (can process many emails)
      final response = await http.post(
        Uri.parse(AppConfig.gmailSyncUrl),
        headers: authHeaders,
      ).timeout(const Duration(seconds: 120));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        debugPrint('Gmail sync completed successfully');
        syncSuccess = true;
      } else {
        debugPrint('Gmail sync API returned error: ${data['error']}');
      }
    } catch (e) {
      // Timeout or other errors - server may still be processing
      debugPrint('Gmail sync request error (server may still be processing): $e');
    }

    // Always reload connection and invoices after sync attempt
    // Even if request timed out, server may have completed processing
    try {
      await _loadConnection();
      // Reload invoices to show any newly extracted ones
      await _ref.read(extractedInvoicesServiceProvider.notifier).loadInvoices();
    } catch (e) {
      debugPrint('Error reloading after sync: $e');
    }

    state = state.copyWith(isSyncing: false);

    // Check if new invoices were loaded (indicates sync worked even if request failed)
    final invoicesState = _ref.read(extractedInvoicesServiceProvider);
    if (!syncSuccess && invoicesState.invoices.isNotEmpty) {
      debugPrint('Sync appears successful - invoices loaded');
      syncSuccess = true;
    }

    return syncSuccess;
  }

  /// Update sync settings (keywords, enabled state, sync from date)
  Future<bool> updateSyncSettings({
    bool? syncEnabled,
    List<String>? syncKeywords,
    DateTime? syncFromDate,
    bool clearSyncFromDate = false,
  }) async {
    if (state.connection == null) return false;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final authHeaders = await _ref.read(authServiceProvider.notifier).getAuthHeaders();

      final body = <String, dynamic>{};
      if (syncEnabled != null) body['sync_enabled'] = syncEnabled;
      if (syncKeywords != null) body['sync_keywords'] = syncKeywords;
      if (clearSyncFromDate) {
        body['sync_from_date'] = null;
      } else if (syncFromDate != null) {
        body['sync_from_date'] = syncFromDate.toIso8601String().split('T')[0]; // YYYY-MM-DD
      }

      final response = await http.patch(
        Uri.parse(AppConfig.gmailConnectionsUrl),
        headers: authHeaders,
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        await _loadConnection();
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: data['error'] as String? ?? 'Update failed',
        );
        return false;
      }
    } catch (e) {
      debugPrint('Error updating sync settings: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Update failed: ${e.toString()}',
      );
      return false;
    }
  }

  /// Refresh connection status
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await _loadConnection();
  }
}

/// Service for managing extracted invoices
class ExtractedInvoicesService extends StateNotifier<ExtractedInvoicesState> {
  final Ref _ref;

  ExtractedInvoicesService(this._ref) : super(const ExtractedInvoicesState());

  /// Load extracted invoices from server
  Future<void> loadInvoices({String? status}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final authHeaders = await _ref.read(authServiceProvider.notifier).getAuthHeaders();
      if (authHeaders['Authorization'] == null) {
        state = const ExtractedInvoicesState();
        return;
      }

      var url = AppConfig.gmailExtractedUrl;
      if (status != null) {
        url += '?status=$status';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: authHeaders,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['invoices'] != null) {
          final invoices = (data['invoices'] as List)
              .map((json) => GmailExtractedInvoice.fromJson(json as Map<String, dynamic>))
              .toList();
          state = ExtractedInvoicesState(invoices: invoices);
          debugPrint('Loaded ${invoices.length} extracted invoices');
        } else {
          state = const ExtractedInvoicesState();
        }
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        state = ExtractedInvoicesState(
          error: data['error'] as String? ?? 'Failed to load invoices',
        );
      }
    } catch (e) {
      debugPrint('Error loading extracted invoices: $e');
      state = ExtractedInvoicesState(error: 'Failed to load: ${e.toString()}');
    }
  }

  /// Approve an extracted invoice
  ///
  /// This will create an invoice record in the invoices table
  Future<bool> approveInvoice(String invoiceId, {Map<String, dynamic>? edits}) async {
    state = state.copyWith(isProcessing: true, clearError: true);

    try {
      final authHeaders = await _ref.read(authServiceProvider.notifier).getAuthHeaders();

      final body = <String, dynamic>{};
      if (edits != null) body['edits'] = edits;

      final url = '${AppConfig.gmailExtractedUrl}/$invoiceId/approve';
      debugPrint('Approve URL: $url');
      debugPrint('Approve body: ${jsonEncode(body)}');

      final response = await http.post(
        Uri.parse(url),
        headers: authHeaders,
        body: jsonEncode(body),
      );

      debugPrint('Approve response status: ${response.statusCode}');
      debugPrint('Approve response body: ${response.body}');

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        // Update local state
        final updatedInvoices = state.invoices.map((invoice) {
          if (invoice.id == invoiceId) {
            return invoice.copyWith(
              status: ExtractedInvoiceStatus.approved,
              invoiceId: data['invoice_id'] as String?,
            );
          }
          return invoice;
        }).toList();

        state = state.copyWith(
          invoices: updatedInvoices,
          isProcessing: false,
        );
        debugPrint('Invoice approved: $invoiceId');
        return true;
      } else {
        state = state.copyWith(
          isProcessing: false,
          error: data['error'] as String? ?? 'Approval failed',
        );
        return false;
      }
    } catch (e) {
      debugPrint('Error approving invoice: $e');
      state = state.copyWith(
        isProcessing: false,
        error: 'Approval failed: ${e.toString()}',
      );
      return false;
    }
  }

  /// Reject an extracted invoice
  Future<bool> rejectInvoice(String invoiceId, {String? reason}) async {
    state = state.copyWith(isProcessing: true, clearError: true);

    try {
      final authHeaders = await _ref.read(authServiceProvider.notifier).getAuthHeaders();

      final body = <String, dynamic>{};
      if (reason != null) body['reason'] = reason;

      final response = await http.post(
        Uri.parse('${AppConfig.gmailExtractedUrl}/$invoiceId/reject'),
        headers: authHeaders,
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        // Update local state
        final updatedInvoices = state.invoices.map((invoice) {
          if (invoice.id == invoiceId) {
            return invoice.copyWith(status: ExtractedInvoiceStatus.rejected);
          }
          return invoice;
        }).toList();

        state = state.copyWith(
          invoices: updatedInvoices,
          isProcessing: false,
        );
        debugPrint('Invoice rejected: $invoiceId');
        return true;
      } else {
        state = state.copyWith(
          isProcessing: false,
          error: data['error'] as String? ?? 'Rejection failed',
        );
        return false;
      }
    } catch (e) {
      debugPrint('Error rejecting invoice: $e');
      state = state.copyWith(
        isProcessing: false,
        error: 'Rejection failed: ${e.toString()}',
      );
      return false;
    }
  }

  /// Re-extract an invoice from the original document
  ///
  /// Returns the updated invoice if successful, null otherwise
  Future<GmailExtractedInvoice?> reextractInvoice(String invoiceId) async {
    state = state.copyWith(isProcessing: true, clearError: true);

    try {
      final authHeaders = await _ref.read(authServiceProvider.notifier).getAuthHeaders();

      final response = await http.post(
        Uri.parse('${AppConfig.gmailExtractedUrl}/$invoiceId/reextract'),
        headers: authHeaders,
      ).timeout(const Duration(seconds: 60));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        final updatedInvoice = GmailExtractedInvoice.fromJson(
          data['invoice'] as Map<String, dynamic>,
        );

        // Update local state
        final updatedInvoices = state.invoices.map((invoice) {
          if (invoice.id == invoiceId) {
            return updatedInvoice;
          }
          return invoice;
        }).toList();

        state = state.copyWith(
          invoices: updatedInvoices,
          isProcessing: false,
        );
        debugPrint('Invoice re-extracted: $invoiceId');
        return updatedInvoice;
      } else {
        state = state.copyWith(
          isProcessing: false,
          error: data['error'] as String? ?? 'Re-extraction failed',
        );
        return null;
      }
    } catch (e) {
      debugPrint('Error re-extracting invoice: $e');
      state = state.copyWith(
        isProcessing: false,
        error: 'Re-extraction failed: ${e.toString()}',
      );
      return null;
    }
  }

  /// Refresh invoices
  Future<void> refresh({String? status}) async {
    await loadInvoices(status: status);
  }
}

// Riverpod providers
final gmailServiceProvider = StateNotifierProvider<GmailService, GmailConnectionState>((ref) {
  return GmailService(ref);
});

final extractedInvoicesServiceProvider =
    StateNotifierProvider<ExtractedInvoicesService, ExtractedInvoicesState>((ref) {
  return ExtractedInvoicesService(ref);
});

// Convenience providers
final isGmailConnectedProvider = Provider<bool>((ref) {
  return ref.watch(gmailServiceProvider).isConnected;
});

final gmailConnectionProvider = Provider<GmailConnection?>((ref) {
  return ref.watch(gmailServiceProvider).connection;
});

final pendingExtractedInvoicesCountProvider = Provider<int>((ref) {
  return ref.watch(extractedInvoicesServiceProvider).pendingCount;
});
