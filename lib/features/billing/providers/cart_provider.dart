import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/item_model.dart';
import '../../../data/models/order_model.dart';
import '../../../data/repositories/billing_repository.dart';
import '../../shop_setup/providers/shop_provider.dart';
import 'billing_provider.dart';
import 'package:hive/hive.dart';
import '../../subscription/services/subscription_service.dart';

class CartBill {
  final String id;
  final String name;
  final List<CartItemModel> items;
  final bool isHold;
  final bool isPaid;
  final String paymentMethod; // Cash, UPI
  final String? customerPhone;

  CartBill({
    required this.id,
    required this.name,
    this.items = const [],
    this.isHold = false,
    this.isPaid = false,
    this.paymentMethod = 'Cash',
    this.customerPhone,
  });

  double get total => items.fold(0, (sum, item) => sum + item.total);

  CartBill copyWith({
    String? name,
    List<CartItemModel>? items,
    bool? isHold,
    bool? isPaid,
    String? paymentMethod,
    String? customerPhone,
  }) {
    return CartBill(
      id: id,
      name: name ?? this.name,
      items: items ?? this.items,
      isHold: isHold ?? this.isHold,
      isPaid: isPaid ?? this.isPaid,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      customerPhone: customerPhone ?? this.customerPhone,
    );
  }
}

class ActiveBillsState {
  final List<CartBill> bills;
  final String selectedBillId;

  ActiveBillsState({
    required this.bills,
    required this.selectedBillId,
  });

  CartBill get selectedBill => bills.firstWhere((b) => b.id == selectedBillId);
}

final cartProvider = StateNotifierProvider<ActiveBillsNotifier, ActiveBillsState>((ref) {
  final billingRepo = ref.watch(billingRepositoryProvider);
  return ActiveBillsNotifier(ref, billingRepo);
});

class ActiveBillsNotifier extends StateNotifier<ActiveBillsState> {
  final Ref ref;
  final BillingRepository _billingRepository;
  
  ActiveBillsNotifier(this.ref, this._billingRepository) : super(_initialState()) {
    _init();
    
    // Listen for manual token resets from the Profile screen to update UI immediately
    ref.listen<int>(tokenProvider, (previous, next) {
      if (next != previous) {
        _updateVisualTokenNames();
      }
    });
  }

  void _init() {
    _updateVisualTokenNames();
  }

  void _updateVisualTokenNames() {
    // Sync the first bill's name with the persisted token value
    final currentToken = ref.read(tokenProvider);
    if (state.bills.length == 1 && state.bills.first.items.isEmpty) {
      state = ActiveBillsState(
        bills: [state.bills.first.copyWith(name: 'Token $currentToken')],
        selectedBillId: state.selectedBillId,
      );
    }
  }

  static ActiveBillsState _initialState() {
    final firstBill = CartBill(id: '1', name: 'Token 1');
    return ActiveBillsState(
      bills: [firstBill],
      selectedBillId: '1',
    );
  }

  void selectBill(String id) {
    final bills = [...state.bills];
    final billIndex = bills.indexWhere((b) => b.id == id);
    if (billIndex != -1) {
      bills[billIndex] = bills[billIndex].copyWith(isHold: false);
    }
    state = ActiveBillsState(bills: bills, selectedBillId: id);
  }

  void addBill({String? name}) {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final currentToken = ref.read(tokenProvider);
    // Use the global token + number of existing bills to determine the visual token name
    final billName = name ?? 'Token ${currentToken + state.bills.length}';
    
    final newBill = CartBill(id: newId, name: billName);
    state = ActiveBillsState(
      bills: [...state.bills, newBill],
      selectedBillId: newId,
    );
  }

  void removeBill(String id) {
    if (state.bills.length <= 1) {
      clearCurrentBill();
      return;
    }
    final newBills = state.bills.where((b) => b.id != id).toList();
    final newSelectedId = id == state.selectedBillId ? newBills.first.id : state.selectedBillId;
    state = ActiveBillsState(bills: newBills, selectedBillId: newSelectedId);
  }

