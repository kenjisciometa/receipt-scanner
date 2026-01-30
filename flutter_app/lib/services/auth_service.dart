import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

/// User data from Sciometa Auth
class AuthUser {
  final String id;
  final String email;
  final String? fullName;
  final String? organizationId;
  final String role;
  final bool emailVerified;

  AuthUser({
    required this.id,
    required this.email,
    this.fullName,
    this.organizationId,
    required this.role,
    required this.emailVerified,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      organizationId: json['organization_id'] as String?,
      role: json['role'] as String? ?? 'user',
      emailVerified: json['email_verified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'full_name': fullName,
    'organization_id': organizationId,
    'role': role,
    'email_verified': emailVerified,
  };
}

/// Authentication session data
class AuthSession {
  final String accessToken;
  final String refreshToken;
  final int expiresAt;
  final int expiresIn;

  AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.expiresIn,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresAt: json['expires_at'] as int,
      expiresIn: json['expires_in'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'expires_at': expiresAt,
    'expires_in': expiresIn,
  };

  bool get isExpired {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    // Consider token expired 60 seconds before actual expiry
    return now >= (expiresAt - 60);
  }
}

/// Authentication state
class AuthState {
  final AuthUser? user;
  final AuthSession? session;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.user,
    this.session,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => user != null && session != null;

  AuthState copyWith({
    AuthUser? user,
    AuthSession? session,
    bool? isLoading,
    String? error,
    bool clearUser = false,
    bool clearSession = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      session: clearSession ? null : (session ?? this.session),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Auth service for Sciometa Auth integration
class AuthService extends StateNotifier<AuthState> {
  static const _userKey = 'auth_user';
  static const _sessionKey = 'auth_session';

  AuthService() : super(const AuthState(isLoading: true)) {
    _loadStoredSession();
  }

  /// Load stored session from SharedPreferences
  Future<void> _loadStoredSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      final sessionJson = prefs.getString(_sessionKey);

      if (userJson != null && sessionJson != null) {
        final user = AuthUser.fromJson(jsonDecode(userJson));
        final session = AuthSession.fromJson(jsonDecode(sessionJson));

        if (!session.isExpired) {
          state = AuthState(user: user, session: session);
          debugPrint('✅ Restored auth session for: ${user.email}');
        } else {
          // Try to refresh the token
          debugPrint('⚠️ Stored session expired, attempting refresh...');
          await _refreshToken(session.refreshToken);
        }
      } else {
        state = const AuthState();
      }
    } catch (e) {
      debugPrint('❌ Error loading stored session: $e');
      state = const AuthState();
    }
  }

  /// Save session to SharedPreferences
  Future<void> _saveSession(AuthUser user, AuthSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(user.toJson()));
      await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
    } catch (e) {
      debugPrint('❌ Error saving session: $e');
    }
  }

  /// Clear stored session
  Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
      await prefs.remove(_sessionKey);
    } catch (e) {
      debugPrint('❌ Error clearing session: $e');
    }
  }

  /// Sign in with email and password
  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await http.post(
        Uri.parse(AppConfig.authLoginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'app_id': AppConfig.appId,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
        final session = AuthSession.fromJson(data['session'] as Map<String, dynamic>);

        await _saveSession(user, session);
        state = AuthState(user: user, session: session);

        debugPrint('✅ Login successful for: ${user.email}');
        return true;
      } else {
        final error = data['error'] as String? ?? 'Login failed';
        state = state.copyWith(isLoading: false, error: error);
        debugPrint('❌ Login failed: $error');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Login error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Refresh the access token
  Future<bool> _refreshToken(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse(AppConfig.authRefreshUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'refresh_token': refreshToken,
          'app_id': AppConfig.appId,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        final newSession = AuthSession.fromJson(data['session'] as Map<String, dynamic>);

        // Keep existing user, update session
        if (state.user != null) {
          await _saveSession(state.user!, newSession);
          state = AuthState(user: state.user, session: newSession);
          debugPrint('✅ Token refreshed successfully');
          return true;
        }
      }

      // Refresh failed, clear session
      debugPrint('❌ Token refresh failed');
      await _clearSession();
      state = const AuthState();
      return false;
    } catch (e) {
      debugPrint('❌ Token refresh error: $e');
      await _clearSession();
      state = const AuthState();
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _clearSession();
    state = const AuthState();
    debugPrint('✅ Signed out');
  }

  /// Get current access token, refreshing if necessary
  Future<String?> getAccessToken() async {
    final session = state.session;
    if (session == null) return null;

    if (session.isExpired) {
      final success = await _refreshToken(session.refreshToken);
      if (!success) return null;
    }

    return state.session?.accessToken;
  }

  /// Get auth headers for API requests
  Future<Map<String, String>> getAuthHeaders() async {
    final token = await getAccessToken();
    if (token != null) {
      return {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
    }
    return {'Content-Type': 'application/json'};
  }
}

// Riverpod providers
final authServiceProvider = StateNotifierProvider<AuthService, AuthState>((ref) {
  return AuthService();
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authServiceProvider).isAuthenticated;
});

final currentUserProvider = Provider<AuthUser?>((ref) {
  return ref.watch(authServiceProvider).user;
});
