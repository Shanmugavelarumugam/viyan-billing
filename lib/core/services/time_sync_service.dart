import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final timeSyncProvider = StateNotifierProvider<TimeSyncNotifier, TimeSyncState>((ref) {
  return TimeSyncNotifier();
});

class TimeSyncState {
  final int offset;
  final bool isOfflineSyncValid;
  final DateTime? lastSyncedAt;
  final bool isBlacklisted;

  TimeSyncState({
    required this.offset,
    required this.isOfflineSyncValid,
    this.lastSyncedAt,
    this.isBlacklisted = false,
  });

  DateTime getNetworkTime() {
    return DateTime.now().add(Duration(milliseconds: offset));
  }
}

class TimeSyncNotifier extends StateNotifier<TimeSyncState> {
  TimeSyncNotifier() : super(TimeSyncState(offset: 0, isOfflineSyncValid: true)) {
    _initNotifier();
  }

  Future<void> _initNotifier() async {
    await _loadFromCache();
    // Defer network sync to after first frame to avoid blocking startup
    Future.microtask(() => syncTime());
  }

  Future<void> _loadFromCache() async {
    try {
      const secureStorage = FlutterSecureStorage(
        aOptions: AndroidOptions(
          resetOnError: true,
        ),
      );
      final isBlacklisted = await secureStorage.read(key: 'device_blacklisted') == 'true';
      if (isBlacklisted) {
        state = TimeSyncState(
          offset: 0,
          isOfflineSyncValid: false,
          lastSyncedAt: null,
          isBlacklisted: true,
        );
        return;
      }

      final box = Hive.box('settings_box');
      final cachedOffset = box.get('time_offset', defaultValue: 0) as int;
      final cachedLastSyncedStr = box.get('last_synced_at') as String?;
      final cachedLastDeviceTimeMs = box.get('last_synced_device_time') as int?;
      
      if (cachedLastSyncedStr != null && cachedLastDeviceTimeMs != null) {
        final lastSyncedAt = DateTime.parse(cachedLastSyncedStr);
        final elapsedMs = DateTime.now().millisecondsSinceEpoch - cachedLastDeviceTimeMs;
        
        final bool isValid = elapsedMs >= 0 && elapsedMs <= const Duration(hours: 48).inMilliseconds;
        
        if (elapsedMs < 0) {
          // Clock rewind detected! Record a tamper attempt.
          await _recordTamperAttempt();
        }
        
        state = TimeSyncState(
          offset: cachedOffset,
          isOfflineSyncValid: isValid,
          lastSyncedAt: lastSyncedAt,
          isBlacklisted: false,
        );
      }
    } catch (e) {
      debugPrint("⚠️ Failed to load time sync cache: $e");
    }
  }

  Future<void> _recordTamperAttempt() async {
    try {
      const secureStorage = FlutterSecureStorage(
        aOptions: AndroidOptions(
          resetOnError: true,
        ),
      );
      final attemptsStr = await secureStorage.read(key: 'tamper_attempts');
      int attempts = (attemptsStr != null ? int.tryParse(attemptsStr) : null) ?? 0;
      attempts++;
      await secureStorage.write(key: 'tamper_attempts', value: attempts.toString());
      debugPrint("⚠️ Tampering detected! Total attempts: $attempts");
      
      if (attempts > 5) {
        await secureStorage.write(key: 'device_blacklisted', value: 'true');
        debugPrint("🚨 Device permanently blacklisted due to multiple tampering attempts.");
        state = TimeSyncState(
          offset: 0,
          isOfflineSyncValid: false,
          lastSyncedAt: null,
          isBlacklisted: true,
        );
      }
    } catch (e) {
      debugPrint("Failed to update secure tamper attempts: $e");
    }
  }

  Future<void> syncTime() async {
    try {
      const secureStorage = FlutterSecureStorage(
        aOptions: AndroidOptions(
          resetOnError: true,
        ),
      );
      final isBlacklisted = await secureStorage.read(key: 'device_blacklisted') == 'true';
      if (isBlacklisted) {
        state = TimeSyncState(
          offset: 0,
          isOfflineSyncValid: false,
          lastSyncedAt: null,
          isBlacklisted: true,
        );
        return;
      }

      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
      ));
      final response = await dio.head('https://www.google.com');
      final dateHeader = response.headers.value('date');
      if (dateHeader != null) {
        final serverTime = HttpDate.parse(dateHeader);
        final now = DateTime.now();
        final offset = serverTime.difference(now).inMilliseconds;
        
        final box = Hive.box('settings_box');
        await box.put('time_offset', offset);
        await box.put('last_synced_at', serverTime.toIso8601String());
        await box.put('last_synced_device_time', now.millisecondsSinceEpoch);
        
        state = TimeSyncState(
          offset: offset,
          isOfflineSyncValid: true,
          lastSyncedAt: serverTime,
          isBlacklisted: false,
        );
        debugPrint("⏰ Time sync successful. Offset: ${offset}ms. Network time: ${now.add(Duration(milliseconds: offset))}");
      }
    } catch (e) {
      debugPrint("⚠️ Time sync failed: $e. Re-checking offline status.");
      await _loadFromCache();
    }
  }
}
