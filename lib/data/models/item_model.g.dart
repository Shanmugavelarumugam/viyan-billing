// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'item_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ItemModelAdapter extends TypeAdapter<ItemModel> {
  @override
  final int typeId = 1;

  @override
  ItemModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ItemModel(
      id: fields[0] as String? ?? '',
      name: fields[1] as String? ?? '',
      price: fields[2] as double? ?? 0.0,
      category: fields[3] as String?,
      isAvailable: fields[4] as bool? ?? true,
      imageUrl: fields[5] as String?,
      costPrice: fields[6] as double?,
      barcode: fields[7] as String?,
      stockCount: fields[8] as double?,
      trackStock: fields[9] as bool? ?? false,
      lowStockThreshold: fields[10] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, ItemModel obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.price)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.isAvailable)
      ..writeByte(5)
      ..write(obj.imageUrl)
      ..writeByte(6)
      ..write(obj.costPrice)
      ..writeByte(7)
      ..write(obj.barcode)
      ..writeByte(8)
      ..write(obj.stockCount)
      ..writeByte(9)
      ..write(obj.trackStock)
      ..writeByte(10)
      ..write(obj.lowStockThreshold);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CartItemModelAdapter extends TypeAdapter<CartItemModel> {
  @override
  final int typeId = 2;

  @override
  CartItemModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CartItemModel(
      item: fields[0] as ItemModel,
      quantity: fields[1] as int,
    );
  }

  @override
  void write(BinaryWriter writer, CartItemModel obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.item)
      ..writeByte(1)
      ..write(obj.quantity);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItemModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
