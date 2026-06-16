# Subscription Security Architecture — Viyan Billing

## Table of Contents
1. [Threat Model & Risk Analysis](#1-threat-model)
2. [Target Architecture Overview](#2-architecture)
3. [Multi-Signal Device Fingerprinting](#3-fingerprinting)
4. [APK Integrity & Root Detection](#4-integrity)
5. [Firestore Schema Redesign](#5-schema)
6. [Cloud Function Security Layer](#6-cloud-functions)
7. [Firestore Security Rules](#7-rules)
8. [Time Tamper Protection v2](#8-time)
9. [Anti-Fraud Protections](#9-fraud)
10. [UX & Conversion](#10-ux)
11. [Migration Plan](#11-migration)

---

<a id="1-threat-model"></a>
## 1. Threat Model & Risk Analysis

| Threat | Severity | Current Mitigation | Gap |
|--------|----------|--------------------|-----|
| Clear app data / reinstall → new trial | **Critical** | Single `FlutterSecureStorage` deviceId | One signal, fully deletable |
| APK repackage / patch out checks | **Critical** | None | No integrity checks |
| Run on emulator for unlimited trials | **High** | None | No emulator detection |
| Offline clock rollback | **High** | `TimeSyncService` with tamper counter | Counter stored in secure storage (deletable) |
| Modify Firestore via console | **High** | App Check | No validated server-side write rules |
| VPN/proxy spoofing | **Medium** | None | No geo/anomaly checks |
| Multiple accounts per device | **Medium** | Email-change detection | Only flags, doesn't block server-side |
| Intercept/skip Razorpay callback | **Medium** | None | No payment receipt validation |

---

<a id="2-architecture"></a>
## 2. Target Architecture

```
┌──────────────────────┐       ┌──────────────────────────┐
│   Flutter Client      │       │   Firebase Cloud Functions│
│                       │       │                          │
│  ┌─────────────────┐  │       │  ┌────────────────────┐  │
│  │ Integrity Check  │──┼───────┼─▶│ validateDevice()   │  │
│  │ (root/emu/patch) │  │       │  │ isTrialValid()     │  │
│  └─────────────────┘  │       │  │ registerTrial()    │  │
│  ┌─────────────────┐  │       │  │ verifyPayment()    │  │
│  │ Fingerprint Gen  │──┼───────┼─▶│ logSecurityEvent() │  │
│  └─────────────────┘  │       │  └────────────────────┘  │
│  ┌─────────────────┐  │       │         │                 │
│  │ Encrypted Token  │──┼───────┼─────────┘                 │
│  │ (JWT-like)       │  │       │                          │
│  └─────────────────┘  │       │  Firestore:               │
│                       │       │  ┌────────────────────┐  │
│  ALL decisions        │       │  │ devices/{fp}        │  │
│  come from Cloud      │       │  │ subscriptions/{uid}│  │
│  Functions, NEVER     │       │  │ security_events/*   │  │
│  local logic.         │       │  │ trial_requests/*   │  │
└──────────────────────┘       └──┴────────────────────┴──┘
```

**Golden rule**: The client sends evidence — the server decides.

---

<a id="3-fingerprinting"></a>
## 3. Multi-Signal Device Fingerprinting

### Why single `FlutterSecureStorage` is insufficient
Secure Storage uses Android Keystore / iOS Keychain. Both can be wiped by:
- "Clear Data" in Android Settings
- App reinstall on iOS (Keychain can persist with proper config, but not guaranteed)
- Rooted device with Keystore extraction

### Multi-signal fingerprint (composite hash)

```dart
// lib/core/services/device_fingerprint_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' show sha256;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:unique_identifier/unique_identifier.dart';
import 'package:android_id/android_id.dart';
import 'package:flutter/material.dart';

class DeviceFingerprintService {
  final FlutterSecureStorage _secureStorage;
  final DeviceInfoPlugin _deviceInfo;

  DeviceFingerprintService({
    FlutterSecureStorage? secureStorage,
    DeviceInfoPlugin? deviceInfo,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  /// Generates a composite SHA-256 fingerprint from multiple signals.
  /// Signals are collected BEST-EFFORT; missing signals still produce a
  /// usable fingerprint (just with lower entropy).
  Future<String> getFingerprint() async {
    // 1. Persistent secure-storage token (survives reinstall on iOS Keychain,
    //    Android Backup, or if user migrates data)
    final storedToken = await _secureStorage.read(key: 'fp_token');
    if (storedToken != null) return storedToken;

    // 2. Collect signals (failures are caught — null signals are skipped)
    final signals = await _collectSignals();

    // 3. Hash into a 64-char hex fingerprint
    final raw = signals.join('|');
    final hash = sha256.convert(utf8.encode(raw)).toString();

    // 4. Persist so subsequent calls are instant
    await _secureStorage.write(key: 'fp_token', value: hash);
    return hash;
  }

  Future<List<String?>> _collectSignals() async {
    final signals = <String?>[];

    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        signals.add(androidInfo.id);              // Android ID (resets on factory reset)
        signals.add(androidInfo.serialNumber);     // serial (on older APIs)
        signals.add(androidInfo.fingerprint);      // build fingerprint
        signals.add(androidInfo.hardware);
        signals.add(androidInfo.brand);
        signals.add(androidInfo.device);
        // Advertising ID (requires user opt-in)
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        signals.add(iosInfo.identifierForVendor);  // IDFV (resets on reinstall by same vendor)
        signals.add(iosInfo.modelName);
        signals.add(iosInfo.systemVersion);
        signals.add(iosInfo.utsname.machine);       // e.g. "iPhone14,2"
      }
    } catch (_) {
      // Non-fatal — proceed with fewer signals
    }

    // Installation ID (persists across app updates, resets on clear data)
    try {
      final installStore = const FlutterSecureStorage();
      var installId = await installStore.read(key: 'install_id');
      if (installId == null) {
        installId = _randomHex(16);
        await installStore.write(key: 'install_id', value: installId);
      }
      signals.add(installId);
    } catch (_) {}

    return signals;
  }

  String _randomHex(int length) {
    final rand = Random.secure();
    return List.generate(length, (_) => rand.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }
}
```

### Why this is better
| Signal | Survives clear data | Survives reinstall | Survives factory reset |
|--------|:---:|:---:|:---:|
| Old single deviceId | ✗ | ✗ | ✗ |
| `fp_token` (secure storage) | ✗ | ✓(iOS Keychain) | ✗ |
| Android ID | ✗ | ✗ | ✗ |
| Build fingerprint | ✓ | ✓ | ✗ |
| IDFV (iOS) | ✓ | ✗ | ✗ |
| Serial / hardware | ✓ | ✓ | ✗ |
| **Composite hash** | **Partial** | **Strong** | **Weak** |

If secure storage is wiped, the remaining signals still produce a fingerprint. If ALL signals are wiped (factory reset), treat as a completely new device — that's acceptable.

---

<a id="4-integrity"></a>
## 4. APK Integrity & Root/Emulator Detection

### 4.1 Package signature verification

```dart
// lib/core/services/integrity_service.dart
import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart';

class IntegrityService {
  /// Returns SHA-256 of the installed APK's signing certificate.
  /// On a repackaged APK, the signature WILL differ.
  Future<String?> getApkSignatureHash() async {
    if (!Platform.isAndroid) return null;

    try {
      // Use PackageManager on Android via MethodChannel
      // This returns the signing certificate hash.
      // A repackaged APK will have a different signer.
      final info = await PackageInfo.fromPlatform();
      // On Android, we read the Installer Store info as a lightweight check.
      // For production, use SafetyNet / Play Integrity API.
      return info.installerStore;
    } catch (_) {
      return null;
    }
  }

  /// Determine if the app is running on a production store build.
  /// Side-loaded APKs return null or a non-standard installer.
  bool isStoreBuild(String? installerStore) {
    if (installerStore == null) return false;
    const stores = ['com.android.vending', 'com.samsung.android.apps', 'com.amazon.venezia'];
    return stores.contains(installerStore);
  }
}
```

### 4.2 Root / Jailbreak detection

```dart
import 'dart:io';

class RootDetector {
  static Future<bool> isDeviceTampered() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    return _checkRootPaths() || _checkSuspiciousPackages() || _checkEmulator();
  }

  static Future<bool> _checkRootPaths() async {
    const paths = [
      '/system/app/Superuser.apk',
      '/sbin/su',
      '/system/bin/su',
      '/system/xbin/su',
      '/data/local/xbin/su',
      '/data/local/bin/su',
      '/system/sd/xbin/su',
      '/system/bin/failsafe/su',
      '/data/local/su',
      '/su/bin/su',
    ];
    for (final path in paths) {
      if (await File(path).exists()) return true;
    }
    return false;
  }

  static Future<bool> _checkSuspiciousPackages() async {
    // In production, use a native platform channel for efficiency
    const packages = [
      'com.noshufou.android.su',
      'com.noshufou.android.su.elite',
      'com.thirdparty.superuser',
      'eu.chainfire.supersu',
      'com.koushikdutta.superuser',
      'com.topjohnwu.magisk',
      'com.stifflered.aosp.faker',
      'com.genymotion.genymotion',
      'com.bluestacks',
    ];
    // On Android, check via packageManager
    return false; // Placeholder — requires platform channel
  }

  static Future<bool> _checkEmulator() async {
    if (!Platform.isAndroid) return false;
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      final isEmulator = [
        info.fingerprint.startsWith('google/sdk_gphone'),
        info.fingerprint == 'sdk/google/sdk_gphone',
        info.hardware == 'goldfish' || info.hardware == 'ranchu',
        info.brand == 'google' && info.device == 'generic_x86',
        info.product == 'sdk_gphone64_x86_64',
        info.product == 'sdk_gphone64_arm64',
      ].any((check) => check);
      return isEmulator;
    } catch (_) {
      return false;
    }
  }
}
```

### 4.3 Google Play Integrity API (recommended for production)

For Android, **replace root detection entirely** with:

```dart
// Uses the official plugin: https://pub.dev/packages/play_integrity
import 'package:play_integrity/play_integrity.dart';

class PlayIntegrityGuard {
  static Future<IntegrityResult> verify() async {
    // 1. Get a nonce from your Cloud Function
    final nonce = await CloudFunctionService.getNonce();

    // 2. Request integrity token
    final integrity = PlayIntegrity();
    final tokenResult = await integrity.requestIntegrityToken(
      nonce: nonce,
      cloudProjectNumber: 123456789, // Your GCP project number
    );

    // 3. Send token to your Cloud Function for verification
    //    (NEVER verify locally — the token is encrypted)
    return CloudFunctionService.verifyIntegrityToken(
      token: tokenResult.token,
      nonce: nonce,
    );
  }
}

class IntegrityResult {
  final bool isDeviceCertified;
  final bool isAppRecognized;
  final bool passesIntegrity;
  final String? advice;

  IntegrityResult({
    required this.isDeviceCertified,
    required this.isAppRecognized,
    required this.passesIntegrity,
    this.advice,
  });
}
```

**Cloud Function (Node.js)**:

```javascript
// functions/src/integrity.ts
import * as functions from 'firebase-functions';
import { GoogleAuth } from 'google-auth-library';

const GOOGLE_CLOUD_PROJECT = 123456789;

export const verifyIntegrity = functions.https.onCall(async (data, context) => {
  const { token, nonce } = data;

  // Verify the nonce matches what we issued
  // (In production, store nonces with expiration in Firestore or Redis)

  const auth = new GoogleAuth();
  const client = await auth.getIdTokenClient(
    'https://playintegrity.googleapis.com'
  );
  const response = await client.request({
    method: 'POST',
    uri: `https://playintegrity.googleapis.com/v1/${GOOGLE_CLOUD_PROJECT}/:decodeIntegrityToken`,
    data: { integrityToken: token },
  });

  const payload = response.data.tokenPayloadExternal;
  const verdict = payload.deviceIntegrity;

  return {
    isDeviceCertified: verdict.deviceRecognitionVerdict === 'MEETS_DEVICE_INTEGRITY',
    isAppRecognized: payload.appIntegrity.appRecognitionVerdict === 'PLAY_RECOGNIZED',
    passesIntegrity: verdict.deviceRecognitionVerdict === 'MEETS_DEVICE_INTEGRITY'
      && payload.appIntegrity.appRecognitionVerdict === 'PLAY_RECOGNIZED',
    requestDetails: payload.requestDetails,
  };
});
```

---

<a id="5-schema"></a>
## 5. Firestore Schema Redesign

### Collections

#### `devices/{fingerprintHash}` — Device registry

```typescript
{
  // Identity
  fingerprintHash: string,          // SHA-256 composite fingerprint
  firstSeenAt: Timestamp,
  lastSeenAt: Timestamp,
  
  // Signals (for audit, not for trust)
  signals: {
    hardware: string?,
    brand: string?,
    device: string?,
    buildFingerprint: string?,
    androidId: string?,
    identifierForVendor: string?,
    installId: string?,
  },

  // Trial tracking
  trial: {
    startedAt: Timestamp?,
    endsAt: Timestamp?,
    usedByEmails: string[],          // All emails that used this device
    suspiciousEmailChanges: number,  // Incremented on email != firstEmail
    isBlacklisted: boolean,
    blacklistReason: string?,
    blacklistedAt: Timestamp?,
  },
  
  // Integrity history
  integrity: {
    lastCheckPassed: boolean,
    lastCheckAt: Timestamp,
    failureCount: number,
    lastFailureReason: string?,
  },
  
  // Time sync
  timeSync: {
    lastOffset: number,
    lastSyncedAt: Timestamp,
    tamperAttempts: number,
    isBlacklisted: boolean,
  },

  // Metadata
  createdAt: Timestamp,
  updatedAt: Timestamp,
}

// Indexes:
// - fingerprintHash (primary key)
// - trial.endsAt ASC (for expiry sweep)
// - trial.isBlacklisted == true (for sweep)
```

#### `subscriptions/{uid}` — Subscription state (1:1 with Firebase Auth UID)

```typescript
{
  uid: string,
  email: string,
  
  // Plan
  plan: 'free_trial' | 'basic_monthly' | 'pro_monthly' | 'expired' | 'suspended',
  status: 'active' | 'grace' | 'expired' | 'read_only' | 'suspended',
  
  // Dates (server-time validated)
  trialStartedAt: Timestamp?,
  trialEndsAt: Timestamp?,
  graceEndsAt: Timestamp?,
  currentPeriodStart: Timestamp,
  currentPeriodEnd: Timestamp,         // Next billing date
  
  // Device binding
  activeDeviceFingerprint: string,
  deviceHistory: string[],             // All fingerprints that logged in
  
  // Payments
  payments: [
    {
      razorpayPaymentId: string,
      razorpayOrderId: string,
      amount: number,
      currency: string,
      status: 'verified' | 'pending' | 'failed' | 'refunded',
      verifiedAt: Timestamp,
      planPurchased: string,
      periodStart: Timestamp,
      periodEnd: Timestamp,
    }
  ],
  
  // Fraud detection
  securityFlags: {
    suspiciousEmailChanges: number,
    deviceSwitches: number,
    lastFlaggedAt: Timestamp?,
    isUnderReview: boolean,
  },
  
  createdAt: Timestamp,
  updatedAt: Timestamp,
}

// Indexes:
// - uid (primary key)
// - status ASC (for sweep)
// - currentPeriodEnd ASC (for expiry notifications)
// - plan == 'free_trial' (for bulk queries)
```

#### `security_events/{eventId}` — Audit log

```typescript
{
  eventId: string,                   // Auto-generated
  type: 'trial_abuse' | 'tamper_detected' | 'device_switch' 
      | 'integrity_failure' | 'payment_verification_failed'
      | 'reinstall_detected' | 'email_change_flag'
      | 'time_tamper' | 'root_detected',
  severity: 'info' | 'warning' | 'critical',
  
  uid: string?,                      // Firebase Auth UID if available
  fingerprintHash: string?,
  email: string?,
  
  details: Record<string, any>,      // Arbitrary payload
  
  ipAddress: string?,
  userAgent: string?,
  
  createdAt: Timestamp,
}

// Indexes:
// - createdAt DESC (for recent-first queries)
// - type + createdAt DESC
// - uid + createdAt DESC
```

#### `trial_requests/{requestId}` — Rate-limited request log

```typescript
{
  requestId: string,
  fingerprintHash: string,
  email: string,
  ipAddress: string,
  resolvedStatus: 'approved' | 'rejected',
  rejectionReason: string?,
  deviceFingerprint: string,
  createdAt: Timestamp,
}

// Indexes:
// - fingerprintHash + createdAt DESC
// - email + createdAt DESC
```

---

<a id="6-cloud-functions"></a>
## 6. Cloud Function Security Layer

### 6.1 Register trial (server-authoritative)

```javascript
// functions/src/trial.ts
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

const db = admin.firestore();

export const registerTrial = functions.https.onCall(async (data, context) => {
  // 1. Require auth
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Login required');
  }

  const { fingerprintHash, signals, email, apkSignatureHash } = data;
  const uid = context.auth.uid;

  // 2. Validate fingerprint
  if (!fingerprintHash || fingerprintHash.length !== 64) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid device fingerprint');
  }

  // 3. Check if user already has a subscription
  const existingSub = await db.collection('subscriptions').doc(uid).get();
  if (existingSub.exists && existingSub.data()!.plan !== 'expired') {
    throw new functions.https.HttpsError('already-exists', 'Subscription already active');
  }

  // 4. Check device record
  const deviceRef = db.collection('devices').doc(fingerprintHash);
  const deviceSnap = await deviceRef.get();

  // 5. Check for abuse patterns
  const abuseCheck = await _checkDeviceAbuse(deviceSnap, fingerprintHash, email, uid);
  if (abuseCheck.isAbusive) {
    await _logSecurityEvent('trial_abuse', {
      uid, fingerprintHash, email,
      reason: abuseCheck.reason,
    });
    // Mark device as blacklisted
    await deviceRef.set({
      trial: { isBlacklisted: true, blacklistReason: abuseCheck.reason, blacklistedAt: admin.firestore.FieldValue.serverTimestamp() },
    }, { merge: true });
    throw new functions.https.HttpsError('permission-denied', 'Trial not available for this device');
  }

  // 6. Check rate limits for this fingerprint + email
  const recentRequests = await db.collection('trial_requests')
    .where('fingerprintHash', '==', fingerprintHash)
    .where('createdAt', '>=', admin.firestore.Timestamp.now().toMillis() - 86400000)
    .get();
  if (recentRequests.size >= 3) {
    throw new functions.https.HttpsError('resource-exhausted', 'Too many trial requests');
  }

  // 7. Create device record (upsert)
  const now = admin.firestore.FieldValue.serverTimestamp();
  const trialEnd = new Date(Date.now() + 15 * 24 * 60 * 60 * 1000);

  await deviceRef.set({
    fingerprintHash,
    firstSeenAt: now,
    lastSeenAt: now,
    signals: signals || {},
    trial: {
      startedAt: now,
      endsAt: admin.firestore.Timestamp.fromDate(trialEnd),
      usedByEmails: admin.firestore.FieldValue.arrayUnion([email]),
      suspiciousEmailChanges: 0,
      isBlacklisted: false,
    },
    createdAt: now,
    updatedAt: now,
  }, { merge: true });

  // 8. Create subscription
  await db.collection('subscriptions').doc(uid).set({
    uid,
    email,
    plan: 'free_trial',
    status: 'active',
    trialStartedAt: now,
    trialEndsAt: admin.firestore.Timestamp.fromDate(trialEnd),
    graceEndsAt: admin.firestore.Timestamp.fromDate(new Date(trialEnd.getTime() + 2 * 86400000)),
    currentPeriodStart: now,
    currentPeriodEnd: admin.firestore.Timestamp.fromDate(trialEnd),
    activeDeviceFingerprint: fingerprintHash,
    deviceHistory: [fingerprintHash],
    securityFlags: {
      suspiciousEmailChanges: 0,
      deviceSwitches: 0,
      isUnderReview: false,
    },
    createdAt: now,
    updatedAt: now,
  });

  // 9. Log the request
  await db.collection('trial_requests').add({
    fingerprintHash, email,
    resolvedStatus: 'approved',
    createdAt: now,
  });

  return {
    trialEndsAt: trialEnd.toISOString(),
    status: 'active',
  };
});

async function _checkDeviceAbuse(deviceSnap, fingerprintHash, email, uid) {
  const abuse = { isAbusive: false, reason: '' };

  if (!deviceSnap.exists) return abuse;

  const device = deviceSnap.data()!;

  // 1. Already blacklisted
  if (device.trial?.isBlacklisted) {
    return { isAbusive: true, reason: 'Device is blacklisted' };
  }

  // 2. Different email on same device (excluding unknown)
  const usedEmails = device.trial?.usedByEmails || [];
  const normalizedEmail = email.trim().toLowerCase();
  if (normalizedEmail !== 'unknown@example.com' 
      && usedEmails.length > 0 
      && !usedEmails.includes(normalizedEmail)) {
    return { isAbusive: true, reason: 'Email mismatch on registered device' };
  }

  // 3. Excessive email changes
  if ((device.trial?.suspiciousEmailChanges || 0) >= 3) {
    return { isAbusive: true, reason: 'Excessive email changes' };
  }

  // 4. Too many devices for this user
  const userDevices = await db.collection('subscriptions')
    .where('deviceHistory', 'array-contains', fingerprintHash)
    .get();
  if (userDevices.size > 5) {
    return { isAbusive: true, reason: 'Device linked to too many accounts' };
  }

  return abuse;
}
```

### 6.2 Validate subscription (called on every app launch)

```javascript
export const validateSubscription = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Login required');
  }
  
  const { fingerprintHash } = data;
  const uid = context.auth.uid;
  
  // 1. Get subscription
  const subSnap = await db.collection('subscriptions').doc(uid).get();
  if (!subSnap.exists) {
    return { status: 'expired', reason: 'No subscription found' };
  }
  const sub = subSnap.data()!;
  
  // 2. Get device record
  const deviceSnap = await db.collection('devices').doc(fingerprintHash).get();
  
  // 3. Cross-check device
  const isAuthorizedDevice = sub.activeDeviceFingerprint === fingerprintHash
    || (sub.deviceHistory || []).includes(fingerprintHash);
  
  // 4. Check blacklists
  if (deviceSnap.exists && deviceSnap.data()!.trial?.isBlacklisted) {
    return { status: 'suspended', reason: 'Device blacklisted' };
  }
  
  // 5. Evaluate using SERVER time
  const now = admin.firestore.Timestamp.now();
  const expiry = sub.currentPeriodEnd?.toDate();
  const graceEnd = sub.graceEndsAt?.toDate();
  
  let status = sub.status;
  
  if (expiry && now.toDate() > expiry) {
    if (graceEnd && now.toDate() <= graceEnd) {
      status = 'grace';
    } else {
      status = 'expired';
    }
  }
  
  // 6. Update last seen
  await db.collection('subscriptions').doc(uid).update({
    lastValidatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  return {
    status,
    plan: sub.plan,
    currentPeriodEnd: sub.currentPeriodEnd?.toDate()?.toISOString(),
    isAuthorizedDevice,
    serverTime: now.toDate().toISOString(),
  };
});
```

### 6.3 Payment verification (prevent Razorpay callback forging)

```javascript
export const verifyPayment = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Login required');
  }
  
  const { razorpayPaymentId, razorpayOrderId, razorpaySignature, planType } = data;
  const uid = context.auth.uid;
  
  // 1. Verify signature with Razorpay secret
  const crypto = require('crypto');
  const expectedSig = crypto
    .createHmac('sha256', process.env.RAZORPAY_KEY_SECRET!)
    .update(`${razorpayOrderId}|${razorpayPaymentId}`)
    .digest('hex');
  
  if (expectedSig !== razorpaySignature) {
    await _logSecurityEvent('payment_verification_failed', {
      uid, razorpayPaymentId, razorpayOrderId,
      reason: 'Signature mismatch',
    });
    throw new functions.https.HttpsError('unauthenticated', 'Payment verification failed');
  }
  
  // 2. Verify with Razorpay API (server-to-server)
  const axios = require('axios');
  const auth = Buffer.from(`${process.env.RAZORPAY_KEY_ID}:${process.env.RAZORPAY_KEY_SECRET}`).toString('base64');
  
  const paymentResponse = await axios.get(
    `https://api.razorpay.com/v1/payments/${razorpayPaymentId}`,
    { headers: { Authorization: `Basic ${auth}` } },
  );
  
  const payment = paymentResponse.data;
  if (payment.status !== 'captured') {
    throw new functions.https.HttpsError('failed-precondition', 'Payment not captured');
  }
  
  // 3. Update subscription
  const periodEnd = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
  
  await db.collection('subscriptions').doc(uid).update({
    plan: planType === 'pro' ? 'pro_monthly' : 'basic_monthly',
    status: 'active',
    currentPeriodStart: admin.firestore.FieldValue.serverTimestamp(),
    currentPeriodEnd: admin.firestore.Timestamp.fromDate(periodEnd),
    payments: admin.firestore.FieldValue.arrayUnion([{
      razorpayPaymentId,
      razorpayOrderId,
      amount: payment.amount,
      currency: payment.currency,
      status: 'verified',
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      planPurchased: planType,
      periodStart: admin.firestore.FieldValue.serverTimestamp(),
      periodEnd: admin.firestore.Timestamp.fromDate(periodEnd),
    }]),
  });
  
  return { success: true, validUntil: periodEnd.toISOString() };
});
```

---

<a id="7-rules"></a>
## 7. Firestore Security Rules

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ==========================================
    // FUNCTIONS
    // ==========================================
    function isAuth() {
      return request.auth != null;
    }
    
    function isOwner(uid) {
      return request.auth.uid == uid;
    }
    
    function isAdmin() {
      return request.auth.token.admin == true;
    }
    
    function isFromCloudFunction() {
      // Cloud Functions use the Admin SDK which bypasses rules,
      // but we add this for defensive coding
      return request.auth.token.firebase.sign_in_provider == 'admin' 
          || request.auth.token.firebase.sign_in_provider == 'cloudfunctions';
    }

    // ==========================================
    // devices/{fingerprintHash}
    // ==========================================
    match /devices/{fingerprintHash} {
      // CREATE: Only through Cloud Function
      // For security, we block direct client writes
      allow create: if false;
      
      // READ: Only the owner of a linked subscription
      allow read: if isAuth() && (
        isAdmin() ||
        exists(/databases/$(database)/documents/subscriptions/$(request.auth.uid)) &&
        get(/databases/$(database)/documents/subscriptions/$(request.auth.uid)).data.activeDeviceFingerprint == fingerprintHash
      );
      
      // UPDATE: Only Cloud Function
      allow update: if isFromCloudFunction();
      
      // DELETE: Never
      allow delete: if false;
    }

    // ==========================================
    // subscriptions/{uid}
    // ==========================================
    match /subscriptions/{uid} {
      // Only the owner or admin can read their subscription
      allow read: if isAuth() && (isOwner(uid) || isAdmin());
      
      // Client writes are BLOCKED — only Cloud Function writes
      allow create: if false;
      allow update: if false;
      allow delete: if false;
    }

    // ==========================================
    // security_events/{eventId}
    // ==========================================
    match /security_events/{eventId} {
      // Only Cloud Functions can write
      allow create: if isFromCloudFunction();
      
      // Admin can read for auditing
      allow read: if isAuth() && isAdmin();
      
      allow update: if false;
      allow delete: if false;
    }

    // ==========================================
    // trial_requests/{requestId}
    // ==========================================
    match /trial_requests/{requestId} {
      allow create: if isFromCloudFunction();
      allow read: if false;  // Internal use only
      allow update: if false;
      allow delete: if false;
    }

    // ==========================================
    // shops/{uid} — Read/write by owner
    // ==========================================
    match /shops/{uid} {
      allow read: if isAuth() && (isOwner(uid) || isAdmin());
      allow create: if isAuth() && isOwner(uid);
      allow update: if isAuth() && isOwner(uid);
      allow delete: if false;
      
      // Validate shop data
      allow write: if request.resource.data.keys().hasAll(['name', 'ownerName', 'ownerPhone', 'createdAt']);
    }

    // ==========================================
    // items/{itemId}
    // ==========================================
    match /items/{itemId} {
      allow read: if isAuth();
      
      // Write blocked if subscription is not active or expired
      allow create: if isAuth() && 
        get(/databases/$(database)/documents/subscriptions/$(request.auth.uid)).data.status == 'active';
      allow update: if isAuth() &&
        get(/databases/$(database)/documents/subscriptions/$(request.auth.uid)).data.status == 'active';
      allow delete: if false;
    }

    // ==========================================
    // orders/{orderId}
    // ==========================================
    match /orders/{orderId} {
      allow read: if isAuth();
      allow create: if isAuth() &&
        get(/databases/$(database)/documents/subscriptions/$(request.auth.uid)).data.status == 'active';
      allow update: if false;
      allow delete: if false;
    }

    // ==========================================
    // CATCH-ALL: Deny everything else
    // ==========================================
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

---

<a id="8-time"></a>
## 8. Time Tamper Protection v2

The current implementation stores tamper attempts in `FlutterSecureStorage`. If a user wipes secure storage, tamper count resets.

### Server-validated time sync (v2)

```dart
// lib/core/services/time_sync_service.dart (refactored)

class TimeSyncService {
  // On app start:
  Future<SyncResult> verifyTime() async {
    // 1. Get the server time from Cloud Function
    final serverResult = await CloudFunctionService.getServerTime();
    
    if (serverResult == null) {
      // Offline fallback
      return _handleOfflineSync();
    }
    
    final serverTime = DateTime.parse(serverResult.serverTime);
    final deviceTime = DateTime.now();
    final diff = deviceTime.difference(serverTime).inSeconds.abs();
    
    // 2. If difference > 120s → likely tampered
    if (diff > 120) {
      await _recordTamperAttempt(diff);
      
      // Report to server
      await CloudFunctionService.reportTamperAttempt(diff: diff);
      
      return SyncResult.invalid(diff);
    }
    
    // 3. Cache the verified sync
    await _cacheSync(serverTime.millisecondsSinceEpoch, deviceTime.millisecondsSinceEpoch);
    return SyncResult.valid(diff);
  }
  
  Future<SyncResult> _handleOfflineSync() async {
    // Use the last cached sync
    final cached = await _getCachedSync();
    if (cached == null) {
      // Never synced → restricted mode
      return SyncResult.offlineNoSync();
    }
    
    // Check device clock hasn't rewound since last sync
    final deviceNow = DateTime.now().millisecondsSinceEpoch;
    if (deviceNow < cached.lastSyncDeviceMs) {
      // Clock went backwards → tamper
      await _recordTamperAttempt(cached.lastSyncDeviceMs - deviceNow);
      return SyncResult.invalid(cached.lastSyncDeviceMs - deviceNow);
    }
    
    // Use cached server offset
    final estimatedServerTime = deviceNow + cached.offset;
    return SyncResult.offlineWithEstimate(
      estimatedServerTime: estimatedServerTime,
      cachedAt: cached.lastSyncAt,
    );
  }
}
```

```javascript
// Cloud Function: getServerTime
export const getServerTime = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Login required');
  }
  return {
    serverTime: admin.firestore.Timestamp.now().toDate().toISOString(),
    nonce: crypto.randomBytes(16).toString('hex'),  // Prevent replay
  };
});
```

### Offline sync strategy
| Situation | Behavior |
|-----------|----------|
| Online with valid sync | Normal operation |
| Offline (has cached valid sync) | Full functionality for up to 24 hours |
| Offline (no cached sync) | Read-only mode |
| Offline (detected clock rewind) | Read-only + tamper record |

---

<a id="9-fraud"></a>
## 9. Anti-Fraud Protections

### 9.1 Suspicious reinstall detection

```javascript
// In Cloud Function registerTrial
async function _detectReinstall(fingerprintHash, deviceSignals) {
  // Look for devices with strongly overlapping signals
  const signalKeys = Object.keys(deviceSignals).filter(k => deviceSignals[k] != null);
  
  // If we have at least 3 matching non-volatile signals,
  // this is likely a reinstall with partial signal loss
  const similarDevices = await db.collection('devices')
    .where('signals.buildFingerprint', '==', deviceSignals.buildFingerprint)
    .where('signals.hardware', '==', deviceSignals.hardware)
    .get();
  
  if (similarDevices.size > 0) {
    // This device was seen before with different fingerprint
    // Flag for review but don't block outright
    await _logSecurityEvent('reinstall_detected', {
      oldFingerprint: similarDevices.docs[0].id,
      newFingerprint: fingerprintHash,
      matchCount: signalKeys.length,
    });
    
    // If this device has a history of abuse, block
    const oldDevice = similarDevices.docs[0].data();
    if (oldDevice.trial?.isBlacklisted || (oldDevice.trial?.suspiciousEmailChanges || 0) > 1) {
      return { isReinstall: true, shouldBlock: true };
    }
    
    return { isReinstall: true, shouldBlock: false };
  }
  
  return { isReinstall: false, shouldBlock: false };
}
```

### 9.2 Excessive account switching

```javascript
// In Cloud Function registerTrial
async function _checkAccountSwitching(fingerprintHash, email) {
  const deviceLogs = await db.collection('trial_requests')
    .where('fingerprintHash', '==', fingerprintHash)
    .orderBy('createdAt', 'desc')
    .limit(20)
    .get();
  
  const uniqueEmails = new Set(deviceLogs.docs.map(d => d.data().email));
  
  // More than 3 different emails on same device = abuse
  if (uniqueEmails.size > 3) {
    return { isAbusive: true, reason: 'Device used with multiple accounts' };
  }
  
  return { isAbusive: false };
}
```

### 9.3 VPN / IP abuse mitigation

Since Firebase Functions provide the request's IP via `context.rawRequest`, you can:

```javascript
// In Cloud Function
import { detect } from 'ip-location'; // or similar

