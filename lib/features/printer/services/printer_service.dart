import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../models/printer_settings_model.dart';
import '../../../data/models/order_model.dart';

// ── Data classes ──────────────────────────────────────────────────────────────

class PrinterDevice {
  final String name;
  final String address;
  final PrinterType type;

  const PrinterDevice({
    required this.name,
    required this.address,
    required this.type,
  });
}

// ── Connection status ─────────────────────────────────────────────────────────

enum PrinterConnectionStatus {
  disconnected,
  connecting,
  connected,
  error;

  bool get isConnected => this == PrinterConnectionStatus.connected;
  bool get isDisconnected => this == PrinterConnectionStatus.disconnected;
  bool get isConnecting => this == PrinterConnectionStatus.connecting;
}

// ── Service interface ─────────────────────────────────────────────────────────

abstract class IPrinterService {
  Future<List<PrinterDevice>> scan({required PrinterType type});

  Future<bool> connect(PrinterDevice device);

  Future<void> disconnect();

  Future<bool> printTestReceipt({
    required String storeName,
    required int paperWidthMM,
  });

  Future<bool> printOrder({
    required OrderModel order,
    required PrinterSettingsModel settings,
    String? storeName,
    String? shopPhone,
    String? shopGst,
  });

  Future<int?> getBatteryLevel(String address);

  ValueNotifier<PrinterConnectionStatus> get onConnectionStatusChanged;
}

// ── Production Implementation ────────────────────────────────────────────────

class BluetoothPrinterService implements IPrinterService {
  @override
  final ValueNotifier<PrinterConnectionStatus> onConnectionStatusChanged =
      ValueNotifier(PrinterConnectionStatus.disconnected);

  BluetoothPrinterService() {
    _initConnectionListener();
  }

  void _initConnectionListener() {
    // Periodically check connection status
  }

