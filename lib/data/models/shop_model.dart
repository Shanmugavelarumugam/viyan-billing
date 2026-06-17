import 'package:hive/hive.dart';

part 'shop_model.g.dart';

@HiveType(typeId: 0)
class ShopModel extends HiveObject {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final String? upiId;

  @HiveField(2)
  final String? address;

  @HiveField(3)
  final String? email;

  @HiveField(4)
  final String? language; // 'en' or 'ta'

  @HiveField(5)
  final String? ownerName;

  @HiveField(6)
  final String? shopType; // 'Tea Shop', 'Food Truck', etc.

  @HiveField(7)
  final String? currency; // Default to '₹'

  @HiveField(8)
  final int? tokenStartNumber; // Default to 1

  @HiveField(9)
  final bool? isCashEnabled;

  @HiveField(10)
  final bool? isUpiEnabled;

  @HiveField(11)
  final String? qrImageUrl;

  @HiveField(12)
  final DateTime? lastBackupTime;

  @HiveField(13)
  final String? subscriptionPlan;

  @HiveField(14)
  final DateTime? subscriptionExpiry;

  @HiveField(15)
  final String? profilePhotoPath;

  @HiveField(16)
  final String? phone;

  @HiveField(17)
  final String? gstNumber;

  @HiveField(18)
  final String? logoPath;

  ShopModel({
    required this.name,
    this.upiId,
    this.address,
    this.email,
    String? language,
    this.ownerName,
    this.shopType,
    String? currency,
    int? tokenStartNumber,
    bool? isCashEnabled,
    bool? isUpiEnabled,
    this.qrImageUrl,
    this.lastBackupTime,
    String? subscriptionPlan,
    this.subscriptionExpiry,
    this.profilePhotoPath,
    this.phone,
    this.gstNumber,
    this.logoPath,
  })  : language = language ?? 'ta',
        currency = currency ?? '₹',
        tokenStartNumber = tokenStartNumber ?? 1,
        isCashEnabled = isCashEnabled ?? true,
        isUpiEnabled = isUpiEnabled ?? true,
        subscriptionPlan = subscriptionPlan ?? 'Free Trial';

  ShopModel copyWith({
    String? name,
    String? upiId,
    String? address,
    String? email,
    String? language,
    String? ownerName,
    String? shopType,
    String? currency,
    int? tokenStartNumber,
    bool? isCashEnabled,
    bool? isUpiEnabled,
    String? qrImageUrl,
    DateTime? lastBackupTime,
    String? subscriptionPlan,
    DateTime? subscriptionExpiry,
    String? profilePhotoPath,
    String? phone,
    String? gstNumber,
    String? logoPath,
  }) {
    return ShopModel(
      name: name ?? this.name,
      upiId: upiId ?? this.upiId,
      address: address ?? this.address,
      email: email ?? this.email,
      language: language ?? this.language,
      ownerName: ownerName ?? this.ownerName,
      shopType: shopType ?? this.shopType,
      currency: currency ?? this.currency,
      tokenStartNumber: tokenStartNumber ?? this.tokenStartNumber,
      isCashEnabled: isCashEnabled ?? this.isCashEnabled,
      isUpiEnabled: isUpiEnabled ?? this.isUpiEnabled,
      qrImageUrl: qrImageUrl ?? this.qrImageUrl,
      lastBackupTime: lastBackupTime ?? this.lastBackupTime,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
      profilePhotoPath: profilePhotoPath ?? this.profilePhotoPath,
      phone: phone ?? this.phone,
      gstNumber: gstNumber ?? this.gstNumber,
      logoPath: logoPath ?? this.logoPath,
    );
  }
}