  bool addItem(ItemModel item) {
    final bills = [...state.bills];
    final billIndex = bills.indexWhere((b) => b.id == state.selectedBillId);
    if (billIndex == -1) return false;

    final items = [...bills[billIndex].items];
    final itemIndex = items.indexWhere((i) => i.item.id == item.id);

    if (item.trackStock) {
      final currentStock = item.stockCount ?? 0.0;
      final currentQty = itemIndex != -1 ? items[itemIndex].quantity : 0;
      if (currentQty + 1 > currentStock) {
        return false;
      }
    }

    if (itemIndex != -1) {
      items[itemIndex] = CartItemModel(
        item: item,
        quantity: items[itemIndex].quantity + 1,
      );
    } else {
      items.add(CartItemModel(item: item));
    }

    bills[billIndex] = bills[billIndex].copyWith(items: items);
    state = ActiveBillsState(bills: bills, selectedBillId: state.selectedBillId);
    return true;
  }

  void removeItem(ItemModel item) {
    final bills = [...state.bills];
    final billIndex = bills.indexWhere((b) => b.id == state.selectedBillId);
    if (billIndex == -1) return;

    final items = [...bills[billIndex].items];
    final itemIndex = items.indexWhere((i) => i.item.id == item.id);

    if (itemIndex != -1) {
      if (items[itemIndex].quantity > 1) {
        items[itemIndex] = CartItemModel(
          item: item,
          quantity: items[itemIndex].quantity - 1,
        );
      } else {
        items.removeAt(itemIndex);
      }
      bills[billIndex] = bills[billIndex].copyWith(items: items);
      state = ActiveBillsState(bills: bills, selectedBillId: state.selectedBillId);
    }
  }

  void holdBill() {
    final bills = [...state.bills];
    final billIndex = bills.indexWhere((b) => b.id == state.selectedBillId);
    if (billIndex != -1) {
      bills[billIndex] = bills[billIndex].copyWith(isHold: true);
      state = ActiveBillsState(bills: bills, selectedBillId: state.selectedBillId);
      // Automatically open a new bill for the next customer
      addBill();
    }
  }

  Future<void> markPaid(String paymentMethod, {String? phone}) async {
    final bills = [...state.bills];
    final billIndex = bills.indexWhere((b) => b.id == state.selectedBillId);
    if (billIndex != -1) {
      bills[billIndex] = bills[billIndex].copyWith(
        isPaid: true, 
        paymentMethod: paymentMethod,
        customerPhone: phone,
      );
      state = ActiveBillsState(bills: bills, selectedBillId: state.selectedBillId);
      
      // Auto-complete the bill since it is now paid (Quick Cash behavior)
      await completeBill();
    }
  }

  void setCustomerPhone(String phone) {
    final bills = [...state.bills];
    final billIndex = bills.indexWhere((b) => b.id == state.selectedBillId);
    if (billIndex != -1) {
      bills[billIndex] = bills[billIndex].copyWith(customerPhone: phone);
      state = ActiveBillsState(bills: bills, selectedBillId: state.selectedBillId);
    }
  }