  Future<bool> _requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      return statuses[Permission.bluetoothScan]?.isGranted == true &&
          statuses[Permission.bluetoothConnect]?.isGranted == true;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final status = await Permission.bluetooth.request();
      return status.isGranted;
    }
    return true;
  }

  @override
  Future<List<PrinterDevice>> scan({required PrinterType type}) async {
    if (type != PrinterType.bluetooth) {
      return _getStubDevicesForType(type);
    }

    final hasPermission = await _requestPermissions();
    if (!hasPermission) {
      throw Exception("Bluetooth permission was denied by the user.");
    }

    final bool isBluetoothEnabled = await PrintBluetoothThermal.bluetoothEnabled;
    if (!isBluetoothEnabled) {
      throw Exception("Bluetooth is disabled. Please turn it on in settings.");
    }

    onConnectionStatusChanged.value = PrinterConnectionStatus.disconnected;

    final List<BluetoothInfo> devices = await PrintBluetoothThermal.pairedBluetooths;
    
    return devices.map((d) => PrinterDevice(
      name: d.name.isNotEmpty ? d.name : "Unnamed Printer",
      address: d.macAdress,
      type: PrinterType.bluetooth,
    )).toList();
  }

  @override
  Future<bool> connect(PrinterDevice device) async {
    onConnectionStatusChanged.value = PrinterConnectionStatus.connecting;
    
    try {
      if (device.type != PrinterType.bluetooth) {
        await Future.delayed(const Duration(milliseconds: 1000));
        onConnectionStatusChanged.value = PrinterConnectionStatus.connected;
        return true;
      }

      final hasPermission = await _requestPermissions();
      if (!hasPermission) {
        throw Exception("Bluetooth permission denied");
      }

      final bool success = await PrintBluetoothThermal.connect(
        macPrinterAddress: device.address,
      );

      if (success) {
        onConnectionStatusChanged.value = PrinterConnectionStatus.connected;
      } else {
        onConnectionStatusChanged.value = PrinterConnectionStatus.error;
      }
      return success;
    } catch (e) {
      onConnectionStatusChanged.value = PrinterConnectionStatus.error;
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect;
    } finally {
      onConnectionStatusChanged.value = PrinterConnectionStatus.disconnected;
    }
  }

  @override
  Future<bool> printTestReceipt({
    required String storeName,
    required int paperWidthMM,
  }) async {
    final bool isConnected = await PrintBluetoothThermal.connectionStatus;
    if (!isConnected && onConnectionStatusChanged.value.isConnected) {
      onConnectionStatusChanged.value = PrinterConnectionStatus.disconnected;
      return false;
    }

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(
        paperWidthMM == 58 ? PaperSize.mm58 : PaperSize.mm80,
        profile,
      );

      List<int> bytes = [];

      bytes += generator.reset();
      bytes += generator.text(
        storeName,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      bytes += generator.text(
        'Thermal Receipt Test',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.feed(1);
      bytes += generator.text(
        'Date: ${DateTime.now().toString().substring(0, 19)}',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.text(
        'Paper Width: ${paperWidthMM}mm',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.feed(2);
      bytes += generator.cut();

      final bool success = await PrintBluetoothThermal.writeBytes(bytes);
      return success;
    } catch (e) {
      debugPrint("Print test receipt error: $e");
      return false;
    }
  }

  @override
  Future<bool> printOrder({
    required OrderModel order,
    required PrinterSettingsModel settings,
    String? storeName,
    String? shopPhone,
    String? shopGst,
  }) async {
    final bool isConnected = await PrintBluetoothThermal.connectionStatus;
    if (!isConnected && onConnectionStatusChanged.value.isConnected) {
      onConnectionStatusChanged.value = PrinterConnectionStatus.disconnected;
      return false;
    }

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(
        settings.paperWidthMM == 58 ? PaperSize.mm58 : PaperSize.mm80,
        profile,
      );

      final printCount = settings.printDuplicateCopy ? 2 : 1;
      
      for (int i = 0; i < printCount; i++) {
        List<int> bytes = [];
        bytes += generator.reset();

        if (settings.showStoreLogo) {
          bytes += generator.text(
            '***',
            styles: const PosStyles(align: PosAlign.center),
          );
        }

        bytes += generator.text(
          storeName ?? 'Viyan Store',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ),
        );

        if (settings.showGstNumber && shopGst != null && shopGst.isNotEmpty) {
          bytes += generator.text(
            'GST: $shopGst',
            styles: const PosStyles(align: PosAlign.center),
          );
        }

        if (settings.showPhoneNumber && shopPhone != null && shopPhone.isNotEmpty) {
          bytes += generator.text(
            'Phone: $shopPhone',
            styles: const PosStyles(align: PosAlign.center),
          );
        }

        bytes += generator.feed(1);
        bytes += generator.text(
          'Token: ${order.tokenNumber}',
          styles: const PosStyles(align: PosAlign.left, bold: true),
        );
        bytes += generator.text(
          'Order ID: ${order.id}',
          styles: const PosStyles(align: PosAlign.left),
        );
        bytes += generator.text(
          'Date: ${order.timestamp.toString().substring(0, 19)}',
          styles: const PosStyles(align: PosAlign.left),
        );

        bytes += generator.feed(1);
        bytes += generator.text(
          '--------------------------------',
          styles: const PosStyles(align: PosAlign.center),
        );

        for (var item in order.items) {
          final qtyAndPrice = '${item.quantity} x ₹${item.item.price.toStringAsFixed(0)}';
          final totalStr = '₹${item.total.toStringAsFixed(0)}';
          bytes += generator.row([
            PosColumn(
              text: item.item.name,
              width: 7,
              styles: const PosStyles(align: PosAlign.left),
            ),
            PosColumn(
              text: qtyAndPrice,
              width: 3,
              styles: const PosStyles(align: PosAlign.right),
            ),
            PosColumn(
              text: totalStr,
              width: 2,
              styles: const PosStyles(align: PosAlign.right, bold: true),
            ),
          ]);
        }

        bytes += generator.text(
          '--------------------------------',
          styles: const PosStyles(align: PosAlign.center),
        );

        bytes += generator.row([
          PosColumn(
            text: 'TOTAL',
            width: 8,
            styles: const PosStyles(align: PosAlign.left, bold: true),
          ),
          PosColumn(
            text: '₹${order.total.toStringAsFixed(0)}',
            width: 4,
            styles: const PosStyles(align: PosAlign.right, bold: true),
          ),
        ]);

        if (settings.showCustomerDetails && order.customerPhone != null && order.customerPhone!.isNotEmpty) {
          bytes += generator.feed(1);
          bytes += generator.text(
            'Customer Phone: ${order.customerPhone}',
            styles: const PosStyles(align: PosAlign.left),
          );
        }

        if (settings.printThankYouMessage) {
          bytes += generator.feed(1);
          bytes += generator.text(
            'Thank You, Visit Again!',
            styles: const PosStyles(align: PosAlign.center),
          );
        }

        if (settings.showQrPayment) {
          bytes += generator.feed(1);
          bytes += generator.qrcode(order.id, size: QRSize.size4);
        }

        bytes += generator.feed(3);
        bytes += generator.cut();

        await PrintBluetoothThermal.writeBytes(bytes);
      }
      return true;
    } catch (e) {
      debugPrint("Print order error: $e");
      return false;
    }
  }

  @override
  Future<int?> getBatteryLevel(String address) async {
    try {
      final level = await PrintBluetoothThermal.batteryLevel;
      return level;
    } catch (_) {
      return null;
    }
  }

  List<PrinterDevice> _getStubDevicesForType(PrinterType type) {
    switch (type) {
      case PrinterType.usb:
        return [
          const PrinterDevice(name: 'USB Thermal Printer (USB#0001)', address: 'usb:0001', type: PrinterType.usb),
        ];
      case PrinterType.wifi:
        return [
          const PrinterDevice(name: 'Network Printer (192.168.1.100)', address: '192.168.1.100:9100', type: PrinterType.wifi),
        ];
      case PrinterType.a4:
        return [
          const PrinterDevice(name: 'HP LaserJet Pro', address: '192.168.1.200:631', type: PrinterType.a4),
        ];
      default:
        return [];
    }
  }
}
