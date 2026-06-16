import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../models/printer_settings_model.dart';
import '../services/printer_service.dart';

// ── Provider for the printer service ──────────────────────────────────────────

final printerServiceProvider = Provider<IPrinterService>((ref) {
  return BluetoothPrinterService();
});

// ── State class ───────────────────────────────────────────────────────────────

class PrinterSettingsState {
  final PrinterSettingsModel settings;
  final PrinterConnectionStatus connectionStatus;
  final String? connectedDeviceName;
  final String? connectedDeviceAddress;
  final int? batteryLevel;
  final List<PrinterDevice> availableDevices;
  final bool isScanning;
  final bool isConnecting;
  final bool isTestPrinting;
  final String? testPrintMessage;
  final String? errorMessage;
  final bool isLoaded;

  const PrinterSettingsState({
    required this.settings,
    this.connectionStatus = PrinterConnectionStatus.disconnected,
    this.connectedDeviceName,
    this.connectedDeviceAddress,
    this.batteryLevel,
    this.availableDevices = const [],
    this.isScanning = false,
    this.isConnecting = false,
    this.isTestPrinting = false,
    this.testPrintMessage,
    this.errorMessage,
    this.isLoaded = false,
  });

  factory PrinterSettingsState.initial() => PrinterSettingsState(
        settings: PrinterSettingsModel(),
      );

