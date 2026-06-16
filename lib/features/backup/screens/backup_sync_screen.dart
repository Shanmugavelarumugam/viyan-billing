import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/backup_provider.dart';

class BackupSyncScreen extends ConsumerStatefulWidget {
  const BackupSyncScreen({super.key});

  @override
  ConsumerState<BackupSyncScreen> createState() => _BackupSyncScreenState();
}

class _BackupSyncScreenState extends ConsumerState<BackupSyncScreen> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = ref.watch(backupSyncProvider);
    final notifier = ref.read(backupSyncProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Sync', style: TextStyle(fontWeight: FontWeight.w700)),
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
      ),
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
        child: state.isLoaded
            ? _buildBody(cs, state, notifier)
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildBody(ColorScheme cs, BackupSyncState state, BackupSyncNotifier notifier) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildSyncStatusCard(cs, state),
              const SizedBox(height: 12),
              _buildAutoBackupCard(cs, state, notifier),
              const SizedBox(height: 12),
              _buildManualBackupCard(cs, state, notifier),
              const SizedBox(height: 12),
              _buildDataIncludedCard(cs),
              const SizedBox(height: 12),
              _buildDevicesCard(cs, state),
              const SizedBox(height: 12),
              _buildExportCard(cs, state, notifier),
              const SizedBox(height: 12),
              _buildRestoreCard(cs, state, notifier),
              const SizedBox(height: 12),
              _buildSyncHealthCard(cs, state),
            ]),
          ),
        ),
      ],
    );
  }

  // ── Section 1: Sync Status Card ────────────────────────────────────────

  Widget _buildSyncStatusCard(ColorScheme cs, BackupSyncState state) {
    final isSafe = state.status == SyncStatus.synced;
    final isPending = state.status == SyncStatus.pending;
    final isError = state.status == SyncStatus.error;

    IconData icon;
    Color color;
    String title;
    String subtitle;

    if (isSafe && state.lastSyncedAt != null) {
      icon = Icons.check_circle_rounded;
      color = Colors.green;
      title = 'All Data Synced';
      subtitle = 'Last backup: ${_formatDateTime(state.lastSyncedAt!)}';
    } else if (isPending) {
      icon = Icons.sync_problem_rounded;
      color = Colors.orange;
      title = 'Sync Pending';
      subtitle = '${state.pendingUploads} records waiting to upload';
    } else if (isError) {
      icon = Icons.error_outline_rounded;
      color = cs.error;
      title = 'Sync Error';
      subtitle = 'Last backup failed. Tap Backup Now to retry.';
    } else {
      icon = Icons.cloud_off_rounded;
      color = cs.onSurfaceVariant;
      title = 'No Backup Yet';
      subtitle = 'Tap Backup Now to save your data to cloud';
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Today, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (diff.inDays < 2) return 'Yesterday, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  // ── Section 2: Auto Backup ─────────────────────────────────────────────

  Widget _buildAutoBackupCard(ColorScheme cs, BackupSyncState state, BackupSyncNotifier notifier) {
    return _sectionCard(cs, Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sectionHeader(cs, 'Automatic Backup', Icons.sync_rounded),
        const SizedBox(height: 4),
        _toggleTile(
          cs,
          'Enable Auto Sync',
          'Your sales, items and reports will automatically sync to cloud.',
          state.isAutoSyncEnabled,
          (v) => notifier.setAutoSync(v),
        ),
        if (state.isAutoSyncEnabled) ...[
          const SizedBox(height: 4),
          _toggleTile(
            cs,
            'Sync over WiFi only',
            'Backup only when connected to WiFi to save mobile data.',
            state.wifiOnly,
            (v) => notifier.setWifiOnly(v),
          ),
        ],
      ],
    ));
  }

  // ── Section 3: Manual Backup ───────────────────────────────────────────

  Widget _buildManualBackupCard(ColorScheme cs, BackupSyncState state, BackupSyncNotifier notifier) {
    return _sectionCard(cs, Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _sectionHeader(cs, 'Manual Backup', Icons.cloud_upload_rounded),
            const Spacer(),
            if (state.lastSyncedAt != null)
              Text(
                _formatDateTime(state.lastSyncedAt!),
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: state.isBackingUp || !state.internetConnected
                ? null
                : () => notifier.backupNow(),
            icon: state.isBackingUp
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.onPrimary,
                    ),
                  )
                : const Icon(Icons.cloud_upload_rounded, size: 20),
            label: Text(
              state.isBackingUp ? 'Backing up data...' : 'Backup Now',
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
        if (state.backupResultMessage != null) ...[
          const SizedBox(height: 10),
          _resultBanner(
            cs,
            message: state.backupResultMessage!,
            isError: state.backupResultIsError,
          ),
        ],
        if (!state.internetConnected)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.wifi_off_rounded, size: 14, color: cs.error),
                const SizedBox(width: 6),
                Text(
                  'No internet connection',
                  style: TextStyle(fontSize: 12, color: cs.error),
                ),
              ],
            ),
          ),
      ],
    ));
  }

  // ── Section 4: Data Included ───────────────────────────────────────────

  Widget _buildDataIncludedCard(ColorScheme cs) {
    return _sectionCard(cs, Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sectionHeader(cs, 'Backed Up Data', Icons.inventory_2_rounded),
        const SizedBox(height: 10),
        _dataRow(cs, Icons.receipt_long_rounded, 'Bills & Sales', true),
        _divider(cs),
        _dataRow(cs, Icons.inventory_rounded, 'Items & Inventory', true),
        _divider(cs),
        _dataRow(cs, Icons.people_rounded, 'Customer Details', true),
        _divider(cs),
        _dataRow(cs, Icons.bar_chart_rounded, 'Reports & History', true),
        _divider(cs),
        _dataRow(cs, Icons.settings_rounded, 'Shop Settings', true),
        _divider(cs),
        _dataRow(cs, Icons.image_rounded, 'Product Images', false),
      ],
    ));
  }

  Widget _dataRow(ColorScheme cs, IconData icon, String label, bool included) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            included ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 18,
            color: included ? Colors.green : cs.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontSize: 14, color: cs.onSurface),
          ),
          const Spacer(),
          if (!included)
            Text(
              'Not included',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }

  // ── Section 5: Connected Devices ───────────────────────────────────────

  Widget _buildDevicesCard(ColorScheme cs, BackupSyncState state) {
    return _sectionCard(cs, Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sectionHeader(cs, 'Connected Devices', Icons.devices_rounded),
        const SizedBox(height: 10),
        ...state.connectedDevices.map((device) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.phone_android_rounded, size: 18, color: cs.primary),
              ),
              const SizedBox(width: 10),
              Text(
                device,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: cs.onSurface),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Active',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green.shade700),
                ),
              ),
            ],
          ),
        )),
        Text(
          'Multi-device sync available on Pro plan',
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontStyle: FontStyle.italic),
        ),
      ],
    ));
  }

  // ── Section 6: Export Data ─────────────────────────────────────────────

  Widget _buildExportCard(ColorScheme cs, BackupSyncState state, BackupSyncNotifier notifier) {
    return _sectionCard(cs, Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sectionHeader(cs, 'Export Data', Icons.file_download_rounded),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _exportButton(
              cs,
              icon: Icons.table_chart_rounded,
              label: 'Bills',
              subtitle: 'CSV',
              isLoading: state.isExportingBills,
              onTap: () => notifier.exportBillsCsv(),
            )),
            const SizedBox(width: 8),
            Expanded(child: _exportButton(
              cs,
              icon: Icons.picture_as_pdf_rounded,
              label: 'Reports',
              subtitle: 'PDF',
              isLoading: state.isExportingReports,
              onTap: () => notifier.exportReportsPdf(),
            )),
            const SizedBox(width: 8),
            Expanded(child: _exportButton(
              cs,
              icon: Icons.inventory_rounded,
              label: 'Inventory',
              subtitle: 'CSV',
              isLoading: state.isExportingInventory,
              onTap: () => notifier.exportInventoryCsv(),
            )),
          ],
        ),
        if (state.exportMessage != null) ...[
          const SizedBox(height: 10),
          _resultBanner(cs, message: state.exportMessage!, isError: state.exportIsError),
        ],
      ],
    ));
  }

  Widget _exportButton(ColorScheme cs, {required IconData icon, required String label, required String subtitle, required bool isLoading, required VoidCallback onTap}) {
    return SizedBox(
      height: 64,
      child: OutlinedButton(
        onPressed: isLoading ? null : onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.onSurface,
          side: BorderSide(color: cs.outlineVariant),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: cs.primary),
                  const SizedBox(height: 2),
                  Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  Text(subtitle, style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
                ],
              ),
      ),
    );
  }

  // ── Section 7: Restore Backup ──────────────────────────────────────────

  Widget _buildRestoreCard(ColorScheme cs, BackupSyncState state, BackupSyncNotifier notifier) {
    return _sectionCard(cs, Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sectionHeader(cs, 'Restore Data', Icons.cloud_download_rounded),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This will replace all current data with cloud data.',
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            onPressed: state.isRestoring || !state.internetConnected
                ? null
                : () => _confirmRestore(context, notifier),
            icon: state.isRestoring
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: cs.error),
                  )
                : Icon(Icons.restore_rounded, size: 18, color: cs.error),
            label: Text(
              state.isRestoring ? 'Restoring...' : 'Restore Data',
              style: TextStyle(fontWeight: FontWeight.w600, color: cs.error, fontSize: 14),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: cs.error.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        if (state.restoreMessage != null) ...[
          const SizedBox(height: 10),
          _resultBanner(cs, message: state.restoreMessage!, isError: state.restoreIsError),
        ],
      ],
    ));
  }

  Future<void> _confirmRestore(BuildContext context, BackupSyncNotifier notifier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.orange.shade700, size: 24),
            const SizedBox(width: 8),
            const Text('Restore Data?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          ],
        ),
        content: const Text(
          'This will replace all local data (bills, items, settings) with the data stored in cloud. This action cannot be undone.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Restore', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      notifier.restoreFromCloud();
    }
  }

  // ── Section 8: Sync Health ─────────────────────────────────────────────

  Widget _buildSyncHealthCard(ColorScheme cs, BackupSyncState state) {
    return _sectionCard(cs, Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sectionHeader(cs, 'Sync Health', Icons.monitor_heart_rounded),
        const SizedBox(height: 10),
        _healthRow(cs, Icons.wifi_rounded, 'Internet', state.internetConnected),
        const SizedBox(height: 6),
        _healthRow(cs, Icons.cloud_rounded, 'Cloud Sync', state.cloudActive),
        const SizedBox(height: 6),
        _healthRow(cs, Icons.pending_actions_rounded, 'Pending Uploads', state.pendingUploads == 0, valueText: '${state.pendingUploads}'),
      ],
    ));
  }

  Widget _healthRow(ColorScheme cs, IconData icon, String label, bool isOk, {String? valueText}) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isOk ? Colors.green.withValues(alpha: 0.08) : cs.errorContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isOk ? Colors.green : cs.error,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: TextStyle(fontSize: 14, color: cs.onSurface, fontWeight: FontWeight.w500)),
        ),
        valueText != null
            ? Text(valueText, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface))
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isOk ? Colors.green.withValues(alpha: 0.08) : cs.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isOk ? 'Connected' : 'Disconnected',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isOk ? Colors.green.shade700 : cs.error,
                  ),
                ),
              ),
      ],
    );
  }

  // ── Shared UI helpers ──────────────────────────────────────────────────

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

  Widget _toggleTile(ColorScheme cs, String title, String description, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ],
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

  Widget _resultBanner(ColorScheme cs, {required String message, required bool isError}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isError
            ? cs.errorContainer.withValues(alpha: 0.3)
            : Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
            size: 18,
            color: isError ? cs.error : Colors.green,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isError ? cs.error : Colors.green.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(ColorScheme cs) {
    return Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5), thickness: 0.5);
  }
}