  Future<OrderModel?> completeBill({String? paymentMethod, String? phone}) async {
    final bill = state.selectedBill;
    if (bill.items.isEmpty) return null;

    final finalPaymentMethod = paymentMethod ?? bill.paymentMethod;
    final finalPhone = phone ?? bill.customerPhone;

    // Deduct stock if Pro plan is active
    final subscription = ref.read(subscriptionProvider);
    final bool isProUnlocked = subscription.planName == 'Pro' ||
                               subscription.planName == 'Enterprise' ||
                               subscription.planName == 'Free Trial';

    if (isProUnlocked) {
      final updatedItems = <ItemModel>[];
      final stockUpdates = <String, double>{};

      for (final cartItem in bill.items) {
        final item = cartItem.item;
        if (item.trackStock) {
          final currentStock = item.stockCount ?? 0.0;
          final newStock = (currentStock - cartItem.quantity).clamp(0.0, double.infinity);
          final updatedItem = item.copyWith(
            stockCount: newStock,
          );
          updatedItems.add(updatedItem);
          stockUpdates[item.id] = cartItem.quantity.toDouble();
        }
      }

      if (stockUpdates.isNotEmpty) {
        try {
          // Deduct stock transactionally on Firestore first
          await _billingRepository.deductStockTransactionally(stockUpdates);

          // Once Firestore succeeds, update local Hive box and Riverpod state
          for (final updatedItem in updatedItems) {
            await ref.read(itemsProvider.notifier).updateItemLocal(updatedItem);
          }
        } catch (e) {
          // Offline fallback: update local Hive directly so checkout completes successfully offline
          for (final updatedItem in updatedItems) {
            await ref.read(itemsProvider.notifier).updateItemLocal(updatedItem);
            try {
              await _billingRepository.saveItem(updatedItem);
            } catch (_) {}
          }
        }
      }
    }

    // 1. Save to Reports Box
    final order = OrderModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      tokenNumber: ref.read(tokenProvider),
      items: bill.items,
      total: bill.total,
      timestamp: DateTime.now(),
      paymentMethod: finalPaymentMethod,
      customerPhone: finalPhone,
    );
    
    final box = Hive.box<OrderModel>('orders_box');
    await box.add(order);

    // Sync with Firestore
    try {
      await _billingRepository.saveOrder(order);
    } catch (e) {
      // Local remains safe
    }

    // 2. Increment Token
    ref.read(tokenProvider.notifier).increment();

    // 3. Clear and Reset
    removeBill(bill.id);
    
    // After removing/clearing, ensure a fresh bill is available with the updated token name
    final nextToken = ref.read(tokenProvider);
    if (state.bills.length == 1 && state.bills.first.items.isEmpty) {
      final bills = [...state.bills];
      bills[0] = bills[0].copyWith(name: 'Token $nextToken');
      state = ActiveBillsState(bills: bills, selectedBillId: bills[0].id);
    } else if (state.bills.isEmpty) {
      addBill(name: 'Token $nextToken');
    }

    return order;
  }

  void clearCurrentBill() {
    final bills = [...state.bills];
    final billIndex = bills.indexWhere((b) => b.id == state.selectedBillId);
    if (billIndex != -1) {
      bills[billIndex] = bills[billIndex].copyWith(items: []);
      state = ActiveBillsState(bills: bills, selectedBillId: state.selectedBillId);
    }
  }
}

class TokenNotifier extends StateNotifier<int> {
  final Ref ref;
  TokenNotifier(this.ref) : super(1) {
    _init();
  }

  void _init() {
    final box = Hive.box('settings_box');
    final today = DateTime.now().toIso8601String().split('T')[0];
    final lastDate = box.get('last_token_date') as String?;
    
    // Get start number from shop settings
    final shop = ref.read(shopProvider).shop;
    final startNum = shop?.tokenStartNumber ?? 1;

    if (lastDate == null || lastDate != today) {
      // New day or first run, reset token
      state = startNum;
      box.put('current_token', state);
      box.put('last_token_date', today);
    } else {
      // Same day, load persisted token
      state = box.get('current_token', defaultValue: startNum);
    }
  }

  void increment() {
    state++;
    final box = Hive.box('settings_box');
    box.put('current_token', state);
    
    // Ensure date is updated in case they stay open past midnight
    final today = DateTime.now().toIso8601String().split('T')[0];
    box.put('last_token_date', today);
  }

  void reset(int startNumber) {
    state = startNumber;
    final box = Hive.box('settings_box');
    box.put('current_token', state);
    final today = DateTime.now().toIso8601String().split('T')[0];
    box.put('last_token_date', today);
  }
}

final tokenProvider = StateNotifierProvider<TokenNotifier, int>((ref) {
  return TokenNotifier(ref);
});
