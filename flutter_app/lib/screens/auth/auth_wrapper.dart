import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';
import '../../services/billing_service.dart';
import '../../services/google_play_billing_service.dart';
import 'login_screen.dart';
import '../home/home_screen.dart';
import '../billing/trial_start_screen.dart';
import '../billing/paywall_screen.dart';

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  bool _billingChecked = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _checkBillingStatus() async {
    if (_billingChecked) return;

    final authState = ref.read(authServiceProvider);
    if (authState.isAuthenticated) {
      // Initialize Google Play Billing on Android
      if (Platform.isAndroid) {
        final googlePlayService = ref.read(googlePlayBillingServiceProvider.notifier);
        await googlePlayService.initialize();
      }

      final billingService = ref.read(billingServiceProvider.notifier);
      await billingService.getAppAccess();
      if (mounted) {
        setState(() {
          _billingChecked = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authServiceProvider);
    final billingState = ref.watch(billingServiceProvider);

    // Show loading indicator while checking auth state
    if (authState.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Show error if any
    if (authState.error != null && !authState.isAuthenticated) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Authentication error: ${authState.error}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(authServiceProvider);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // If not authenticated, reset billing check flag and show login screen
    if (!authState.isAuthenticated) {
      // Reset billing state when logged out
      if (_billingChecked) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _billingChecked = false;
            });
          }
          // Also reset billing service state
          ref.read(billingServiceProvider.notifier).reset();
        });
      }
      return const LoginScreen();
    }

    // User is authenticated - check billing status
    if (!_billingChecked) {
      // Trigger billing check
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkBillingStatus();
      });

      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Checking subscription status...'),
            ],
          ),
        ),
      );
    }

    // Show loading while billing is being checked
    if (billingState.isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading...'),
            ],
          ),
        ),
      );
    }

    // Route based on billing status
    final accessStatus = billingState.accessStatus;

    debugPrint('🔄 AuthWrapper routing - accessStatus: ${accessStatus?.status}');
    if (accessStatus != null) {
      debugPrint('   - hasAccess: ${accessStatus.hasAccess}');
      debugPrint('   - trialEndsAt: ${accessStatus.trialEndsAt}');
      debugPrint('   - canStartTrial: ${accessStatus.canStartTrial}');
    }

    if (accessStatus == null) {
      // Failed to get billing status - show error with retry
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              Text(billingState.error ?? 'Failed to check subscription status'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _billingChecked = false;
                  });
                },
                child: const Text('Retry'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  final authService = ref.read(authServiceProvider.notifier);
                  await authService.signOut();
                  setState(() {
                    _billingChecked = false;
                  });
                },
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      );
    }

    // Route based on access status
    switch (accessStatus.status) {
      case BillingStatus.noAccess:
        if (accessStatus.canStartTrial) {
          debugPrint('📱 Routing to: TrialStartScreen (noAccess + canStartTrial)');
          return const TrialStartScreen();
        } else {
          debugPrint('📱 Routing to: PaywallScreen (noAccess + cannot start trial)');
          return const PaywallScreen();
        }

      case BillingStatus.trialExpired:
        debugPrint('📱 Routing to: PaywallScreen (trialExpired)');
        return const PaywallScreen();

      case BillingStatus.trial:
        debugPrint('📱 Routing to: HomeScreen (trial active)');
        return const HomeScreen();
      case BillingStatus.subscribed:
        debugPrint('📱 Routing to: HomeScreen (subscribed)');
        return const HomeScreen();
      case BillingStatus.canceled: // Still has access until period end
        debugPrint('📱 Routing to: HomeScreen (canceled but still active)');
        return const HomeScreen();

      case BillingStatus.unknown:
        // Unknown status - show home screen but log warning
        debugPrint('⚠️ Warning: Unknown billing status - routing to HomeScreen');
        return const HomeScreen();
    }
  }
}
