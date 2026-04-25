import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../data/models/item_model.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/storage_service.dart';
import '../../shop_setup/providers/shop_provider.dart';

final storageServiceProvider = Provider((ref) => StorageService());

final itemsProvider = StateNotifierProvider<ItemsNotifier, List<ItemModel>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return ItemsNotifier(firestoreService);
});

class ItemsNotifier extends StateNotifier<List<ItemModel>> {
  final FirestoreService _firestoreService;
  
  ItemsNotifier(this._firestoreService) : super([]) {
    loadItems();
  }

  void loadItems() async {
    final box = Hive.box<ItemModel>('items_box');
    state = box.values.toList();
    
    // If local is empty, try to sync from cloud
    if (state.isEmpty) {
      await syncWithCloud();
    }
  }

  Future<void> syncWithCloud() async {
    try {
      final cloudItems = await _firestoreService.getItemsOnce();
      if (cloudItems.isNotEmpty) {
        final box = Hive.box<ItemModel>('items_box');
        await box.clear();
        await box.addAll(cloudItems);
        state = cloudItems;
      }
    } catch (e) {
      // Handle or ignore sync error
    }
  }


  Future<void> addItem(ItemModel item) async {
    final box = Hive.box<ItemModel>('items_box');
    await box.add(item);
    state = [...state, item];
    
    // Sync with Firestore
    try {
      await _firestoreService.saveItem(item);
    } catch (e) {
      // Offline or error - local is still updated
    }
  }

  Future<void> updateItem(ItemModel item) async {
    final box = Hive.box<ItemModel>('items_box');
    final key = box.keys.firstWhere((k) => box.get(k)?.id == item.id);
    await box.put(key, item);
    state = [for (final i in state) if (i.id == item.id) item else i];
    
    // Sync with Firestore
    try {
      await _firestoreService.saveItem(item);
    } catch (e) {
      // Fallback
    }
  }

  Future<void> deleteItem(String id) async {
    final box = Hive.box<ItemModel>('items_box');
    final key = box.keys.firstWhere((k) => box.get(k)?.id == id);
    await box.delete(key);
    state = state.where((i) => i.id != id).toList();
    
    // Sync with Firestore
    try {
      await _firestoreService.deleteItem(id);
    } catch (e) {
      // Fallback
    }
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
    state = items;
    
    // Bulk sync could be added here if needed
  }
}
