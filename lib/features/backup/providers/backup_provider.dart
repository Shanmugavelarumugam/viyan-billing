import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../../data/repositories/firestore_repository.dart';
import '../../../data/models/shop_model.dart';
import '../../../data/models/item_model.dart';
import '../../../data/models/order_model.dart';
import '../../billing/services/invoice_service.dart';

// ── Sync status enum ──────────────────────────────────────────────────────────

enum SyncStatus { synced, pending, error, never }

// ── State ─────────────────────────────────────────────────────────────────────

class BackupSyncState {
  final DateTime? lastSyncedAt;
  final SyncStatus status;
  final int pendingUploads;
  final bool isBackingUp;
  final bool isAutoSyncEnabled;
  final bool wifiOnly;
  final String? backupResultMessage;
  final bool backupResultIsError;
  final bool internetConnected;
  final bool cloudActive;
  final List<String> connectedDevices;
  final bool isRestoring;
  final String? restoreMessage;
  final bool restoreIsError;
  final bool isExportingBills;
  final bool isExportingReports;
  final bool isExportingInventory;
  final String? exportMessage;
  final bool exportIsError;
  final bool isLoaded;

  const BackupSyncState({
    this.lastSyncedAt,
    this.status = SyncStatus.never,
    this.pendingUploads = 0,
    this.isBackingUp = false,
    this.isAutoSyncEnabled = true,
    this.wifiOnly = false,
    this.backupResultMessage,
    this.backupResultIsError = false,
    this.internetConnected = false,
    this.cloudActive = false,
    this.connectedDevices = const ['This Device'],
    this.isRestoring = false,
    this.restoreMessage,
    this.restoreIsError = false,
    this.isExportingBills = false,
    this.isExportingReports = false,
    this.isExportingInventory = false,
    this.exportMessage,
    this.exportIsError = false,
    this.isLoaded = false,
  });

  factory BackupSyncState.initial() => const BackupSyncState();

