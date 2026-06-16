import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import '../../../data/models/item_model.dart';
import '../../../data/repositories/billing_repository.dart';
import '../../../../data/repositories/firestore_repository.dart';
import '../../../../data/repositories/storage_repository.dart';
import '../../auth/providers/auth_provider.dart';

final billingRepositoryProvider = Provider((ref) {
  final firestore = ref.watch(firestoreRepositoryProvider);
  final storage = ref.watch(storageRepositoryProvider);
  return BillingRepository(firestore, storage);
});

final itemsProvider = StateNotifierProvider<ItemsNotifier, List<ItemModel>>((ref) {
  final billingRepo = ref.watch(billingRepositoryProvider);
  // Watch authentication state to trigger reload on login/logout transitions
  ref.watch(authProvider.select((a) => a.isAuthenticated));
  return ItemsNotifier(billingRepo);
});

// Derived provider: only items that are available and in stock
final availableItemsProvider = Provider<List<ItemModel>>((ref) {
  final items = ref.watch(itemsProvider);
  return items.where((i) => i.isAvailable && (!i.trackStock || (i.stockCount ?? 0.0) > 0)).toList();
});

// Derived provider: categories derived from items
final itemCategoriesProvider = Provider<List<String>>((ref) {
  final items = ref.watch(itemsProvider);
  return ['All', ...items.map((i) => i.category ?? 'Uncategorized').toSet()];
});

// Family provider: filtered items by category
final filteredItemsProvider = Provider.family<List<ItemModel>, String>((ref, category) {
  final available = ref.watch(availableItemsProvider);
  if (category == 'All') return available;
  return available.where((i) => i.category == category).toList();
});

class ItemsNotifier extends StateNotifier<List<ItemModel>> {
  final BillingRepository _billingRepository;
  bool _loaded = false;

  ItemsNotifier(this._billingRepository) : super([]) {
    loadItems();
  }

  void loadItems() {
    if (_loaded) return;
    _loaded = true;
    
    debugPrint('🚀 loadItems called');
    
    // Defer Hive read to after first frame to avoid blocking startup
    Future.microtask(() async {
      final box = Hive.box<ItemModel>('items_box');
      final items = box.values.toList();
      
      debugPrint('📦 Existing hive count: ${items.length}');
      
      if (mounted) {
        state = items;
      }
      if (items.isEmpty) {
        await syncWithCloud();
      }
    });
  }

  Future<void> syncWithCloud() async {
    debugPrint('☁️ syncWithCloud called');
    try {
      final cloudItems = await _billingRepository.getItems();
      
      debugPrint('☁️ Cloud items count: ${cloudItems.length}');
      
      if (cloudItems.isNotEmpty) {
        final box = Hive.box<ItemModel>('items_box');
        await box.clear();
        await box.addAll(cloudItems);
        
        debugPrint('✅ Hive saved: ${box.length}');
        
        if (mounted) state = cloudItems;
      }
    } catch (e) {
      debugPrint('❌ syncWithCloud error: $e');
    }
  }

  Future<void> addItem(ItemModel item) async {
    final box = Hive.box<ItemModel>('items_box');
    await box.add(item);
    if (mounted) state = [...state, item];
    try {
      await _billingRepository.saveItem(item);
    } catch (_) {}
  }

  Future<void> updateItem(ItemModel item) async {
    final box = Hive.box<ItemModel>('items_box');
    final key = box.keys.firstWhere((k) => box.get(k)?.id == item.id);
    await box.put(key, item);
    if (mounted) {
      state = [for (final i in state) if (i.id == item.id) item else i];
    }
    try {
      await _billingRepository.saveItem(item);
    } catch (_) {}
  }

  Future<void> updateItemLocal(ItemModel item) async {
    final box = Hive.box<ItemModel>('items_box');
    final key = box.keys.firstWhere((k) => box.get(k)?.id == item.id);
    await box.put(key, item);
    if (mounted) {
      state = [for (final i in state) if (i.id == item.id) item else i];
    }
  }

  Future<void> deleteItem(String id) async {
    final box = Hive.box<ItemModel>('items_box');
    final key = box.keys.firstWhere((k) => box.get(k)?.id == id);
    await box.delete(key);
    if (mounted) state = state.where((i) => i.id != id).toList();
    try {
      await _billingRepository.deleteItem(id);
    } catch (_) {}
  }

  Future<void> toggleAvailability(String id) async {
    final item = state.firstWhere((i) => i.id == id);
    final updated = item.copyWith(isAvailable: !item.isAvailable);
    await updateItem(updated);
  }

  Future<void> duplicateItem(ItemModel item) async {
    final newItem = item.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '${item.name} (Copy)',
    );
    await addItem(newItem);
  }

  Future<void> clearAndAddItems(List<ItemModel> items) async {
    final box = Hive.box<ItemModel>('items_box');
    await box.clear();
    await box.addAll(items);
    if (mounted) state = items;
  }
}
