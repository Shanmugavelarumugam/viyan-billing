// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shop_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ShopModelAdapter extends TypeAdapter<ShopModel> {
  @override
  final int typeId = 0;

  @override
  ShopModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ShopModel(
      name: fields[0] as String,
      upiId: fields[1] as String?,
      address: fields[2] as String?,
      email: fields[3] as String?,
      language: fields[4] as String?,
      ownerName: fields[5] as String?,
      shopType: fields[6] as String?,
      currency: fields[7] as String?,
      tokenStartNumber: fields[8] as int?,
      isCashEnabled: fields[9] as bool?,
      isUpiEnabled: fields[10] as bool?,
      qrImageUrl: fields[11] as String?,
      lastBackupTime: fields[12] as DateTime?,
      subscriptionPlan: fields[13] as String?,
      subscriptionExpiry: fields[14] as DateTime?,
      profilePhotoPath: fields[15] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ShopModel obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.upiId)
      ..writeByte(2)
      ..write(obj.address)
      ..writeByte(3)
      ..write(obj.email)
      ..writeByte(4)
      ..write(obj.language)
      ..writeByte(5)
      ..write(obj.ownerName)
      ..writeByte(6)
      ..write(obj.shopType)
      ..writeByte(7)
      ..write(obj.currency)
      ..writeByte(8)
      ..write(obj.tokenStartNumber)
      ..writeByte(9)
      ..write(obj.isCashEnabled)
      ..writeByte(10)
      ..write(obj.isUpiEnabled)
      ..writeByte(11)
      ..write(obj.qrImageUrl)
      ..writeByte(12)
      ..write(obj.lastBackupTime)
      ..writeByte(13)
      ..write(obj.subscriptionPlan)
      ..writeByte(14)
      ..write(obj.subscriptionExpiry)
      ..writeByte(15)
      ..write(obj.profilePhotoPath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShopModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