  BackupSyncState copyWith({
    DateTime? lastSyncedAt,
    SyncStatus? status,
    int? pendingUploads,
    bool? isBackingUp,
    bool? isAutoSyncEnabled,
    bool? wifiOnly,
    String? backupResultMessage,
    bool? backupResultIsError,
    bool? internetConnected,
    bool? cloudActive,
    List<String>? connectedDevices,
    bool? isRestoring,
    String? restoreMessage,
    bool? restoreIsError,
    bool? isExportingBills,
    bool? isExportingReports,
    bool? isExportingInventory,
    String? exportMessage,
    bool? exportIsError,
    bool? isLoaded,
    bool clearBackupMsg = false,
    bool clearRestoreMsg = false,
    bool clearExportMsg = false,
  }) {
    return BackupSyncState(
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      status: status ?? this.status,
      pendingUploads: pendingUploads ?? this.pendingUploads,
      isBackingUp: isBackingUp ?? this.isBackingUp,
      isAutoSyncEnabled: isAutoSyncEnabled ?? this.isAutoSyncEnabled,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      backupResultMessage: clearBackupMsg ? null : (backupResultMessage ?? this.backupResultMessage),
      backupResultIsError: backupResultIsError ?? this.backupResultIsError,
      internetConnected: internetConnected ?? this.internetConnected,
      cloudActive: cloudActive ?? this.cloudActive,
      connectedDevices: connectedDevices ?? this.connectedDevices,
      isRestoring: isRestoring ?? this.isRestoring,
      restoreMessage: clearRestoreMsg ? null : (restoreMessage ?? this.restoreMessage),
      restoreIsError: restoreIsError ?? this.restoreIsError,
      isExportingBills: isExportingBills ?? this.isExportingBills,
      isExportingReports: isExportingReports ?? this.isExportingReports,
      isExportingInventory: isExportingInventory ?? this.isExportingInventory,
      exportMessage: clearExportMsg ? null : (exportMessage ?? this.exportMessage),
      exportIsError: exportIsError ?? this.exportIsError,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class BackupSyncNotifier extends StateNotifier<BackupSyncState> {
  final FirestoreRepository _repository;
  StreamSubscription? _connectivitySub;

  BackupSyncNotifier(this._repository) : super(BackupSyncState.initial()) {
    _loadPreferences();
    _monitorConnectivity();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  // ── Initialization ──────────────────────────────────────────────────────────

  Future<void> _loadPreferences() async {
    try {
      final box = Hive.box('settings_box');
      final autoSync = box.get('backup_auto_sync', defaultValue: true) as bool;
      final wifiOnly = box.get('backup_wifi_only', defaultValue: false) as bool;
      final lastSyncMs = box.get('backup_last_synced') as int?;
      final lastSyncedAt = lastSyncMs != null
          ? DateTime.fromMillisecondsSinceEpoch(lastSyncMs)
          : null;

      final internet = await _checkInternet();

      state = state.copyWith(
        isAutoSyncEnabled: autoSync,
        wifiOnly: wifiOnly,
        lastSyncedAt: lastSyncedAt,
        internetConnected: internet,
        status: lastSyncedAt != null ? SyncStatus.synced : SyncStatus.never,
        cloudActive: _repository.isInitialized,
        pendingUploads: _countPending(),
        isLoaded: true,
      );
    } catch (_) {
      state = state.copyWith(isLoaded: true);
    }
  }

  Future<bool> _checkInternet() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  void _monitorConnectivity() {
    try {
      _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
        final connected = results.any((r) => r != ConnectivityResult.none);
        if (connected != state.internetConnected && mounted) {
          state = state.copyWith(internetConnected: connected);
        }
      });
    } catch (_) {}
  }

  int _countPending() {
    try {
      final box = Hive.box('orders_box');
      return box.length;
    } catch (_) {
      return 0;
    }
  }

  // ── Preferences ─────────────────────────────────────────────────────────────

  Future<void> setAutoSync(bool enabled) async {
    final box = Hive.box('settings_box');
    await box.put('backup_auto_sync', enabled);
    state = state.copyWith(isAutoSyncEnabled: enabled);
  }

  Future<void> setWifiOnly(bool enabled) async {
    final box = Hive.box('settings_box');
    await box.put('backup_wifi_only', enabled);
    state = state.copyWith(wifiOnly: enabled);
  }

  // ── Backup Now ──────────────────────────────────────────────────────────────

  Future<void> backupNow() async {
    state = state.copyWith(
      isBackingUp: true,
      clearBackupMsg: true,
    );
    try {
      final itemBox = Hive.box<ItemModel>('items_box');
      for (final item in itemBox.values) {
        await _repository.saveItem(item);
      }

      final orderBox = Hive.box<OrderModel>('orders_box');
      for (final order in orderBox.values) {
        await _repository.saveOrder(order);
      }

      final shopBox = Hive.box<ShopModel>('shop_box');
      final shop = shopBox.get('shop');
      if (shop != null) {
        await _repository.saveShopProfile(shop);
      }

      final now = DateTime.now();
      final settingsBox = Hive.box('settings_box');
      await settingsBox.put('backup_last_synced', now.millisecondsSinceEpoch);

      state = state.copyWith(
        isBackingUp: false,
        status: SyncStatus.synced,
        lastSyncedAt: now,
        backupResultMessage: 'Backup Completed',
        backupResultIsError: false,
        pendingUploads: 0,
      );
    } catch (e) {
      state = state.copyWith(
        isBackingUp: false,
        status: SyncStatus.error,
        backupResultMessage: 'Backup failed',
        backupResultIsError: true,
      );
    }
  }

  // ── Restore ─────────────────────────────────────────────────────────────────

  Future<void> restoreFromCloud() async {
    state = state.copyWith(
      isRestoring: true,
      clearRestoreMsg: true,
    );
    try {
      final cloudShop = await _repository.getShopProfile();
      if (cloudShop != null) {
        final shopBox = Hive.box<ShopModel>('shop_box');
        await shopBox.put('shop', cloudShop);
      }

      final cloudItems = await _repository.getItemsOnce();
      {
        final itemBox = Hive.box<ItemModel>('items_box');
        await itemBox.clear();
        for (final item in cloudItems) {
          await itemBox.put(item.id, item);
        }
      }

      final cloudOrders = await _repository.getOrdersOnce();
      {
        final orderBox = Hive.box<OrderModel>('orders_box');
        await orderBox.clear();
        for (final order in cloudOrders) {
          await orderBox.put(order.id, order);
        }
      }

      state = state.copyWith(
        isRestoring: false,
        restoreMessage: 'Data restored successfully!',
        restoreIsError: false,
      );
    } catch (e) {
      state = state.copyWith(
        isRestoring: false,
        restoreMessage: 'Restore failed',
        restoreIsError: true,
      );
    }
  }

  // ── Export ──────────────────────────────────────────────────────────────────

  Future<void> exportBillsCsv() async {
    state = state.copyWith(isExportingBills: true, clearExportMsg: true);
    try {
      final box = Hive.box<OrderModel>('orders_box');
      final orders = box.values.toList();
      final buffer = StringBuffer();
      buffer.writeln('Invoice#,Date,Items,Total,Payment Method');
      for (final o in orders) {
        final items = o.items.map((i) => '${i.item.name} x${i.quantity}').join('; ');
        buffer.writeln('${o.tokenNumber},${o.timestamp.toIso8601String()},"$items",${o.total},${o.paymentMethod}');
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/Bills_Export.csv');
      await file.writeAsString(buffer.toString());
      await Share.shareXFiles([XFile(file.path)], text: 'Bills Export');
      state = state.copyWith(
        isExportingBills: false,
        exportMessage: 'Bills exported successfully!',
        exportIsError: false,
      );
    } catch (e) {
      state = state.copyWith(
        isExportingBills: false,
        exportMessage: 'Export failed',
        exportIsError: true,
      );
    }
  }

  Future<void> exportReportsPdf() async {
    state = state.copyWith(isExportingReports: true, clearExportMsg: true);
    try {
      final shopBox = Hive.box<ShopModel>('shop_box');
      final shop = shopBox.get('shop');
      final orderBox = Hive.box<OrderModel>('orders_box');
      final orders = orderBox.values.toList();
      if (shop == null) {
        state = state.copyWith(
          isExportingReports: false,
          exportMessage: 'Shop not configured',
          exportIsError: true,
        );
        return;
      }
      final file = await InvoiceService.generateReport(
        shop: shop,
        orders: orders,
        filterName: 'All',
      );
      await Share.shareXFiles([XFile(file.path)], text: 'Sales Report');
      state = state.copyWith(
        isExportingReports: false,
        exportMessage: 'Report exported successfully!',
        exportIsError: false,
      );
    } catch (e) {
      state = state.copyWith(
        isExportingReports: false,
        exportMessage: 'Export failed',
        exportIsError: true,
      );
    }
  }

  Future<void> exportInventoryCsv() async {
    state = state.copyWith(isExportingInventory: true, clearExportMsg: true);
    try {
      final box = Hive.box<ItemModel>('items_box');
      final items = box.values.toList();
      final buffer = StringBuffer();
      buffer.writeln('Name,Price,Category,Stock,Available');
      for (final item in items) {
        buffer.writeln('"${item.name}",${item.price},${item.category},${item.stockCount ?? 0},${item.isAvailable}');
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/Inventory_Export.csv');
      await file.writeAsString(buffer.toString());
      await Share.shareXFiles([XFile(file.path)], text: 'Inventory Export');
      state = state.copyWith(
        isExportingInventory: false,
        exportMessage: 'Inventory exported successfully!',
        exportIsError: false,
      );
    } catch (e) {
      state = state.copyWith(
        isExportingInventory: false,
        exportMessage: 'Export failed',
        exportIsError: true,
      );
    }
  }

  // ── Utilities ───────────────────────────────────────────────────────────────

  void dismissMessages() {
    state = state.copyWith(clearBackupMsg: true, clearRestoreMsg: true, clearExportMsg: true);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final backupSyncProvider =
    StateNotifierProvider<BackupSyncNotifier, BackupSyncState>((ref) {
  final repository = ref.watch(firestoreRepositoryProvider);
  return BackupSyncNotifier(repository);
});
