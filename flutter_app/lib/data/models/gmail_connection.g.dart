// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gmail_connection.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GmailConnection _$GmailConnectionFromJson(Map<String, dynamic> json) =>
    GmailConnection(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      gmailEmail: json['gmail_email'] as String,
      gmailUserId: json['gmail_user_id'] as String,
      scopes:
          (json['scopes'] as List<dynamic>).map((e) => e as String).toList(),
      isActive: json['is_active'] as bool,
      syncEnabled: json['sync_enabled'] as bool,
      syncKeywords: (json['sync_keywords'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      lastSyncAt: json['last_sync_at'] == null
          ? null
          : DateTime.parse(json['last_sync_at'] as String),
      lastSyncError: json['last_sync_error'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$GmailConnectionToJson(GmailConnection instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'gmail_email': instance.gmailEmail,
      'gmail_user_id': instance.gmailUserId,
      'scopes': instance.scopes,
      'is_active': instance.isActive,
      'sync_enabled': instance.syncEnabled,
      'sync_keywords': instance.syncKeywords,
      'last_sync_at': instance.lastSyncAt?.toIso8601String(),
      'last_sync_error': instance.lastSyncError,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };
