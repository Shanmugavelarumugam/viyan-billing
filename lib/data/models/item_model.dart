import 'package:hive/hive.dart';

part 'item_model.g.dart';

@HiveType(typeId: 1)
class ItemModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final double price;

  @HiveField(3)
  final String? category;

  @HiveField(4)
  final bool isAvailable;

  @HiveField(5)
  final String? imageUrl;

  @HiveField(6)
  final double? costPrice;

  @HiveField(7)
  final String? barcode;

  @HiveField(8)
  final double? stockCount;

  @HiveField(9)
  final bool trackStock;

  @HiveField(10)
  final int? lowStockThreshold;

  ItemModel({
    required this.id,
    required this.name,
    required this.price,
    this.category,
    this.isAvailable = true,
    this.imageUrl,
    this.costPrice,
    this.barcode,
    this.stockCount = 0.0,
    this.trackStock = false,
    this.lowStockThreshold = 5,
  });

  ItemModel copyWith({
    String? id,
    String? name,
    double? price,
    String? category,
    bool? isAvailable,
    String? imageUrl,
    double? costPrice,
    String? barcode,
    double? stockCount,
    bool? trackStock,
    int? lowStockThreshold,
  }) {
    return ItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      category: category ?? this.category,
      isAvailable: isAvailable ?? this.isAvailable,
      imageUrl: imageUrl ?? this.imageUrl,
      costPrice: costPrice ?? this.costPrice,
      barcode: barcode ?? this.barcode,
      stockCount: stockCount ?? this.stockCount,
      trackStock: trackStock ?? this.trackStock,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
    );
  }
}

@HiveType(typeId: 2)
class CartItemModel {
  @HiveField(0)
  final ItemModel item;

  @HiveField(1)
  int quantity;

  CartItemModel({required this.item, this.quantity = 1});

  double get total => item.price * quantity;
}
