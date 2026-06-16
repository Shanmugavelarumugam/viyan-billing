import 'package:hive/hive.dart';

enum PrinterType {
  bluetooth,
  usb,
  wifi,
  a4;

  String get label {
    switch (this) {
      case PrinterType.bluetooth:
        return 'Bluetooth Thermal Printer';
      case PrinterType.usb:
        return 'USB Thermal Printer';
      case PrinterType.wifi:
        return 'WiFi / Network Printer';
      case PrinterType.a4:
        return 'A4 Printer';
    }
  }

  String get iconLabel {
    switch (this) {
      case PrinterType.bluetooth:
        return 'bluetooth';
      case PrinterType.usb:
        return 'usb';
      case PrinterType.wifi:
        return 'wifi';
      case PrinterType.a4:
        return 'a4';
    }
  }
}

@HiveType(typeId: 4)
class PrinterSettingsModel extends HiveObject {
  @HiveField(0)
  final PrinterType printerType;

  @HiveField(1)
  final int paperWidthMM;

  @HiveField(2)
  final bool showStoreLogo;

  @HiveField(3)
  final bool showGstNumber;

  @HiveField(4)
  final bool showPhoneNumber;

  @HiveField(5)
  final bool showQrPayment;

  @HiveField(6)
  final bool showCustomerDetails;

  @HiveField(7)
  final bool printThankYouMessage;

  @HiveField(8)
  final bool printDuplicateCopy;

  @HiveField(9)
  final bool autoPrintAfterSale;

  @HiveField(10)
  final bool askBeforePrinting;

  @HiveField(11)
  final bool autoReconnectPrinter;

  @HiveField(12)
  final bool autoOpenCashDrawer;

  @HiveField(13)
  final String? selectedPrinterAddress;

  @HiveField(14)
  final String? selectedPrinterName;

  PrinterSettingsModel({
    this.printerType = PrinterType.bluetooth,
    this.paperWidthMM = 58,
    this.showStoreLogo = true,
    this.showGstNumber = true,
    this.showPhoneNumber = true,
    this.showQrPayment = true,
    this.showCustomerDetails = true,
    this.printThankYouMessage = true,
    this.printDuplicateCopy = false,
    this.autoPrintAfterSale = true,
    this.askBeforePrinting = false,
    this.autoReconnectPrinter = true,
    this.autoOpenCashDrawer = false,
    this.selectedPrinterAddress,
    this.selectedPrinterName,
  });

  PrinterSettingsModel copyWith({
    PrinterType? printerType,
    int? paperWidthMM,
    bool? showStoreLogo,
    bool? showGstNumber,
    bool? showPhoneNumber,
    bool? showQrPayment,
    bool? showCustomerDetails,
    bool? printThankYouMessage,
    bool? printDuplicateCopy,
    bool? autoPrintAfterSale,
    bool? askBeforePrinting,
    bool? autoReconnectPrinter,
    bool? autoOpenCashDrawer,
    String? selectedPrinterAddress,
    String? selectedPrinterName,
    bool clearPrinter = false,
  }) {
    return PrinterSettingsModel(
      printerType: printerType ?? this.printerType,
      paperWidthMM: paperWidthMM ?? this.paperWidthMM,
      showStoreLogo: showStoreLogo ?? this.showStoreLogo,
      showGstNumber: showGstNumber ?? this.showGstNumber,
      showPhoneNumber: showPhoneNumber ?? this.showPhoneNumber,
      showQrPayment: showQrPayment ?? this.showQrPayment,
      showCustomerDetails: showCustomerDetails ?? this.showCustomerDetails,
      printThankYouMessage: printThankYouMessage ?? this.printThankYouMessage,
      printDuplicateCopy: printDuplicateCopy ?? this.printDuplicateCopy,
      autoPrintAfterSale: autoPrintAfterSale ?? this.autoPrintAfterSale,
      askBeforePrinting: askBeforePrinting ?? this.askBeforePrinting,
      autoReconnectPrinter: autoReconnectPrinter ?? this.autoReconnectPrinter,
      autoOpenCashDrawer: autoOpenCashDrawer ?? this.autoOpenCashDrawer,
      selectedPrinterAddress: clearPrinter ? null : (selectedPrinterAddress ?? this.selectedPrinterAddress),
      selectedPrinterName: clearPrinter ? null : (selectedPrinterName ?? this.selectedPrinterName),
    );
  }

