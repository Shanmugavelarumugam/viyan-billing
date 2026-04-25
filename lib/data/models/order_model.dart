import 'package:hive/hive.dart';
import 'item_model.dart';

part 'order_model.g.dart';

@HiveType(typeId: 3)
class OrderModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final int tokenNumber;

  @HiveField(2)
  final List<CartItemModel> items;

  @HiveField(3)
  final double total;

  @HiveField(4)
  final DateTime timestamp;

  @HiveField(5)
  final String paymentMethod; // Cash, UPI

  @HiveField(6)
  final String status; // Completed, Cancelled

  @HiveField(7)
  final String? customerPhone;

  OrderModel({
    required this.id,
    required this.tokenNumber,
    required this.items,
    required this.total,
    required this.timestamp,
    required this.paymentMethod,
    this.status = 'Completed',
    this.customerPhone,
  });
}
