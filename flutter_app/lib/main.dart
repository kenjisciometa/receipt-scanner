import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/config/app_config.dart';
import 'config/app_config.dart' as api_config;
import 'services/remote_config_service.dart';
import 'app/app.dart';

/// Global logger instance
final logger = Logger(
  level: EnvironmentConfig.enableVerboseLogging ? Level.debug : Level.info,
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Fetch remote config from server (keys managed server-side)
  await RemoteConfigService.initialize(api_config.AppConfig.accountAppApiBaseUrl);

  // Configure system UI
  await _configureSystemUI();

  // Initialize logging
  _initializeLogging();

  // Run the app with Riverpod
  runApp(
    const ProviderScope(
      child: ReceiptScannerApp(),
    ),
  );
}

/// Configure system UI overlays and orientation
Future<void> _configureSystemUI() async {
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Configure system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
}

/// Initialize logging configuration
void _initializeLogging() {
  if (EnvironmentConfig.enableLogging) {
    logger.i('Receipt Scanner App starting...');
    logger.d('Environment: ${EnvironmentConfig.currentEnvironment}');
    logger.d('Debug logging: ${EnvironmentConfig.enableVerboseLogging}');
    logger.d('Crash reporting: ${EnvironmentConfig.enableCrashReporting}');
  }
}