  Map<String, dynamic> toJson() => {
        'printerType': printerType.index,
        'paperWidthMM': paperWidthMM,
        'showStoreLogo': showStoreLogo,
        'showGstNumber': showGstNumber,
        'showPhoneNumber': showPhoneNumber,
        'showQrPayment': showQrPayment,
        'showCustomerDetails': showCustomerDetails,
        'printThankYouMessage': printThankYouMessage,
        'printDuplicateCopy': printDuplicateCopy,
        'autoPrintAfterSale': autoPrintAfterSale,
        'askBeforePrinting': askBeforePrinting,
        'autoReconnectPrinter': autoReconnectPrinter,
        'autoOpenCashDrawer': autoOpenCashDrawer,
        'selectedPrinterAddress': selectedPrinterAddress,
        'selectedPrinterName': selectedPrinterName,
      };

  factory PrinterSettingsModel.fromJson(Map<String, dynamic> json) =>
      PrinterSettingsModel(
        printerType: PrinterType.values[json['printerType'] as int? ?? 0],
        paperWidthMM: json['paperWidthMM'] as int? ?? 58,
        showStoreLogo: json['showStoreLogo'] as bool? ?? true,
        showGstNumber: json['showGstNumber'] as bool? ?? true,
        showPhoneNumber: json['showPhoneNumber'] as bool? ?? true,
        showQrPayment: json['showQrPayment'] as bool? ?? true,
        showCustomerDetails: json['showCustomerDetails'] as bool? ?? true,
        printThankYouMessage: json['printThankYouMessage'] as bool? ?? true,
        printDuplicateCopy: json['printDuplicateCopy'] as bool? ?? false,
        autoPrintAfterSale: json['autoPrintAfterSale'] as bool? ?? true,
        askBeforePrinting: json['askBeforePrinting'] as bool? ?? false,
        autoReconnectPrinter: json['autoReconnectPrinter'] as bool? ?? true,
        autoOpenCashDrawer: json['autoOpenCashDrawer'] as bool? ?? false,
        selectedPrinterAddress: json['selectedPrinterAddress'] as String?,
        selectedPrinterName: json['selectedPrinterName'] as String?,
      );
}

class PrinterSettingsModelAdapter extends TypeAdapter<PrinterSettingsModel> {
  @override
  final int typeId = 4;

  @override
  PrinterSettingsModel read(BinaryReader reader) {
    return PrinterSettingsModel(
      printerType: PrinterType.values[reader.readByte()],
      paperWidthMM: reader.readByte(),
      showStoreLogo: reader.readBool(),
      showGstNumber: reader.readBool(),
      showPhoneNumber: reader.readBool(),
      showQrPayment: reader.readBool(),
      showCustomerDetails: reader.readBool(),
      printThankYouMessage: reader.readBool(),
      printDuplicateCopy: reader.readBool(),
      autoPrintAfterSale: reader.readBool(),
      askBeforePrinting: reader.readBool(),
      autoReconnectPrinter: reader.readBool(),
      autoOpenCashDrawer: reader.readBool(),
      selectedPrinterAddress: reader.readString(),
      selectedPrinterName: reader.readString(),
    );
  }

  @override
  void write(BinaryWriter writer, PrinterSettingsModel obj) {
    writer.writeByte(obj.printerType.index);
    writer.writeByte(obj.paperWidthMM);
    writer.writeBool(obj.showStoreLogo);
    writer.writeBool(obj.showGstNumber);
    writer.writeBool(obj.showPhoneNumber);
    writer.writeBool(obj.showQrPayment);
    writer.writeBool(obj.showCustomerDetails);
    writer.writeBool(obj.printThankYouMessage);
    writer.writeBool(obj.printDuplicateCopy);
    writer.writeBool(obj.autoPrintAfterSale);
    writer.writeBool(obj.askBeforePrinting);
    writer.writeBool(obj.autoReconnectPrinter);
    writer.writeBool(obj.autoOpenCashDrawer);
    writer.writeString(obj.selectedPrinterAddress ?? '');
    writer.writeString(obj.selectedPrinterName ?? '');
  }
}
