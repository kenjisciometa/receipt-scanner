import 'package:json_annotation/json_annotation.dart';

part 'gmail_connection.g.dart';

/// Represents a Gmail connection for invoice extraction
@JsonSerializable()
class GmailConnection {
  final String id;

  @JsonKey(name: 'user_id')
  final String userId;

  @JsonKey(name: 'gmail_email')
  final String gmailEmail;

  @JsonKey(name: 'gmail_user_id')
  final String gmailUserId;

  final List<String> scopes;

  @JsonKey(name: 'is_active')
  final bool isActive;

  @JsonKey(name: 'sync_enabled')
  final bool syncEnabled;

  @JsonKey(name: 'sync_keywords')
  final List<String> syncKeywords;

  @JsonKey(name: 'sync_from_date')
  final DateTime? syncFromDate;

  @JsonKey(name: 'last_sync_at')
  final DateTime? lastSyncAt;

  @JsonKey(name: 'last_sync_error')
  final String? lastSyncError;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  GmailConnection({
    required this.id,
    required this.userId,
    required this.gmailEmail,
    required this.gmailUserId,
    required this.scopes,
    required this.isActive,
    required this.syncEnabled,
    required this.syncKeywords,
    this.syncFromDate,
    this.lastSyncAt,
    this.lastSyncError,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GmailConnection.fromJson(Map<String, dynamic> json) =>
      _$GmailConnectionFromJson(json);

  Map<String, dynamic> toJson() => _$GmailConnectionToJson(this);

  GmailConnection copyWith({
    String? id,
    String? userId,
    String? gmailEmail,
    String? gmailUserId,
    List<String>? scopes,
    bool? isActive,
    bool? syncEnabled,
    List<String>? syncKeywords,
    DateTime? syncFromDate,
    DateTime? lastSyncAt,
    String? lastSyncError,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearLastSyncError = false,
    bool clearSyncFromDate = false,
  }) {
    return GmailConnection(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      gmailEmail: gmailEmail ?? this.gmailEmail,
      gmailUserId: gmailUserId ?? this.gmailUserId,
      scopes: scopes ?? this.scopes,
      isActive: isActive ?? this.isActive,
      syncEnabled: syncEnabled ?? this.syncEnabled,
      syncKeywords: syncKeywords ?? this.syncKeywords,
      syncFromDate: clearSyncFromDate ? null : (syncFromDate ?? this.syncFromDate),
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastSyncError: clearLastSyncError ? null : (lastSyncError ?? this.lastSyncError),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if connection is healthy (active, sync enabled, no recent errors)
  bool get isHealthy => isActive && syncEnabled && lastSyncError == null;

  /// Get sync status description
  String get syncStatus {
    if (!isActive) return 'Inactive';
    if (!syncEnabled) return 'Sync disabled';
    if (lastSyncError != null) return 'Error';
    if (lastSyncAt == null) return 'Never synced';
    return 'Active';
  }
}

/// State for Gmail connection management
class GmailConnectionState {
  final GmailConnection? connection;
  final bool isLoading;
  final bool isConnecting;
  final bool isSyncing;
  final String? error;

  const GmailConnectionState({
    this.connection,
    this.isLoading = false,
    this.isConnecting = false,
    this.isSyncing = false,
    this.error,
  });

  bool get isConnected => connection != null && connection!.isActive;

  GmailConnectionState copyWith({
    GmailConnection? connection,
    bool? isLoading,
    bool? isConnecting,
    bool? isSyncing,
    String? error,
    bool clearConnection = false,
    bool clearError = false,
  }) {
    return GmailConnectionState(
      connection: clearConnection ? null : (connection ?? this.connection),
      isLoading: isLoading ?? this.isLoading,
      isConnecting: isConnecting ?? this.isConnecting,
      isSyncing: isSyncing ?? this.isSyncing,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
