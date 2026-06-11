import 'package:flutter_riverpod/flutter_riverpod.dart';

final subscriptionProvider = StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
  return SubscriptionNotifier();
});

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  SubscriptionNotifier() : super(SubscriptionState.active()); // Default to active for demo

  void checkStatus() {
    // In a real app, verify with backend API
  }

  void renewPlan(String planName, int days) {
    state = SubscriptionState(
      isActive: true,
      expiryDate: DateTime.now().add(Duration(days: days)),
      planName: planName,
    );
  }
}

class SubscriptionState {
  final bool isActive;
  final DateTime? expiryDate;
  final String planName;

  SubscriptionState({
    required this.isActive,
    this.expiryDate,
    this.planName = 'Basic Plan',
  });

  factory SubscriptionState.active() => SubscriptionState(
        isActive: true,
        expiryDate: DateTime.now().add(const Duration(days: 30)),
      );

  factory SubscriptionState.expired() => SubscriptionState(isActive: false);
}