  PrinterSettingsState copyWith({
    PrinterSettingsModel? settings,
    PrinterConnectionStatus? connectionStatus,
    String? connectedDeviceName,
    String? connectedDeviceAddress,
    int? batteryLevel,
    List<PrinterDevice>? availableDevices,
    bool? isScanning,
    bool? isConnecting,
    bool? isTestPrinting,
    String? testPrintMessage,
    String? errorMessage,
    bool? isLoaded,
    bool clearConnection = false,
    bool clearTestPrint = false,
    bool clearError = false,
  }) {
    return PrinterSettingsState(
      settings: settings ?? this.settings,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      connectedDeviceName:
          clearConnection ? null : (connectedDeviceName ?? this.connectedDeviceName),
      connectedDeviceAddress:
          clearConnection ? null : (connectedDeviceAddress ?? this.connectedDeviceAddress),
      batteryLevel: clearConnection ? null : (batteryLevel ?? this.batteryLevel),
      availableDevices: availableDevices ?? this.availableDevices,
      isScanning: isScanning ?? this.isScanning,
      isConnecting: isConnecting ?? this.isConnecting,
      isTestPrinting: isTestPrinting ?? this.isTestPrinting,
      testPrintMessage: clearTestPrint ? null : (testPrintMessage ?? this.testPrintMessage),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class PrinterSettingsNotifier extends StateNotifier<PrinterSettingsState> {
  final IPrinterService _service;

  PrinterSettingsNotifier(this._service)
      : super(PrinterSettingsState.initial()) {
    _loadSettings();
    _service.onConnectionStatusChanged.addListener(_onConnectionChanged);
  }

  @override
  void dispose() {
    _service.onConnectionStatusChanged.removeListener(_onConnectionChanged);
    super.dispose();
  }

  void _onConnectionChanged() {
    state = state.copyWith(
      connectionStatus: _service.onConnectionStatusChanged.value,
    );
  }

  // ── Persistence ─────────────────────────────────────────────────────────────

  Future<void> _loadSettings() async {
    try {
      final box = await Hive.openBox<PrinterSettingsModel>('printer_box');
      final saved = box.get('settings');
      if (saved != null) {
        state = state.copyWith(settings: saved, isLoaded: true);
      } else {
        final defaults = PrinterSettingsModel();
        await box.put('settings', defaults);
        state = state.copyWith(settings: defaults, isLoaded: true);
      }
    } catch (e) {
      state = state.copyWith(
        isLoaded: true,
        errorMessage: 'Failed to load printer settings: $e',
      );
    }
  }

  Future<void> _saveSettings(PrinterSettingsModel settings) async {
    try {
      final box = Hive.box<PrinterSettingsModel>('printer_box');
      await box.put('settings', settings);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to save settings: $e');
    }
  }

  // ── Settings mutations ──────────────────────────────────────────────────────

  Future<void> updatePrinterType(PrinterType type) async {
    final updated = state.settings.copyWith(printerType: type);
    state = state.copyWith(settings: updated, clearConnection: true);
    await _saveSettings(updated);
  }

  Future<void> updatePaperWidth(int widthMM) async {
    final updated = state.settings.copyWith(paperWidthMM: widthMM);
    state = state.copyWith(settings: updated);
    await _saveSettings(updated);
  }

  Future<void> toggleSetting({
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
  }) async {
    final updated = state.settings.copyWith(
      showStoreLogo: showStoreLogo,
      showGstNumber: showGstNumber,
      showPhoneNumber: showPhoneNumber,
      showQrPayment: showQrPayment,
      showCustomerDetails: showCustomerDetails,
      printThankYouMessage: printThankYouMessage,
      printDuplicateCopy: printDuplicateCopy,
      autoPrintAfterSale: autoPrintAfterSale,
      askBeforePrinting: askBeforePrinting,
      autoReconnectPrinter: autoReconnectPrinter,
      autoOpenCashDrawer: autoOpenCashDrawer,
    );
    state = state.copyWith(settings: updated);
    await _saveSettings(updated);
  }

  // ── Scanner ─────────────────────────────────────────────────────────────────

  Future<void> scanDevices() async {
    state = state.copyWith(isScanning: true, errorMessage: null);
    try {
      final devices = await _service.scan(type: state.settings.printerType);
      state = state.copyWith(
        availableDevices: devices,
        isScanning: false,
      );
    } catch (e) {
      state = state.copyWith(
        isScanning: false,
        errorMessage: 'Scan failed: $e',
      );
    }
  }

  // ── Connection ──────────────────────────────────────────────────────────────

  Future<void> connectToDevice(PrinterDevice device) async {
    state = state.copyWith(isConnecting: true, errorMessage: null);
    try {
      final success = await _service.connect(device);
      if (success) {
        final battery = await _service.getBatteryLevel(device.address);
        final updated = state.settings.copyWith(
          selectedPrinterAddress: device.address,
          selectedPrinterName: device.name,
        );
        await _saveSettings(updated);
        state = state.copyWith(
          settings: updated,
          isConnecting: false,
          connectedDeviceName: device.name,
          connectedDeviceAddress: device.address,
          batteryLevel: battery,
          connectionStatus: PrinterConnectionStatus.connected,
        );
      } else {
        state = state.copyWith(
          isConnecting: false,
          errorMessage: 'Failed to connect to ${device.name}',
          connectionStatus: PrinterConnectionStatus.error,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isConnecting: false,
        errorMessage: 'Connection failed: $e',
        connectionStatus: PrinterConnectionStatus.error,
      );
    }
  }

  Future<void> disconnectPrinter() async {
    try {
      await _service.disconnect();
      state = state.copyWith(
        clearConnection: true,
        connectionStatus: PrinterConnectionStatus.disconnected,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: 'Disconnect failed: $e');
    }
  }

  Future<void> reconnectPrinter() async {
    final address = state.connectedDeviceAddress;
    if (address == null) {
      state = state.copyWith(errorMessage: 'No previously connected printer');
      return;
    }
    // Find device by address in available list or create a temp device
    final device = state.availableDevices.where((d) => d.address == address).firstOrNull;
    if (device != null) {
      await connectToDevice(device);
    } else {
      state = state.copyWith(
        errorMessage: 'Printer not found. Scan again.',
      );
    }
  }

  // ── Test print ──────────────────────────────────────────────────────────────

  Future<void> printTestReceipt() async {
    state = state.copyWith(
      isTestPrinting: true,
      clearTestPrint: true,
      errorMessage: null,
    );
    try {
      final storeName = 'Viyan Store';
      final success = await _service.printTestReceipt(
        storeName: storeName,
        paperWidthMM: state.settings.paperWidthMM,
      );
      state = state.copyWith(
        isTestPrinting: false,
        testPrintMessage: success
            ? 'Test receipt printed successfully!'
            : 'Print failed. Check printer connection.',
        errorMessage: success ? null : 'Print failed',
      );
    } catch (e) {
      state = state.copyWith(
        isTestPrinting: false,
        errorMessage: 'Test print error: $e',
      );
    }
  }

  // ── Troubleshooting actions ─────────────────────────────────────────────────

  Future<void> forgetDevice() async {
    try {
      await _service.disconnect();
      final updated = state.settings.copyWith(clearPrinter: true);
      await _saveSettings(updated);
      state = state.copyWith(
        settings: updated,
        clearConnection: true,
        availableDevices: [],
        connectionStatus: PrinterConnectionStatus.disconnected,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to forget device: $e');
    }
  }

  Future<void> resetAllSettings() async {
    try {
      await _service.disconnect();
      final defaults = PrinterSettingsModel();
      await _saveSettings(defaults);
      state = state.copyWith(
        settings: defaults,
        clearConnection: true,
        availableDevices: [],
        connectionStatus: PrinterConnectionStatus.disconnected,
        errorMessage: null,
        clearTestPrint: true,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to reset settings: $e');
    }
  }

  void dismissError() {
    state = state.copyWith(clearError: true);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final printerSettingsProvider =
    StateNotifierProvider<PrinterSettingsNotifier, PrinterSettingsState>((ref) {
  final service = ref.watch(printerServiceProvider);
  return PrinterSettingsNotifier(service);
});
