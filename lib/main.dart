import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_router.dart';
import 'data/models/shop_model.dart';
import 'data/models/item_model.dart';
import 'data/models/order_model.dart';

import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

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
  Hive.registerAdapter(ShopModelAdapter());
  Hive.registerAdapter(ItemModelAdapter());
  Hive.registerAdapter(CartItemModelAdapter());
  Hive.registerAdapter(OrderModelAdapter());
}

Future<void> _openBoxes() async {
  try {
    await Hive.openBox<ShopModel>('shop_box');
    await Hive.openBox<ItemModel>('items_box');
    await Hive.openBox<OrderModel>('orders_box');
    await Hive.openBox('settings_box'); // Box for simple settings like current token
  } catch (e) {
    debugPrint("⚠️ Error opening Hive boxes: $e. Attempting to clear and reopen...");
    // If opening fails (often due to corruption), we might need to delete and recreate
    // For now, just rethrow to let the global handler catch it
    rethrow;
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
