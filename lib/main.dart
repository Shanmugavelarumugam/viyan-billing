import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_router.dart';
import 'data/models/shop_model.dart';
import 'data/models/item_model.dart';
import 'data/models/order_model.dart';
import 'features/printer/models/printer_settings_model.dart';

import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'core/services/notification_service.dart';

void main() async {
  // Use a targeted try-catch for the early initialization to catch fatal errors
  try {
    WidgetsFlutterBinding.ensureInitialized();
    debugPrint("🚀 Starting Viyan Billing App...");

    // 1. Initialize Hive
    await Hive.initFlutter();
    debugPrint("✅ Hive initialized");

    // 2. Register Hive Adapters
    _registerAdapters();
    debugPrint("✅ Hive adapters registered");

    // 3. Open Hive Boxes
    await _openBoxes();
    debugPrint("✅ Hive boxes opened");

    // 4. Initialize Firebase (with platform safety)
    await _initializeFirebase();

    // 5. Initialize Notification Service (non-blocking)
    NotificationService.init();

    runApp(
      const ProviderScope(
        child: ViyanBillingApp(),
      ),
    );
  } catch (e, stackTrace) {
    debugPrint("❌ FATAL ERROR DURING STARTUP: $e");
    debugPrint(stackTrace.toString());
    
    // Show a basic error app if initialization fails completely
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                const Text(
                  "App Failed to Start",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  "Error: $e",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => main(),
                  child: const Text("RETRY"),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }
}

void _registerAdapters() {
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(ShopModelAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(ItemModelAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(CartItemModelAdapter());
  }
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(OrderModelAdapter());
  }
  if (!Hive.isAdapterRegistered(4)) {
    Hive.registerAdapter(PrinterSettingsModelAdapter());
  }
}

Future<void> _openBoxes() async {
  // Open boxes in parallel for faster startup
  await Future.wait([
    _openBoxSafely<ShopModel>('shop_box'),
    _openBoxSafely<ItemModel>('items_box'),
    _openBoxSafely<OrderModel>('orders_box'),
    _openBoxSafely<dynamic>('settings_box'),
    _openBoxSafely<PrinterSettingsModel>('printer_box'),
  ]);
  debugPrint("✅ Hive boxes opened");
}

/// Opens a typed Hive box, and if it fails due to schema changes (type cast errors),
/// it closes the box if open, deletes the corrupted box from disk, and reopens it fresh.
Future<void> _openBoxSafely<T>(String boxName) async {
  try {
    if (T == dynamic) {
      await Hive.openBox(boxName);
    } else {
      await Hive.openBox<T>(boxName);
    }
  } catch (e) {
    debugPrint("⚠️ Box '$boxName' failed to open (schema mismatch?): $e");
    debugPrint("🔄 Deleting and recreating box '$boxName'...");
    try {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box(boxName).close();
      }
      await Hive.deleteBoxFromDisk(boxName);
      if (T == dynamic) {
        await Hive.openBox(boxName);
      } else {
        await Hive.openBox<T>(boxName);
      }
      debugPrint("✅ Box '$boxName' recreated successfully.");
    } catch (e2) {
      debugPrint("❌ Failed to recreate box '$boxName': $e2");
      rethrow;
    }
  }
}

Future<void> _initializeFirebase() async {
  // Skip initialization on platforms where it's not configured to prevent crashes
  if (kIsWeb) return;
  
  if (defaultTargetPlatform == TargetPlatform.macOS || 
      defaultTargetPlatform == TargetPlatform.windows || 
      defaultTargetPlatform == TargetPlatform.linux) {
    debugPrint("ℹ️ Skipping Firebase initialization for current desktop platform ($defaultTargetPlatform)");
    return;
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Enable App Check for Firebase abuse protection
    await FirebaseAppCheck.instance.activate();
    debugPrint("✅ Firebase initialized successfully");
  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app') {
      debugPrint("ℹ️ Firebase already initialized (duplicate-app)");
    } else {
      debugPrint("⚠️ Firebase initialization failed: ${e.message}");
    }
  } catch (e) {
    debugPrint("⚠️ Unexpected error during Firebase initialization: $e");
  }
}

class ViyanBillingApp extends ConsumerWidget {
  const ViyanBillingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Viyan Billing',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
