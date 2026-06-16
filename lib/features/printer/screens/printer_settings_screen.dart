import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/printer_settings_model.dart';
import '../providers/printer_provider.dart';
import '../services/printer_service.dart';

class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends ConsumerState<PrinterSettingsScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = ref.watch(printerSettingsProvider);
    final notifier = ref.read(printerSettingsProvider.notifier);

    return Scaffold(
      appBar: _buildAppBar(cs),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              cs.primary.withValues(alpha: 0.03),
              cs.surface,
              cs.surface,
            ],
          ),
        ),
        child: _buildBody(cs, state, notifier),
      ),
    );
  }

  Widget _buildBody(ColorScheme cs, PrinterSettingsState state, PrinterSettingsNotifier notifier) {
    if (!state.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildStatusCard(cs, state, notifier),
              const SizedBox(height: 12),
              _buildPrinterTypeSection(cs, state, notifier),
              const SizedBox(height: 12),
              _buildAvailablePrintersSection(cs, state, notifier),
              const SizedBox(height: 12),
              _buildPaperWidthSection(cs, state, notifier),
              const SizedBox(height: 12),
              _buildReceiptCustomizationSection(cs, state, notifier),
              const SizedBox(height: 12),
              _buildReceiptPreview(cs, state),
              const SizedBox(height: 12),
              _buildAutoPrintSection(cs, state, notifier),
              const SizedBox(height: 12),
              _buildTestPrintSection(cs, state, notifier),
              const SizedBox(height: 12),
              _buildTroubleshootingSection(cs, state, notifier, context),
            ]),
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar(ColorScheme cs) {
    return AppBar(
      title: const Text('Printer Settings', style: TextStyle(fontWeight: FontWeight.w700)),
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      scrolledUnderElevation: 1,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.pop(context),
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarIconBrightness: cs.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      ),
    );
  }


  // ── Section 1: Printer Status Card ──────────────────────────────────────

  Widget _buildStatusCard(ColorScheme cs, PrinterSettingsState state, PrinterSettingsNotifier notifier) {
    final connected = state.connectionStatus.isConnected;
    final icon = connected ? Icons.check_circle_rounded : Icons.error_outline_rounded;
    final iconColor = connected ? Colors.green : cs.error;
    final statusText = connected ? 'Printer Connected' : 'No Printer Connected';
    final subtitle = connected
        ? (state.connectedDeviceName ?? 'Thermal Printer')
        : 'Configure a printer to start printing receipts';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: iconColor, width: 4),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (connected && state.batteryLevel != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.battery_std_rounded, size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          'Battery: ${state.batteryLevel}%',
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (connected)
              TextButton(
                onPressed: () => notifier.disconnectPrinter(),
                style: TextButton.styleFrom(
                  foregroundColor: cs.error,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 36),
                ),
                child: const Text('Disconnect', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
          ],
        ),
      ),
    );
  }

  // ── Section 2: Printer Type ─────────────────────────────────────────────

  Widget _buildPrinterTypeSection(ColorScheme cs, PrinterSettingsState state, PrinterSettingsNotifier notifier) {
    return _sectionCard(cs, Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sectionHeader(cs, 'Printer Type', Icons.print_rounded),
        const SizedBox(height: 8),
        ...PrinterType.values.map((type) => _radioTile(
          cs,
          value: type,
          groupValue: state.settings.printerType,
          label: type.label,
          subtitle: _printerTypeSubtitle(type),
          leadingIcon: _printerTypeIcon(type),
          onChanged: (t) => notifier.updatePrinterType(t),
        )),
      ],
    ));
  }

  String _printerTypeSubtitle(PrinterType type) {
    switch (type) {
      case PrinterType.bluetooth:
        return 'Wireless connection via Bluetooth';
      case PrinterType.usb:
        return 'Direct USB connection';
      case PrinterType.wifi:
        return 'Network printer over WiFi/LAN';
      case PrinterType.a4:
        return 'Standard A4 document printer';
    }
  }

  IconData _printerTypeIcon(PrinterType type) {
    switch (type) {
      case PrinterType.bluetooth:
        return Icons.bluetooth_rounded;
      case PrinterType.usb:
        return Icons.usb_rounded;
      case PrinterType.wifi:
        return Icons.wifi_rounded;
      case PrinterType.a4:
        return Icons.description_rounded;
    }
  }

  // ── Section 3: Available Printers ───────────────────────────────────────

  Widget _buildAvailablePrintersSection(ColorScheme cs, PrinterSettingsState state, PrinterSettingsNotifier notifier) {
    return _sectionCard(cs, Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _sectionHeader(cs, 'Available Printers', Icons.print_rounded),
            const Spacer(),
            SizedBox(
              height: 34,
              child: TextButton.icon(
                onPressed: state.isScanning ? null : () => notifier.scanDevices(),
                icon: state.isScanning
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.primary,
                        ),
                      )
                    : Icon(Icons.refresh_rounded, size: 16, color: cs.primary),
                label: Text(
                  state.isScanning ? 'Scanning...' : 'Scan',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.primary),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 34),
                ),
              ),
            ),
          ],
        ),
        if (state.availableDevices.isEmpty && !state.isScanning)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.print_disabled_rounded, size: 36, color: cs.outlineVariant),
                  const SizedBox(height: 6),
                  Text(
                    'No printers found',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                  Text(
                    'Tap "Scan" to discover nearby printers',
                    style: TextStyle(fontSize: 12, color: cs.outline),
                  ),
                ],
              ),
            ),
          )
        else
          ...state.availableDevices.map((device) => _printerDeviceTile(cs, device, state, notifier)),
      ],
    ));
  }

  Widget _printerDeviceTile(ColorScheme cs, PrinterDevice device, PrinterSettingsState state, PrinterSettingsNotifier notifier) {
    final isConnected = device.address == state.connectedDeviceAddress && state.connectionStatus.isConnected;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Card(
        elevation: 0,
        color: isConnected ? Colors.green.withValues(alpha: 0.06) : cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isConnected
              ? BorderSide(color: Colors.green, width: 1)
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.print_rounded, size: 22, color: cs.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      device.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      device.address,
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isConnected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Connected',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green.shade700),
                  ),
                )
              else
                SizedBox(
                  width: 90,
                  height: 32,
                  child: ElevatedButton(
                    onPressed: state.isConnecting
                        ? null
                        : () => notifier.connectToDevice(device),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    child: state.isConnecting && state.connectedDeviceAddress == device.address
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.onPrimary,
                            ),
                          )
                        : const Text('Connect'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section 4: Paper Width ──────────────────────────────────────────────

  Widget _buildPaperWidthSection(ColorScheme cs, PrinterSettingsState state, PrinterSettingsNotifier notifier) {
    return _sectionCard(cs, Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sectionHeader(cs, 'Paper Width', Icons.straighten_rounded),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _radioTile(
              cs,
              value: 58,
              groupValue: state.settings.paperWidthMM,
              label: '58 mm',
              subtitle: 'Standard thermal roll',
              leadingIcon: Icons.receipt_long_rounded,
              onChanged: (v) => notifier.updatePaperWidth(v),
            )),
            const SizedBox(width: 8),
            Expanded(child: _radioTile(
              cs,
              value: 80,
              groupValue: state.settings.paperWidthMM,
              label: '80 mm',
              subtitle: 'Wide format',
              leadingIcon: Icons.receipt_rounded,
              onChanged: (v) => notifier.updatePaperWidth(v),
            )),
          ],
        ),
      ],
    ));
  }

  // ── Section 5: Receipt Customization ────────────────────────────────────

  Widget _buildReceiptCustomizationSection(ColorScheme cs, PrinterSettingsState state, PrinterSettingsNotifier notifier) {
    final s = state.settings;
    return _sectionCard(cs, Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sectionHeader(cs, 'Receipt Customization', Icons.tune_rounded),
        const SizedBox(height: 4),
        _toggleTile(cs, 'Show Store Logo', s.showStoreLogo, (v) => notifier.toggleSetting(showStoreLogo: v)),
        _divider(cs),
        _toggleTile(cs, 'Show GST Number', s.showGstNumber, (v) => notifier.toggleSetting(showGstNumber: v)),
        _divider(cs),
        _toggleTile(cs, 'Show Phone Number', s.showPhoneNumber, (v) => notifier.toggleSetting(showPhoneNumber: v)),
        _divider(cs),
        _toggleTile(cs, 'Show QR Payment', s.showQrPayment, (v) => notifier.toggleSetting(showQrPayment: v)),
        _divider(cs),
        _toggleTile(cs, 'Show Customer Details', s.showCustomerDetails, (v) => notifier.toggleSetting(showCustomerDetails: v)),
        _divider(cs),
        _toggleTile(cs, 'Print Thank You Message', s.printThankYouMessage, (v) => notifier.toggleSetting(printThankYouMessage: v)),
        _divider(cs),
        _toggleTile(cs, 'Print Duplicate Copy', s.printDuplicateCopy, (v) => notifier.toggleSetting(printDuplicateCopy: v)),
      ],
    ));
  }

  // ── Section 6: Receipt Preview ──────────────────────────────────────────

  Widget _buildReceiptPreview(ColorScheme cs, PrinterSettingsState state) {
    final s = state.settings;
    final isNarrow = s.paperWidthMM == 58;
    final receiptWidth = isNarrow ? 220.0 : 280.0;

    return _sectionCard(cs, Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _sectionHeader(cs, 'Receipt Preview', Icons.article_rounded),
            const Spacer(),
            Text(
              '${s.paperWidthMM}mm',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.primary),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Center(
          child: Container(
            width: receiptWidth,
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (s.showStoreLogo) ...[
                  Icon(Icons.store_rounded, size: 22, color: Colors.black87),
                  const SizedBox(height: 2),
                ],
                Text(
                  'Viyan Store',
                  style: TextStyle(
                    fontSize: isNarrow ? 12 : 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                if (s.showGstNumber) ...[
                  const SizedBox(height: 1),
                  Text(
                    'GST: 33ABCDE1234F1Z5',
                    style: TextStyle(fontSize: isNarrow ? 8 : 9, color: Colors.black54),
                  ),
                ],
                if (s.showPhoneNumber) ...[
                  const SizedBox(height: 1),
                  Text(
                    'Phone: +91 98765 43210',
                    style: TextStyle(fontSize: isNarrow ? 8 : 9, color: Colors.black54),
                  ),
                ],
                const SizedBox(height: 8),
                _receiptDivider(isNarrow),
                const SizedBox(height: 6),
                _receiptLine('Item A x1', '₹50', isNarrow),
                const SizedBox(height: 2),
                _receiptLine('Item B x2', '₹100', isNarrow),
                const SizedBox(height: 2),
                _receiptLine('Item C x3', '₹75', isNarrow),
                const SizedBox(height: 6),
                _receiptDivider(isNarrow),
                const SizedBox(height: 4),
                _receiptLine('TOTAL', '₹225', isNarrow, bold: true),
                if (s.showCustomerDetails) ...[
                  const SizedBox(height: 6),
                  _receiptDivider(isNarrow),
                  const SizedBox(height: 4),
                  Text(
                    'Customer: Rahul Kumar\nPhone: +91 98765 43210',
                    style: TextStyle(fontSize: isNarrow ? 7 : 8, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (s.printThankYouMessage) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Thank You, Visit Again!',
                    style: TextStyle(
                      fontSize: isNarrow ? 9 : 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (s.showQrPayment) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(Icons.qr_code_rounded, size: 24, color: Colors.black54),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    ));
  }

  Widget _receiptDivider(bool isNarrow) {
    return Container(
      height: 1,
      color: Colors.black.withValues(alpha: 0.15),
      margin: EdgeInsets.symmetric(horizontal: isNarrow ? 4 : 8),
    );
  }

  Widget _receiptLine(String label, String price, bool isNarrow, {bool bold = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isNarrow ? 4 : 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isNarrow ? 9 : 10,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          Text(
            price,
            style: TextStyle(
              fontSize: isNarrow ? 9 : 10,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ── Section 7: Auto Print Settings ──────────────────────────────────────

  Widget _buildAutoPrintSection(ColorScheme cs, PrinterSettingsState state, PrinterSettingsNotifier notifier) {
    final s = state.settings;
    return _sectionCard(cs, Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sectionHeader(cs, 'Auto Print Settings', Icons.settings_rounded),
        const SizedBox(height: 4),
        _toggleTile(cs, 'Auto Print After Sale', s.autoPrintAfterSale, (v) => notifier.toggleSetting(autoPrintAfterSale: v)),
        _divider(cs),
        _toggleTile(cs, 'Ask Before Printing', s.askBeforePrinting, (v) => notifier.toggleSetting(askBeforePrinting: v)),
        _divider(cs),
        _toggleTile(cs, 'Auto Reconnect Printer', s.autoReconnectPrinter, (v) => notifier.toggleSetting(autoReconnectPrinter: v)),
        _divider(cs),
        _toggleTile(cs, 'Auto Open Cash Drawer', s.autoOpenCashDrawer, (v) => notifier.toggleSetting(autoOpenCashDrawer: v)),
      ],
    ));
  }

  // ── Section 8: Test Printing ────────────────────────────────────────────

  Widget _buildTestPrintSection(ColorScheme cs, PrinterSettingsState state, PrinterSettingsNotifier notifier) {
    return _sectionCard(cs, Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sectionHeader(cs, 'Test Printing', Icons.print_rounded),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: state.isTestPrinting || !state.connectionStatus.isConnected
                ? null
                : () => notifier.printTestReceipt(),
            icon: state.isTestPrinting
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.onPrimary,
                    ),
                  )
                : const Icon(Icons.print_rounded, size: 20),
            label: Text(
              state.isTestPrinting ? 'Printing...' : 'Print Test Receipt',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        if (state.testPrintMessage != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: (state.testPrintMessage?.contains('success') ?? false)
                  ? Colors.green.withValues(alpha: 0.08)
                  : cs.errorContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  (state.testPrintMessage?.contains('success') ?? false)
                      ? Icons.check_circle_rounded
                      : Icons.error_outline_rounded,
                  size: 18,
                  color: (state.testPrintMessage?.contains('success') ?? false)
                      ? Colors.green
                      : cs.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.testPrintMessage!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: (state.testPrintMessage?.contains('success') ?? false)
                          ? Colors.green.shade800
                          : cs.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ));
  }

  // ── Section 9: Troubleshooting ─────────────────────────────────────────

  Widget _buildTroubleshootingSection(ColorScheme cs, PrinterSettingsState state, PrinterSettingsNotifier notifier, BuildContext context) {
    return _sectionCard(cs, Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sectionHeader(cs, 'Troubleshooting', Icons.help_outline_rounded),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _troubleshootButton(
              cs,
              icon: Icons.refresh_rounded,
              label: 'Reconnect',
              onTap: () => notifier.reconnectPrinter(),
            )),
            const SizedBox(width: 8),
            Expanded(child: _troubleshootButton(
              cs,
              icon: Icons.delete_sweep_rounded,
              label: 'Forget',
              onTap: () => _confirmAction(
                context,
                title: 'Forget Printer?',
                message: 'Remove this printer from saved devices.',
                onConfirm: () => notifier.forgetDevice(),
              ),
            )),
            const SizedBox(width: 8),
            Expanded(child: _troubleshootButton(
              cs,
              icon: Icons.restart_alt_rounded,
              label: 'Reset',
              onTap: () => _confirmAction(
                context,
                title: 'Reset Printer Settings?',
                message: 'All printer settings will be restored to defaults.',
                onConfirm: () => notifier.resetAllSettings(),
              ),
            )),
          ],
        ),
        if (state.errorMessage != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.errorContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, size: 18, color: cs.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.errorMessage!,
                    style: TextStyle(fontSize: 12, color: cs.error),
                  ),
                ),
                GestureDetector(
                  onTap: () => notifier.dismissError(),
                  child: Icon(Icons.close_rounded, size: 16, color: cs.error),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded, size: 16, color: cs.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Troubleshooting Tips',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _tipRow(cs, Icons.bluetooth_rounded, 'Turn Bluetooth On'),
              const SizedBox(height: 4),
              _tipRow(cs, Icons.battery_charging_full_rounded, 'Keep Printer Charged'),
              const SizedBox(height: 4),
              _tipRow(cs, Icons.wifi_tethering_rounded, 'Stay Within Range (10m)'),
              const SizedBox(height: 4),
              _tipRow(cs, Icons.restart_alt_rounded, 'Restart Printer if Not Responding'),
            ],
          ),
        ),
      ],
    ));
  }

  Widget _troubleshootButton(ColorScheme cs, {required IconData icon, required String label, required VoidCallback onTap}) {
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.onSurface,
          side: BorderSide(color: cs.outlineVariant),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: cs.primary),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _tipRow(ColorScheme cs, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: cs.primary,),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      ],
    );
  }

  Future<void> _confirmAction(BuildContext context, {required String title, required String message, required VoidCallback onConfirm}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: Text(message, style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      onConfirm();
    }
  }

  // ── Shared UI helpers ───────────────────────────────────────────────────

  Widget _sectionCard(ColorScheme cs, Column child) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  Widget _sectionHeader(ColorScheme cs, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _radioTile<T>(
    ColorScheme cs, {
    required T value,
    required T groupValue,
    required String label,
    required String subtitle,
    required IconData leadingIcon,
    required ValueChanged<T> onChanged,
  }) {
    final selected = value == groupValue;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? cs.primaryContainer.withValues(alpha: 0.3) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? cs.primary.withValues(alpha: 0.3) : cs.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Icon(
                leadingIcon,
                size: 20,
                color: selected ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: selected ? cs.primary : cs.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? cs.primary : cs.outline,
                    width: selected ? 6 : 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggleTile(ColorScheme cs, String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider(ColorScheme cs) {
    return Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5), thickness: 0.5);
  }
}