export const registerTrial = functions.https.onCall(async (data, context) => {
  const ip = context.rawRequest.ip;
  
  // 1. Check if IP is from known datacenter/VPN
  // (Use a service like ip2location or maxmind)
  const ipInfo = await detect(ip);
  if (ipInfo.isProxy || ipInfo.isVPN || ipInfo.isHosting) {
    // Require additional verification
    return { requiresManualReview: true };
  }
  
  // 2. Check rate limit per IP
  const ipRequests = await db.collection('trial_requests')
    .where('ipAddress', '==', ip)
    .where('createdAt', '>=', new Date(Date.now() - 3600000))
    .get();
  
  if (ipRequests.size > 5) {
    throw new functions.https.HttpsError('resource-exhausted', 'Too many requests from this network');
  }
});
```

### 9.4 Offline abuse protection

```dart
// Client-side enforcement
class SubscriptionGuard {
  /// Called before every protected operation
  static Future<bool> canExecuteOperation(WidgetRef ref) async {
    final sub = ref.read(subscriptionProvider);
    final connectivity = ref.read(connectivityProvider);
    
    // 1. Check subscription
    if (!sub.isActive && !sub.isGraceActive) {
      return false;
    }
    
    // 2. If offline for more than 24 hours since last validation, block
    if (connectivity == ConnectivityResult.none) {
      final lastValidation = sub.lastServerValidatedAt;
      if (lastValidation != null && 
          DateTime.now().difference(lastValidation) > const Duration(hours: 24)) {
        return false;  // Force online re-validation
      }
    }
    
    return true;
  }
}
```

---

<a id="10-ux"></a>
## 10. UX & Conversion Strategy

### Warning banners (progressively stronger)

| Time remaining | Banner style | Action |
|---------------|-------------|--------|
| 7+ days | None | — |
| 3–7 days | Soft amber bar: "Free trial ends in X days" | None |
| 1–3 days | Orange bar with icon: "Trial ending soon — Renew to keep your data" | "Renew" button |
| 0 days (grace) | Red bar: "Trial expired — 2 days of grace remaining" | Prominent "Renew" CTA |
| Grace expired | Full-screen overlay → Read-only mode | "Renew Now" modal |

### Renewal conversion flow

```dart
class RenewalOptimizer {
  // Show smart prompts based on usage
  static void maybePromptUpgrade(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(orderCountProvider);
    final daysLeft = ref.watch(subscriptionProvider).daysRemaining;
    
    if (orders > 50 && daysLeft <= 5) {
      // Active user + near expiry → full-screen offer
      _showUpgradeOffer(context, ref);
    } else if (daysLeft <= 2) {
      // Urgency prompt
      _showUrgencyBanner(context, ref);
    } else if (daysLeft <= 7) {
      // Gentle reminder
      _showReminderSnackbar(context, ref);
    }
  }
}
```

### Grace period UX

```dart
// In billing_screen.dart
Widget _buildGraceBanner(int daysRemaining) {
  return Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Color(0xFFFEF3C7),  // Soft amber
          Color(0xFFFFF8E1),
        ],
      ),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Color(0xFFF59E0B).withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Trial expired — grace period active',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E)),
              ),
              const SizedBox(height: 2),
              Text(
                'You have $daysRemaining days to renew. After that, the app enters read-only mode.',
                style: TextStyle(fontSize: 11, color: Color(0xFFA16207)),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => context.push('/profile/renewal'),
          child: const Text('Renew', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ],
    ),
  );
}
```

---

<a id="11-migration"></a>
## 11. Migration Plan

### Phase 1: Foundation (Week 1)

| Step | What | Files |
|------|------|-------|
| 1.1 | Add dependencies | `pubspec.yaml`: `crypto`, `device_info_plus`, `play_integrity`, `package_info_plus` |
| 1.2 | Create `DeviceFingerprintService` | `lib/core/services/device_fingerprint_service.dart` |
| 1.3 | Create `IntegrityService` + root detection | `lib/core/services/integrity_service.dart` |
| 1.4 | Deploy Cloud Functions (trial, validate, verify payment, server time) | `functions/src/` |
| 1.5 | Create new Firestore collections (`devices`, `subscriptions`, `security_events`, `trial_requests`) | Firebase Console |
| 1.6 | Apply new Firestore security rules | Firebase Console |

### Phase 2: Migration (Week 2)

| Step | What | Details |
|------|------|---------|
| 2.1 | Backfill `devices` collection from existing `trial_devices` | One-time migration script |
| 2.2 | Backfill `subscriptions` collection from shops' subscription fields | One-time migration script |
| 2.3 | Update `shop_provider.dart` to call Cloud Function instead of direct Firestore | Remove `checkAndRegisterDeviceTrial()` call |
| 2.4 | Update `subscription_service.dart` to call Cloud Function `validateSubscription` | Remove local expiry logic |
| 2.5 | Update `checkout_screen.dart` and renewal to call Cloud Function `verifyPayment` | Remove direct shop update |

### Phase 3: Hardening (Week 3)

| Step | What | Files |
|------|------|-------|
| 3.1 | Add Play Integrity verification to `IntegrityService` | `lib/core/services/integrity_service.dart` |
| 3.2 | Add offline abuse checks | `SubscriptionGuard` |
| 3.3 | Add security event monitoring dashboard (Firebase Console → Extension) | Firebase Extensions |
| 3.4 | Update all feature-gating to use server response | `billing_screen.dart`, `items_screen.dart`, etc. |

### Phase 4: Rollout

```text
1. Deploy Cloud Functions → ✅
2. Apply Firestore rules → ✅
3. Release Flutter update (v2.0) with new fingerprint + Cloud Function calls
4. Monitor security_events collection for anomalies
5. After 30 days, delete old trial_devices collection
6. Remove old client-side validation code
```

### Rollback plan

```javascript
// Feature flag in Firestore
// collections/config/flags
{
  useServerValidation: true,  // Toggle to false to fall back to client-side
  blockNewTrials: false,      // Emergency kill switch for trial registration
  maintenanceMode: false,
}
```

```dart
// Client checks flag
final flags = await FirebaseFirestore.instance.collection('config').doc('flags').get();
if (flags.data()?['useServerValidation'] == true) {
  return _callCloudFunction();
} else {
  return _legacyClientValidation();
}
```

---

## Summary: Security posture improvement

| Threat | Before | After |
|--------|--------|-------|
| Reinstall → new trial | One deletable deviceId | Multi-signal fingerprint + server-side reinstall detection |
| APK repackage | None | Play Integrity API + signature verification |
| Root/emulator | None | Detection + server-side flagging |
| Offline clock rollback | Client tamper counter (deletable) | Server time anchor + offline fallback with restrictions |
| Firestore direct writes | App Check only | Rules block client writes to subscriptions/devices |
| Payment callback forging | None | Server-side Razorpay signature + API verification |
| Account switching | Email flag only | Server-side rate limits + device-email binding |
| IP/VPN abuse | None | IP reputation + rate limiting |
| Audit trail | None | Full `security_events` collection |
| Feature gating | Client-side | Server-authoritative via Cloud Function |
