import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/config/router_config.dart';
import 'core/theme/app_theme.dart';
import 'core/services/security_service.dart';
import 'core/services/security_globals.dart'; // Import global state
import 'core/storage/storage_service.dart';
import 'package:smashrite/features/exam/data/services/exam_storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Initialize StorageService FIRST (before other services that depend on it)
  await StorageService.init();
  debugPrint('✅ StorageService initialized');

  // Then initialize ExamStorageService
  await ExamStorageService.init();
  debugPrint('✅ ExamStorageService initialized');

  // Setup security callbacks BEFORE SecurityService.initialize()
  await setupEarlySecurityCallbacks();

  // Initialize Security Service early (non-blocking)
  try {
    await SecurityService.initialize();
    debugPrint('✅ Security Service initialized successfully');
  } catch (e) {
    debugPrint('[!! WARNING !!] Security Service initialization failed: $e');
    // App can still run, but security features will be limited
  }

  // Set preferred orientations (portrait only for exams)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ProviderScope(child: SmashriteApp()));
}

class SmashriteApp extends ConsumerWidget {
  const SmashriteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Smashrite',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}