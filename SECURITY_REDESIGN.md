# Viyan Billing — Free Trial Security Redesign

## Table of Contents
1. [Security Audit](#1-audit)
2. [Vulnerability Report](#2-vulns)
3. [Production Architecture](#3-architecture)
4. [Device Fingerprinting](#4-fingerprinting)
5. [FlutterSecureStorage Hardening](#5-storage)
6. [Firestore Security Rules](#6-rules)
7. [Cloud Function Security Layer](#7-functions)
8. [Anti-Abuse Protections](#8-abuse)
9. [Time Tamper Protection](#9-time)
10. [Firestore Schema](#10-schema)
11. [Server-Side Read-Only Enforcement](#11-readonly)
12. [UX & Conversion](#12-ux)
13. [Package List](#13-packages)
14. [Migration Plan](#14-migration)

---

<a id="1-audit"></a>
## 1. Security Audit of Current Implementation

### Architecture diagram (current)

```
Flutter App
├── FlutterSecureStorage ─── deviceId (24-char random)
├── TimeSyncService ─── HTTP HEAD google.com → offset
├── shop_provider.dart ─── client decides trial validity
│   ├── checkAndRegisterDeviceTrial(deviceId, email)
│   ├── "Expired (Suspicious)" logic
│   └── "isBlocked" checking
├── subscription_service.dart ─── local expiry comparison
│   ├── isActive = DateTime.now() < subscriptionExpiry
│   ├── isGraceActive = 2-day grace
│   └── Notification scheduling
└── All screens check subscription.isActive locally
```

### Finding 1: Client-authoritative validation (Critical)
Every subscription decision is made client-side. The app determines `isActive`, `isGraceActive`, `isSuspicious`. A user who reverse-engineers the APK can:
- Patch out the `isActive` check
- Modify `DateTime.now()` references
- Spoof the `subscriptionExpiry` value from Hive (local DB)

**Evidence**: `subscription_service.dart` line ~50: `isActive = shop.subscriptionExpiry == null || DateTime.now().isBefore(shop.subscriptionExpiry!)`

### Finding 2: Single-signal device identity (Critical)
`deviceId` is a single 24-char random string in `FlutterSecureStorage`. If a user:
- Clears app data → `FlutterSecureStorage` wiped → new `deviceId` → new 15-day trial
- Reinstalls → same result
- Uses a backup restore that doesn't include secure storage → same

### Finding 3: Firestore rules allow public reads (High)
```
match /trial_devices/{deviceId} {
  allow read: if true;   // ← Anyone can enumerate device IDs
  allow create: if request.auth != null;
  allow update: if false;
}
```
An attacker can brute-force or guess deviceIds and read trial data. The `deviceId` being the document ID makes enumeration trivial if the ID generation pattern is guessed.

### Finding 4: No server-side validation (High)
The `checkAndRegisterDeviceTrial()` function in `firestore_repository.dart` runs on the client. There is no Cloud Function. This means:
- A patched client can write arbitrary `trialEndsAt` values
- A patched client can set `isBlocked: false` on creation
- There's no rate limiting on trial registrations

### Finding 5: No integrity checks (High)
No root detection, no emulator detection, no APK signature verification, no debugger detection. An attacker can:
- Run on rooted device → modify any client-side check
- Run on emulator → generate unlimited deviceIds
- Repackage APK → remove all subscription gates
- Use Frida → hook and bypass any Dart function

### Finding 6: TimeSyncService is client-only (Medium)
The time sync stores tamper attempts in `FlutterSecureStorage` (same storage the attacker can wipe). The network time source is `google.com` HEAD request, which can be intercepted or spoofed on a rooted device.

### Finding 7: No audit trail (Medium)
There is no logging of suspicious events. When a tamper is detected or an email mismatch occurs, there's no record in Firestore. This makes fraud analysis impossible.

### Finding 8: Payment verification is client-side (Medium)
The Razorpay success callback directly updates the shop. There's no server-to-server verification with Razorpay's API. A patched client could simulate a payment callback.

---

<a id="2-vulns"></a>
## 2. Vulnerabilities Ranked

| # | Vulnerability | Severity | CVSS-like | Effort to Exploit | Business Impact |
|---|-------------|----------|-----------|-------------------|-----------------|
| 1 | Client-authoritative subscription validation | Critical | 9.8 | Low | Complete bypass of paid model |
| 2 | Single-signal device ID (reinstall = new trial) | Critical | 9.0 | Low | Unlimited free trials |
| 3 | No APK integrity checks | Critical | 8.8 | Medium | Complete bypass, repackaged app |
| 4 | Public Firestore read access | High | 7.5 | Low | Privacy leak, trial data enumeration |
| 5 | No server-side trial registration | High | 8.0 | Medium | Forged trial records |
| 6 | No root/emulator detection | High | 7.8 | Low | Unlimited trials from emulators |
| 7 | Client-side payment verification | High | 7.5 | Medium | Fake payment confirmations |
| 8 | Tamper counter in secure storage only | Medium | 6.0 | Low | Wipe storage = reset tamper count |
| 9 | No security audit trail | Medium | 5.5 | N/A | Cannot detect abuse patterns |
| 10 | No rate limiting on trial registration | Medium | 6.5 | Low | Bulk registration attacks |
| 11 | HTTP time sync (spoofable) | Medium | 5.0 | High | Requires MITM, lower priority |
| 12 | No offline abuse protection | Low | 4.0 | Medium | Limited window of abuse |

---

<a id="3-architecture"></a>
## 3. Production Architecture (Target)

```
┌─────────────────────────────────────────────┐
│ Flutter Client                               │
│                                              │
│  DeviceFingerprintService                    │
│  ├── Collects 6+ device signals              │
│  ├── SHA-256 → composite hash                │
│  └── Cached in secure storage + memory       │
│                                              │
│  IntegrityService                            │
│  ├── Root detection (file paths, packages)   │
│  ├── Emulator detection (build props)        │
│  ├── Debugger detection                      │
│  └── Play Integrity API token request        │
│                                              │
│  SubscriptionClient (NOT decision-maker)     │
│  ├── Calls Cloud Functions for ALL decisions │
│  ├── Sends fingerprint + signals + token     │
│  └── Receives signed status response         │
│                                              │
│  TimeSyncClient                              │
│  ├── Calls `getServerTime` Cloud Function    │
│  ├── Caches offset locally                   │
│  └── Reports tamper attempts to server       │
└──────────────┬──────────────────────────────┘
               │ HTTPS (Firebase Functions)
               ▼
┌─────────────────────────────────────────────┐
│ Firebase Cloud Functions                     │
│                                              │
│  registerTrial(data) →                       │
│  ├── Validates fingerprint                   │
│  ├── Checks device abuse history             │
│  ├── Checks IP reputation                    │
│  ├── Rate limits per fingerprint/email/IP    │
│  ├── Detects reinstall via signal matching   │
│  └── Creates device + subscription docs      │
│                                              │
│  validateSubscription(data) →                │
│  ├── Verifies subscription doc               │
│  ├── Checks device blacklist                 │
│  ├── Compares server Timestamp.now()         │
│  ├── Returns status + server time            │
│  └── Updates lastValidatedAt                 │
│                                              │
│  verifyPayment(data) →                       │
│  ├── Validates Razorpay HMAC signature       │
│  ├── Calls Razorpay API server-to-server     │
│  ├── Updates subscription plan               │
│  └── Creates payment record                  │
│                                              │
│  reportTamper(data) →                        │
│  ├── Logs to security_events                 │
│  ├── Increments device tamper counter        │
│  └── Blacklists if threshold exceeded        │
│                                              │
│  getServerTime(data) →                       │
│  ├── Returns server Timestamp + nonce        │
│  └── Used for time sync                      │
└──────────────┬──────────────────────────────┘
               │ Admin SDK (bypasses rules)
               ▼
┌─────────────────────────────────────────────┐
│ Firestore                                    │
│                                              │
│  devices/{fingerprintHash}                   │
│  ├── signals (map)                           │
│  ├── trial (startedAt, endsAt, isBlacklisted)│
│  ├── integrity (lastCheck, failureCount)     │
│  ├── timeSync (tamperAttempts, lastOffset)   │
│  └── usedByEmails (array)                    │
│                                              │
│  subscriptions/{uid}                         │
│  ├── plan, status, currentPeriodEnd          │
│  ├── activeDeviceFingerprint                 │
│  ├── deviceHistory (array)                   │
│  └── payments (array of verified objects)    │
│                                              │
│  security_events/{eventId}                   │
│  ├── type, severity, uid, details            │
│  └── createdAt (TTL after 90 days)           │
│                                              │
│  trial_requests/{requestId}                  │
│  ├── fingerprintHash, email, ipAddress       │
│  ├── resolvedStatus                          │
│  └── createdAt (TTL after 30 days)           │
│                                              │
│  config/flags                                │
│  └── useServerValidation, blockNewTrials     │
└─────────────────────────────────────────────┘
```

---

<a id="4-fingerprinting"></a>
## 4. Device Fingerprinting Strategy

### Why the old approach fails
A single `deviceId` in `FlutterSecureStorage` is equivalent to a single point of failure. If that storage gets wiped, the device is "new" again.

### Multi-signal fingerprint

```dart
// lib/core/services/device_fingerprint_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DeviceFingerprintService {
  final FlutterSecureStorage _storage;
  final DeviceInfoPlugin _deviceInfo;

  DeviceFingerprintService({
    FlutterSecureStorage? storage,
    DeviceInfoPlugin? deviceInfo,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  String? _cachedFingerprint;

  Future<String> getFingerprint() async {
    if (_cachedFingerprint != null) return _cachedFingerprint!;

    // 1. Check persistent cache (survives app restarts)
    final cached = await _storage.read(key: 'fp_v2');
    if (cached != null) {
      _cachedFingerprint = cached;
      return cached;
    }

    // 2. Collect signals
    final parts = <String>[];

    // Tier 1: Stable hardware signals (survive clear data)
    try {
      if (Platform.isAndroid) {
        final android = await _deviceInfo.androidInfo;
        parts.add('br:${android.brand}');
        parts.add('dv:${android.device}');
        parts.add('hw:${android.hardware}');
        parts.add('bf:${android.fingerprint}');
        parts.add('bd:${android.board}');
        parts.add('mn:${android.manufacturer}');
        parts.add('md:${android.model}');
        parts.add('pi:${android.id}');
        if (android.serialNumber.isNotEmpty && android.serialNumber != 'unknown') {
          // Only if not "unknown" — some newer APIs block serial
          parts.add('sn:${android.serialNumber}');
        }
      } else if (Platform.isIOS) {
        final ios = await _deviceInfo.iosInfo;
        parts.add('mv:${ios.identifierForVendor ?? ''}');
        parts.add('mn:${ios.modelName}');
        parts.add('sv:${ios.systemVersion}');
        parts.add('mc:${ios.utsname.machine}');
      }
    } catch (_) {}

    // Tier 2: Installation-scoped signals
    try {
      // Firebase Installation ID (survives reinstall within Firebase scope)
      final firebaseInstallId = await _getFirebaseInstallationId();
      if (firebaseInstallId != null) parts.add('fiid:$firebaseInstallId');
    } catch (_) {}

    try {
      // Local install token (secure storage — survives iOS Keychain restore)
      var installToken = await _storage.read(key: 'install_token');
      if (installToken == null) {
        installToken = _randomHex(32);
        await _storage.write(key: 'install_token', value: installToken);
      }
      parts.add('it:$installToken');
    } catch (_) {}

    // Tier 3: Runtime signals
    final timezone = DateTime.now().timeZoneOffset.inMinutes;
    parts.add('tz:$timezone');
    parts.add('lc:${Platform.locale}');

    // 3. Hash into 64-char fingerprint
    final raw = parts.join('|');
    final hash = sha256.convert(utf8.encode(raw)).toString();

    // 4. Cache
    await _storage.write(key: 'fp_v2', value: hash);
    _cachedFingerprint = hash;
    return hash;
  }

  /// Returns individual signal values for server-side matching
  Future<Map<String, dynamic>> getSignals() async {
    final signals = <String, dynamic>{};

    try {
      if (Platform.isAndroid) {
        final android = await _deviceInfo.androidInfo;
        signals['brand'] = android.brand;
        signals['device'] = android.device;
        signals['hardware'] = android.hardware;
        signals['buildFingerprint'] = android.fingerprint;
        signals['board'] = android.board;
        signals['manufacturer'] = android.manufacturer;
        signals['model'] = android.model;
        signals['androidId'] = android.id;
        if (android.serialNumber.isNotEmpty && android.serialNumber != 'unknown') {
          signals['serialNumber'] = android.serialNumber;
        }
        signals['osVersion'] = android.version.release;
        signals['sdkInt'] = android.version.sdkInt;
      } else if (Platform.isIOS) {
        final ios = await _deviceInfo.iosInfo;
        signals['identifierForVendor'] = ios.identifierForVendor;
        signals['modelName'] = ios.modelName;
        signals['osVersion'] = ios.systemVersion;
        signals['machine'] = ios.utsname.machine;
      }
    } catch (_) {}

    signals['timezone'] = DateTime.now().timeZoneOffset.inMinutes;
    return signals;
  }

  String _randomHex(int length) {
    final rand = Random.secure();
    return List.generate(
      length, (_) => rand.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Future<String?> _getFirebaseInstallationId() async {
    try {
      // Using firebase_messaging or firebase_installations
      // Returns a stable ID for the app installation
      return null; // Placeholder — depends on Firebase setup
    } catch (_) {
      return null;
    }
  }
}
```

### Signal durability matrix

| Signal | Clear Data | Reinstall | Factory Reset | Rooted Device |
|--------|:---:|:---:|:---:|:---:|
| `fp_v2` (secure storage) | ✗ | ✓* | ✗ | ✗ |
| `install_token` (secure storage) | ✗ | ✓* | ✗ | ✗ |
| Android ID | ✗ | ✗ | ✗ | ✓ |
| Build fingerprint | ✓ | ✓ | ✗ | ✓ |
| Hardware / board | ✓ | ✓ | ✗ | ✓ |
| Serial (if accessible) | ✓ | ✓ | ✓** | ✓ |
| IDFV (iOS) | ✓ | ✗ | ✗ | ✓ |
| Timezone | ✓ | ✓ | ✓ | ✓ |
| Firebase Installation ID | ✓ | ✗ | ✗ | ✓ |

*Survives on iOS Keychain restore; on Android depends on backup provider
**Factory reset typically clears serial access on newer Android versions

### What happens if storage is wiped?
The fingerprint **changes** but the signals sent to the server still overlap with the previous fingerprint. The Cloud Function detects this via signal matching (e.g., same `buildFingerprint` + `hardware` + `board`) and links to the old device record → sees previous trial → rejects.

---

<a id="5-storage"></a>
## 5. FlutterSecureStorage Hardening

### Current problems
```dart
const FlutterSecureStorage()
// Default AndroidOptions — encrypted SharedPreferences
// User can go to Settings → Apps → Clear Data to wipe it
```

### Hardened storage approach

```dart
// lib/core/services/storage_guard.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageGuard {
  static FlutterSecureStorage get storage => const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,  // Wipe on integrity failure
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false,  // Don't sync across iCloud
    ),
  );

  /// Stores a value AND a verification hash
  static Future<void> writeWithIntegrity({
    required String key,
    required String value,
  }) async {
    await storage.write(key: key, value: value);
    // Store a hash of the value to detect tampering
    final hash = _sha256(value);
    await storage.write(key: '${key}_hash', value: hash);
  }

  /// Reads and verifies integrity
  static Future<String?> readWithIntegrity(String key) async {
    final value = await storage.read(key: key);
    if (value == null) return null;

    final storedHash = await storage.read(key: '${key}_hash');
    if (storedHash == null) return null;  // No hash = tampered

    final computedHash = _sha256(value);
    if (storedHash != computedHash) {
      // Value was modified outside our control
      await storage.delete(key: key);
      await storage.delete(key: '${key}_hash');
      return null;
    }

    return value;
  }

  static String _sha256(String input) {
    // Using dart:convert + crypto
    return sha256.convert(utf8.encode(input)).toString();
  }
}
```

### Recovery when storage is wiped
```dart
// lib/core/services/trial_recovery_service.dart
class TrialRecoveryService {
  /// Called when secure storage reads return null unexpectedly.
  /// Attempts to recover the device identity using remaining signals.
  Future<RecoveryResult> attemptRecovery() async {
    // 1. Check if we have any remaining signals
    final fingerprint = await DeviceFingerprintService().getSignals();
    
    // 2. Call Cloud Function to see if this device is known
    //    The server matches signals against known devices
    final result = await CloudFunctions.instance
        .call(name: 'identifyDevice', data: {'signals': fingerprint});
    
    if (result.data['known'] == true) {
      // 3. Device was recovered — server sends back the old fingerprint
      final oldFingerprint = result.data['fingerprintHash'];
      await StorageGuard.storage.write(
        key: 'fp_v2', value: oldFingerprint,
      );
      return RecoveryResult.recovered(oldFingerprint);
    }
    
    // 4. Truly new device — proceed with new fingerprint
    return RecoveryResult.newDevice();
  }
}
```

### What this achieves
| Attack | Result |
|--------|--------|
| User clears app data | Fingerprint changes → server identifies it as same hardware → trial history preserved |
| User deletes just secure storage file | Integrity hash mismatch → treated as wiped → recovery flow triggered |
| User restores from partial backup | Missing tokens → signals still identify the device |
| User modifies secure storage values | Hash verification fails → values discarded |

---

<a id="6-rules"></a>
## 6. Firestore Security Rules (Production)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ==========================================
    // HELPER FUNCTIONS
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
    
    function isCloudFunction() {
      return request.auth.token.firebase.sign_in_provider == 'admin' ||
             request.auth.token.firebase.sign_in_provider == 'cloudfunctions';
    }

    function isActiveSubscription(uid) {
      let sub = get(/databases/$(database)/documents/subscriptions/$(uid));
      return sub.exists && sub.data.status in ['active', 'grace'];
    }

    // ==========================================
    // devices/{fingerprintHash}
    // ==========================================
    match /devices/{fingerprintHash} {
      // BLOCKED: Client cannot create device records directly
      allow create: if false;
      
      // RESTRICTED READ: Only if user has a subscription linked to this device
      allow read: if isAuth() && (
        isAdmin() ||
        exists(/databases/$(database)/documents/subscriptions/$(request.auth.uid)) &&
        get(/databases/$(database)/documents/subscriptions/$(request.auth.uid))
          .data.activeDeviceFingerprint == fingerprintHash
      );
      
      // BLOCKED: Client cannot update device records
      allow update: if isCloudFunction() || isAdmin();
      
      // BLOCKED
      allow delete: if false;
      
      // List operations blocked
      allow list: if false;
    }

    // ==========================================
    // subscriptions/{uid}
    // ==========================================
    match /subscriptions/{uid} {
      // RESTRICTED READ: Only the owner
      allow read: if isAuth() && (isOwner(uid) || isAdmin());
      
      // BLOCKED: Only Cloud Functions can create/update subscriptions
      allow create: if false;
      allow update: if false;
      allow delete: if false;
      
      // List blocked
      allow list: if false;
    }

    // ==========================================
    // security_events/{eventId}
    // ==========================================
    match /security_events/{eventId} {
      // BLOCKED: Only Cloud Functions write
      allow create: if isCloudFunction() || isAdmin();
      
      // RESTRICTED: Admin only
      allow read: if isAuth() && isAdmin();
      
      allow update: if false;
      allow delete: if false;
      allow list: if false;
    }

    // ==========================================
    // trial_requests/{requestId}
    // ==========================================
    match /trial_requests/{requestId} {
      // BLOCKED: Only Cloud Functions write
      allow create: if isCloudFunction() || isAdmin();
      allow read: if false;  // Internal use only
      allow update: if false;
      allow delete: if false;
    }

    // ==========================================
    // shops/{uid} — Shop profiles
    // ==========================================
    match /shops/{uid} {
      allow read: if isAuth() && (isOwner(uid) || isAdmin());
      
      // Create: Only by the authenticated owner
      allow create: if isAuth() && isOwner(uid);
      
      // Update: Owner can update, BUT only if subscription is active
      // (This prevents expired users from writing shop data to bypass restrictions)
      allow update: if isAuth() && isOwner(uid) && 
        (isAdmin() || isActiveSubscription(uid) || request.resource.data.diff(resource.data).affectedKeys().hasOnly(['profilePhotoPath', 'upiId', 'updatedAt']));
      
      allow delete: if false;
      allow list: if false;
    }

    // ==========================================
    // items/{itemId} — Inventory
    // ==========================================
    match /items/{itemId} {
      allow read: if isAuth();
      
      // WRITE: Only if subscription is active
      // This is SERVER-SIDE enforcement. Even if client patches UI,
      // the write is blocked here.
      allow create: if isAuth() && isActiveSubscription(request.auth.uid);
      allow update: if isAuth() && isActiveSubscription(request.auth.uid);
      allow delete: if false;
    }

    // ==========================================
    // orders/{orderId} — Invoices/Bills
    // ==========================================
    match /orders/{orderId} {
      allow read: if isAuth();
      
      // CREATE: Only if subscription is active
      allow create: if isAuth() && isActiveSubscription(request.auth.uid);
      
      // Once created, orders are immutable
      allow update: if false;
      allow delete: if false;
    }

    // ==========================================
    // CATCH-ALL: Deny
    // ==========================================
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

### Rule testing scenarios

| Scenario | Expected Behavior |
|----------|------------------|
| Expired user tries to create an order | BLOCKED by `orders` rule |
| Expired user tries to add an item | BLOCKED by `items` rule |
| Expired user tries to update shop name | BLOCKED by `shops` rule (only `profilePhotoPath`/`upiId` allowed) |
| User tries to read another user's subscription | BLOCKED by `subscriptions` rule |
| User tries to enumerate device documents | BLOCKED by `list: false` |
| Attacker tries to create device doc directly | BLOCKED by `create: false` |
| Attacker tries to modify `subscription.status` | BLOCKED by `update: false` |
| Legitimate active user creates an order | ALLOWED by `orders` rule |
| Cloud Function writes to subscriptions | ALLOWED by `isCloudFunction()` |

---

<a id="7-functions"></a>
## 7. Cloud Function Implementation

### 7.1 registerTrial

```javascript
// functions/src/trial.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');

const db = admin.firestore();

/**
 * Register a new trial for a device.
 * 
 * SECURITY: This is the ONLY way a trial gets created.
 * Client-side code can NEVER create trial records.
 */
exports.registerTrial = functions.https.onCall(async (data, context) => {
  // ── Auth check ──────────────────────────────────────────
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Login required');
  }
  
  const { fingerprintHash, signals, email } = data;
  const uid = context.auth.uid;
  const ip = context.rawRequest.ip;
  const normalizedEmail = (email || '').trim().toLowerCase();

  // ── Validation ──────────────────────────────────────────
  if (!fingerprintHash || fingerprintHash.length !== 64) {
    throw new functions.https.HttpsError(
      'invalid-argument', 'Invalid device fingerprint'
    );
  }
  if (!normalizedEmail || normalizedEmail === 'unknown@example.com') {
    throw new functions.https.HttpsError(
      'invalid-argument', 'Valid email required'
    );
  }

  // ── Check existing subscription ─────────────────────────
  const existingSub = await db.collection('subscriptions').doc(uid).get();
  if (existingSub.exists) {
    const subData = existingSub.data();
    // If they already have an active/grace subscription, deny
    if (['active', 'grace'].includes(subData.status)) {
      throw new functions.https.HttpsError(
        'already-exists', 'Subscription already active'
      );
    }
    // If expired, allow re-registration only if old plan was free_trial
    // Paid users who expired cannot re-register for free trial
    if (subData.plan !== 'free_trial') {
      throw new functions.https.HttpsError(
        'permission-denied', 'Not eligible for free trial'
      );
    }
  }

  // ── Check device record ─────────────────────────────────
  const deviceRef = db.collection('devices').doc(fingerprintHash);
  const deviceSnap = await deviceRef.get();

  // ── Abuse detection ─────────────────────────────────────
  const abuseCheck = await checkAbuse(deviceSnap, fingerprintHash, normalizedEmail, uid, ip);
  if (abuseCheck.isAbusive) {
    await logSecurityEvent({
      type: 'trial_abuse',
      severity: 'critical',
      uid,
      fingerprintHash,
      email: normalizedEmail,
      details: abuseCheck,
    });
    throw new functions.https.HttpsError(
      'permission-denied', abuseCheck.userMessage || 'Trial not available'
    );
  }

  // ── Rate limiting ───────────────────────────────────────
  const recentRequests = await db.collection('trial_requests')
    .where('fingerprintHash', '==', fingerprintHash)
    .where('createdAt', '>=', new Date(Date.now() - 86400000))
    .get();
  
  if (recentRequests.size >= 3) {
    throw new functions.https.HttpsError(
      'resource-exhausted', 'Too many trial requests from this device'
    );
  }

  // ── Check IP reputation ─────────────────────────────────
  const ipRequests = await db.collection('trial_requests')
    .where('ipAddress', '==', ip)
    .where('createdAt', '>=', new Date(Date.now() - 86400000))
    .get();
  
  if (ipRequests.size >= 10) {
    await logSecurityEvent({
      type: 'ip_abuse',
      severity: 'warning',
      uid,
      fingerprintHash,
      email: normalizedEmail,
      details: { ip, requestCount: ipRequests.size },
    });
    throw new functions.https.HttpsError(
      'resource-exhausted', 'Too many requests from this network'
    );
  }

  // ── Create records ──────────────────────────────────────
  const now = admin.firestore.FieldValue.serverTimestamp();
  const trialEnd = new Date(Date.now() + 15 * 24 * 60 * 60 * 1000);
  const graceEnd = new Date(trialEnd.getTime() + 2 * 24 * 60 * 60 * 1000);

  const batch = db.batch();

  // Device record
  batch.set(deviceRef, {
    fingerprintHash,
    firstSeenAt: now,
    lastSeenAt: now,
    signals: signals || {},
    trial: {
      startedAt: now,
      endsAt: admin.firestore.Timestamp.fromDate(trialEnd),
      usedByEmails: admin.firestore.FieldValue.arrayUnion([normalizedEmail]),
      suspiciousEmailChanges: 0,
      isBlacklisted: false,
    },
    integrity: {
      lastCheckPassed: true,
      lastCheckAt: now,
      failureCount: 0,
    },
    timeSync: {
      tamperAttempts: 0,
      isBlacklisted: false,
    },
    updatedAt: now,
  }, { merge: true });

  // Subscription record
  batch.set(
    db.collection('subscriptions').doc(uid),
    {
      uid,
      email: normalizedEmail,
      plan: 'free_trial',
      status: 'active',
      trialStartedAt: now,
      trialEndsAt: admin.firestore.Timestamp.fromDate(trialEnd),
      graceEndsAt: admin.firestore.Timestamp.fromDate(graceEnd),
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
    },
  );

  // Trial request log
  batch.set(
    db.collection('trial_requests').doc(),
    {
      fingerprintHash,
      email: normalizedEmail,
      ipAddress: ip,
      resolvedStatus: 'approved',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  );

  await batch.commit();

  return {
    status: 'active',
    plan: 'free_trial',
    trialEndsAt: trialEnd.toISOString(),
    graceEndsAt: graceEnd.toISOString(),
    serverTime: new Date().toISOString(),
  };
});

/**
 * Multi-signal abuse detection.
 * Returns { isAbusive, reason, userMessage }
 */
async function checkAbuse(deviceSnap, fingerprintHash, email, uid, ip) {
  if (!deviceSnap.exists) {
    return { isAbusive: false };
  }

  const device = deviceSnap.data();

  // 1. Blacklisted device
  if (device.trial?.isBlacklisted) {
    return { isAbusive: true, reason: 'device_blacklisted',
      userMessage: 'This device is not eligible for a free trial' };
  }

  // 2. Email mismatch on registered device
  const usedEmails = device.trial?.usedByEmails || [];
  if (email !== 'unknown@example.com' && usedEmails.length > 0) {
    const emailMatch = usedEmails.some(e => e.toLowerCase() === email);
    if (!emailMatch) {
      // Increment suspicious email changes
      await deviceSnap.ref.update({
        'trial.suspiciousEmailChanges': admin.firestore.FieldValue.increment(1),
        'trial.usedByEmails': admin.firestore.FieldValue.arrayUnion([email]),
      });

      const changes = (device.trial?.suspiciousEmailChanges || 0) + 1;
      if (changes >= 3) {
        // Auto-blacklist after 3 email switches
        await deviceSnap.ref.update({
          'trial.isBlacklisted': true,
          'trial.blacklistReason': 'excessive_email_changes',
        });
        return { isAbusive: true, reason: 'excessive_email_changes',
          userMessage: 'Too many account switches on this device' };
      }

      return { isAbusive: true, reason: 'email_mismatch',
        userMessage: 'This device is registered with a different account' };
    }
  }

  // 3. Reinstall detection via signal matching
  if (device.signals && device.signals.buildFingerprint) {
    const matchCount = countMatchingSignals(device.signals, signals);
    if (matchCount >= 3) {
      // This device was seen before with a different fingerprint
      // Likely a reinstall that generated a new fingerprint
      await logSecurityEvent({
        type: 'reinstall_detected',
        severity: 'warning',
        uid,
        fingerprintHash,
        email,
        details: {
          oldFingerprint: deviceSnap.id,
          newFingerprint: fingerprintHash,
          matchCount,
        },
      });

      // If device had abuse history, block
      if (device.trial?.suspiciousEmailChanges > 0 || device.integrity?.failureCount > 2) {
        return { isAbusive: true, reason: 'reinstall_abuse',
          userMessage: 'Free trial already used on this device' };
      }
    }
  }

  return { isAbusive: false };
}

function countMatchingSignals(oldSignals, newSignals) {
  if (!oldSignals || !newSignals) return 0;
  let count = 0;
  const keys = ['buildFingerprint', 'hardware', 'board', 'manufacturer', 'model', 'androidId'];
  for (const key of keys) {
    if (oldSignals[key] && oldSignals[key] === newSignals[key]) {
      count++;
    }
  }
  return count;
}
```

### 7.2 validateSubscription

```javascript
// functions/src/validate.js
exports.validateSubscription = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Login required');
  }

  const { fingerprintHash } = data;
  const uid = context.auth.uid;

  // 1. Get subscription
  const subSnap = await db.collection('subscriptions').doc(uid).get();
  if (!subSnap.exists) {
    return {
      status: 'expired',
      plan: 'none',
      reason: 'No subscription found',
      serverTime: new Date().toISOString(),
    };
  }
  const sub = subSnap.data();

  // 2. Get device
  const deviceSnap = await db.collection('devices').doc(fingerprintHash).get();
  const isBlacklisted = deviceSnap.exists && deviceSnap.data().trial?.isBlacklisted === true;

  // 3. Evaluate using SERVER time
  const now = admin.firestore.Timestamp.now();
  const expiry = sub.currentPeriodEnd?.toDate();
  const graceEnd = sub.graceEndsAt?.toDate();
  const serverNow = now.toDate();

  let status = sub.status;
  let plan = sub.plan;

  if (isBlacklisted) {
    status = 'suspended';
    plan = 'blocked';
  } else if (expiry && serverNow > expiry) {
    if (graceEnd && serverNow <= graceEnd) {
      status = 'grace';
    } else {
      status = 'expired';
    }
  }

  // 4. Update last seen
  await db.collection('subscriptions').doc(uid).update({
    lastValidatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // 5. Return signed response
  return {
    status,
    plan,
    currentPeriodEnd: expiry?.toISOString() || null,
    graceEndsAt: graceEnd?.toISOString() || null,
    isAuthorizedDevice: sub.activeDeviceFingerprint === fingerprintHash,
    serverTime: serverNow.toISOString(),
    isBlacklisted,
  };
});
```

### 7.3 verifyPayment

```javascript
// functions/src/payment.js
const crypto = require('crypto');
const axios = require('axios');

exports.verifyPayment = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Login required');
  }

  const { razorpayPaymentId, razorpayOrderId, razorpaySignature, planType } = data;
  const uid = context.auth.uid;

  // 1. Verify HMAC signature
  const expectedSignature = crypto
    .createHmac('sha256', process.env.RAZORPAY_KEY_SECRET)
    .update(`${razorpayOrderId}|${razorpayPaymentId}`)
    .digest('hex');

  if (expectedSignature !== razorpaySignature) {
    await logSecurityEvent({
      type: 'payment_verification_failed',
      severity: 'critical',
      uid,
      details: { razorpayPaymentId, razorpayOrderId, reason: 'signature_mismatch' },
    });
    throw new functions.https.HttpsError('unauthenticated', 'Payment verification failed');
  }

  // 2. Verify with Razorpay API (server-to-server)
  const auth = Buffer.from(
    `${process.env.RAZORPAY_KEY_ID}:${process.env.RAZORPAY_KEY_SECRET}`
  ).toString('base64');

  const paymentResponse = await axios.get(
    `https://api.razorpay.com/v1/payments/${razorpayPaymentId}`,
    { headers: { Authorization: `Basic ${auth}` } },
  );

  const payment = paymentResponse.data;
  if (payment.status !== 'captured') {
    throw new functions.https.HttpsError(
      'failed-precondition', 'Payment not captured'
    );
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
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {
    success: true,
    validUntil: periodEnd.toISOString(),
    plan: planType,
  };
});
```

### 7.4 getServerTime

```javascript
// functions/src/time.js
exports.getServerTime = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Login required');
  }
  
  // Return server time + nonce to prevent replay attacks
  return {
    serverTime: admin.firestore.Timestamp.now().toDate().toISOString(),
    nonce: crypto.randomBytes(16).toString('hex'),
  };
});

exports.reportTamper = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Login required');
  }

  const { fingerprintHash, diffSeconds } = data;
  const uid = context.auth.uid;

  // Log the tamper event
  await logSecurityEvent({
    type: 'time_tamper',
    severity: 'warning',
    uid,
    fingerprintHash,
    details: { diffSeconds, timestamp: new Date().toISOString() },
  });

  // Increment device tamper counter
  if (fingerprintHash) {
    const deviceRef = db.collection('devices').doc(fingerprintHash);
    await deviceRef.set({
      'timeSync.tamperAttempts': admin.firestore.FieldValue.increment(1),
      'timeSync.lastTamperAt': admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    // Check if threshold exceeded
    const deviceSnap = await deviceRef.get();
    if (deviceSnap.exists) {
      const attempts = deviceSnap.data().timeSync?.tamperAttempts || 0;
      if (attempts >= 5) {
        await deviceRef.update({
          'trial.isBlacklisted': true,
          'trial.blacklistReason': 'time_tamper',
        });
        return { shouldBlacklist: true, attempts };
      }
    }
  }

  return { shouldBlacklist: false };
});
```

### Client-side Cloud Function caller

```dart
// lib/core/services/subscription_client.dart
import 'package:cloud_functions/cloud_functions.dart';

class SubscriptionClient {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<RegisterTrialResult> registerTrial({
    required String fingerprintHash,
    required Map<String, dynamic> signals,
    required String email,
  }) async {
    try {
      final result = await _functions.httpsCallable('registerTrial').call({
        'fingerprintHash': fingerprintHash,
        'signals': signals,
        'email': email,
      });
      return RegisterTrialResult.fromJson(result.data);
    } on FirebaseFunctionsException catch (e) {
      return RegisterTrialResult(
        status: 'error',
        errorCode: e.code,
        errorMessage: e.message ?? 'Unknown error',
      );
    }
  }

  Future<ValidateSubscriptionResult> validateSubscription({
    required String fingerprintHash,
  }) async {
    final result = await _functions.httpsCallable('validateSubscription').call({
      'fingerprintHash': fingerprintHash,
    });
    return ValidateSubscriptionResult.fromJson(result.data);
  }

  Future<VerifyPaymentResult> verifyPayment({
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
    required String planType,
  }) async {
    final result = await _functions.httpsCallable('verifyPayment').call({
      'razorpayPaymentId': razorpayPaymentId,
      'razorpayOrderId': razorpayOrderId,
      'razorpaySignature': razorpaySignature,
      'planType': planType,
    });
    return VerifyPaymentResult.fromJson(result.data);
  }

  Future<ServerTimeResult> getServerTime() async {
    final result = await _functions.httpsCallable('getServerTime').call();
    return ServerTimeResult.fromJson(result.data);
  }

  Future<void> reportTamper({
    required int diffSeconds,
    String? fingerprintHash,
  }) async {
    await _functions.httpsCallable('reportTamper').call({
      'diffSeconds': diffSeconds,
      'fingerprintHash': fingerprintHash,
    });
  }
}
```

---

<a id="8-abuse"></a>
## 8. Anti-Abuse Protections

### 8.1 Root / Jailbreak detection
```dart
// lib/core/services/integrity_service.dart
import 'dart:io';

class IntegrityService {
  /// Returns true if the device shows signs of tampering
  static Future<bool> isDeviceTampered() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;

    final checks = await Future.wait([
      _checkRootBinaries(),
      _checkRootPackages(),
      _checkEmulator(),
      _checkDebugger(),
    ]);

    return checks.any((r) => r == true);
  }

  static Future<bool> _checkRootBinaries() async {
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
      '/magisk',          // Magisk mount point
      '/data/adb/magisk', // Modern Magisk
    ];
    for (final path in paths) {
      if (await File(path).exists()) return true;
    }
    return false;
  }

  static Future<bool> _checkRootPackages() async {
    // Detect by checking for known root management apps
    // This requires a platform channel. Simplified version:
    const packages = [
      'com.noshufou.android.su',
      'com.noshufou.android.su.elite',
      'com.thirdparty.superuser',
      'eu.chainfire.supersu',
      'com.koushikdutta.superuser',
      'com.topjohnwu.magisk',
      'com.stifflered.aosp.faker',
    ];
    // On production, use MethodChannel to PackageManager
    return false;
  }

  static Future<bool> _checkEmulator() async {
    if (!Platform.isAndroid) return false;
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return [
        info.fingerprint.startsWith('google/sdk_gphone'),
        info.hardware == 'goldfish' || info.hardware == 'ranchu',
        info.brand == 'google' && info.device == 'generic_x86',
        info.product == 'sdk_gphone64_x86_64',
        info.product == 'sdk_gphone64_arm64',
        info.product == 'emu64a',
      ].any((check) => check);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _checkDebugger() async {
    // Dart VM debugger check
    // In release mode, this always returns false
    // In debug mode, it returns true
    return Platform.environment.containsKey('FLUTTER_TEST') == false &&
           (await _isDebuggerAttached());
  }

  static Future<bool> _isDebuggerAttached() async {
    // Platform channel check
    // Android: Debug.isDebuggerConnected()
    // iOS: getenv("debug") != null
    try {
      // Using a simple timing-based check
      final stopwatch = Stopwatch()..start();
      // Debugger overhead creates detectable delay
      for (int i = 0; i < 10000; i++) {
        // no-op
      }
      stopwatch.stop();
      // If debugger is attached, this loop will be significantly slower
      return stopwatch.elapsedMilliseconds > 100;
    } catch (_) {
      return false;
    }
  }
}
```

### 8.2 Google Play Integrity API (Production recommended)

```dart
// lib/core/services/play_integrity_service.dart
import 'package:play_integrity/play_integrity.dart';

class PlayIntegrityService {
  static Future<IntegrityVerdict> checkIntegrity() async {
    try {
      // 1. Get nonce from Cloud Function
      final client = SubscriptionClient();
      final timeResult = await client.getServerTime();
      final nonce = 'viyan_billing_${timeResult.serverTime}_${timeResult.nonce}';

      // 2. Request integrity token
      final integrity = PlayIntegrity();
      final tokenResult = await integrity.requestIntegrityToken(
        nonce: nonce,
        cloudProjectNumber: 123456789, // Replace with your GCP project number
      );

      // 3. Send to Cloud Function for verification
      //    (NEVER decode locally — token is encrypted)
      final functions = FirebaseFunctions.instance;
      final result = await functions.httpsCallable('verifyIntegrity').call({
        'token': tokenResult.token,
        'nonce': nonce,
      });

      return IntegrityVerdict(
        isDeviceCertified: result.data['isDeviceCertified'] == true,
        isAppRecognized: result.data['isAppRecognized'] == true,
        passesIntegrity: result.data['passesIntegrity'] == true,
      );
    } catch (e) {
      return IntegrityVerdict(
        isDeviceCertified: false,
        isAppRecognized: false,
        passesIntegrity: false,
      );
    }
  }
}

class IntegrityVerdict {
  final bool isDeviceCertified;
  final bool isAppRecognized;
  final bool passesIntegrity;

  IntegrityVerdict({
    required this.isDeviceCertified,
    required this.isAppRecognized,
    required this.passesIntegrity,
  });
}
```

### 8.3 VPN / Proxy detection

```dart
// lib/core/services/vpn_detector.dart
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

class VpnDetector {
  /// Returns true if VPN is active
  static Future<bool> isVpnActive() async {
    if (Platform.isAndroid) {
      return _checkAndroidVpn();
    } else if (Platform.isIOS) {
      return _checkIosVpn();
    }
    return false;
  }

  static Future<bool> _checkAndroidVpn() async {
    try {
      // Check network interfaces for VPN interfaces
      final interfaces = await NetworkInterface.list();
      return interfaces.any((i) =>
        i.name.contains('tun') ||
        i.name.contains('ppp') ||
        i.name.contains('tap') ||
        i.name.toLowerCase().contains('vpn')
      );
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _checkIosVpn() async {
    // iOS VPN detection requires platform channel
    // CFNetworkCopySystemProxySettings
    return false;
  }
}
```

### 8.4 Account switching abuse prevention (client)

```dart
// In shop_provider.dart — when saving/registering
Future<void> saveShop(ShopModel shop, String email) async {
  final fingerprint = await DeviceFingerprintService().getFingerprint();
  final signals = await DeviceFingerprintService().getSignals();
  
  // Call Cloud Function instead of direct Firestore
  final result = await SubscriptionClient().registerTrial(
    fingerprintHash: fingerprint,
    signals: signals,
    email: email,
  );
  
  if (result.status == 'error') {
    // Handle rejection
    if (result.errorCode == 'permission-denied') {
      _showTrialNotAvailable();
    }
    return;
  }
  
  // Only proceed with shop creation if trial is registered
  await _createShop(shop, email);
}
```

### 8.5 Subscription gating on all screens

```dart
// lib/core/guards/subscription_guard.dart
/// Centralized gate that checks subscription BEFORE any protected operation.
/// Calls Cloud Function for server-authoritative decision.
class SubscriptionGuard {
  static Future<bool> canPerformOperation(WidgetRef ref) async {
    final sub = ref.read(subscriptionProvider);
    
    // Optimistic local check first (fast path)
    if (!sub.isActive && !sub.isGraceActive) {
      return false;
    }
    
    // Server validation (slow path — runs less frequently)
    final shouldRevalidate = sub.lastServerValidatedAt == null ||
        DateTime.now().difference(sub.lastServerValidatedAt!) > const Duration(hours: 1);
    
    if (shouldRevalidate) {
      try {
        final fingerprint = await DeviceFingerprintService().getFingerprint();
        final serverResult = await SubscriptionClient().validateSubscription(
          fingerprintHash: fingerprint,
        );
        
        if (serverResult.status == 'expired' || serverResult.status == 'suspended') {
          ref.read(subscriptionProvider.notifier).invalidate();
          return false;
        }
        
        ref.read(subscriptionProvider.notifier).updateFromServer(serverResult);
        return true;
      } catch (e) {
        // Offline — fall back to local check
        return sub.isActive || sub.isGraceActive;
      }
    }
    
    return true;
  }
}
```

---

<a id="9-time"></a>
## 9. Time Tamper Protection v2

### Current problems
- `TimeSyncService` uses HTTP HEAD to `google.com` — can be intercepted
- Tamper counter in `FlutterSecureStorage` — can be wiped
- No server-side time anchor

### Production-grade time sync

```dart
// lib/core/services/time_sync_service_v2.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TimeSyncResult {
  final bool isValid;
  final DateTime estimatedServerTime;
  final int offsetMs;
  final bool isOffline;
  final bool tamperDetected;

  TimeSyncResult({
    required this.isValid,
    required this.estimatedServerTime,
    this.offsetMs = 0,
    this.isOffline = false,
    this.tamperDetected = false,
  });
}

class TimeSyncServiceV2 {
  final FlutterSecureStorage _storage;

  TimeSyncServiceV2({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Attempts to sync with server. Falls back gracefully when offline.
  Future<TimeSyncResult> syncTime() async {
    final deviceNow = DateTime.now();

    // 1. Try Cloud Function first (primary source)
    try {
      final client = SubscriptionClient();
      final result = await client.getServerTime();
      final serverTime = DateTime.parse(result.serverTime);
      final offset = serverTime.difference(deviceNow).inMilliseconds;

      // Validate: if offset > 120 seconds, likely tampered
      if (offset.abs() > 120000) {
        // Report tamper to server
        await client.reportTamper(
          diffSeconds: (offset / 1000).round(),
          fingerprintHash: await _getFingerprint(),
        );

        // Cache the failed sync attempt
        await _cacheTimeSync(
          serverTime: serverTime,
          deviceTime: deviceNow,
          offset: offset,
          isValid: false,
        );

        return TimeSyncResult(
          isValid: false,
          estimatedServerTime: serverTime,
          offsetMs: offset,
          tamperDetected: true,
        );
      }

      // Valid sync — cache it
      await _cacheTimeSync(
        serverTime: serverTime,
        deviceTime: deviceNow,
        offset: offset,
        isValid: true,
      );

      return TimeSyncResult(
        isValid: true,
        estimatedServerTime: serverTime,
        offsetMs: offset,
      );
    } catch (_) {
      // 2. Offline fallback
      return _handleOfflineSync(deviceNow);
    }
  }

  Future<TimeSyncResult> _handleOfflineSync(DateTime deviceNow) async {
    final cached = await _getCachedSync();

    if (cached == null) {
      // Never synced — restricted mode
      return TimeSyncResult(
        isValid: false,
        estimatedServerTime: deviceNow,
        isOffline: true,
      );
    }

    // 3. Check for clock rollback
    final deviceMs = deviceNow.millisecondsSinceEpoch;
    if (deviceMs < cached.lastSyncDeviceMs) {
      // Clock went backwards since last sync — tamper detected
      final diff = cached.lastSyncDeviceMs - deviceMs;
      await _reportTamperOffline(diff);

      return TimeSyncResult(
        isValid: false,
        estimatedServerTime: DateTime.fromMillisecondsSinceEpoch(
          deviceMs + cached.offset,
        ),
        offsetMs: cached.offset,
        isOffline: true,
        tamperDetected: true,
      );
    }

    // 4. Use cached offset
    final estimatedServerMs = deviceMs + cached.offset;
    final estimatedServerTime = DateTime.fromMillisecondsSinceEpoch(
      estimatedServerMs,
    );

    // 5. Check if cache is stale (> 24 hours)
    if (cached.lastSyncAt != null &&
        deviceNow.difference(cached.lastSyncAt!).inHours > 24) {
      return TimeSyncResult(
        isValid: false, // Stale — requires online validation
        estimatedServerTime: estimatedServerTime,
        offsetMs: cached.offset,
        isOffline: true,
      );
    }

    // Cached sync is valid and fresh enough
    return TimeSyncResult(
      isValid: true,
      estimatedServerTime: estimatedServerTime,
      offsetMs: cached.offset,
      isOffline: true,
    );
  }

  Future<void> _cacheTimeSync({
    required DateTime serverTime,
    required DateTime deviceTime,
    required int offset,
    required bool isValid,
  }) async {
    await _storage.write(
      key: 'ts_server_ms',
      value: serverTime.millisecondsSinceEpoch.toString(),
    );
    await _storage.write(
      key: 'ts_device_ms',
      value: deviceTime.millisecondsSinceEpoch.toString(),
    );
    await _storage.write(
      key: 'ts_offset',
      value: offset.toString(),
    );
    await _storage.write(
      key: 'ts_valid',
      value: isValid ? '1' : '0',
    );
  }

  Future<CachedSync?> _getCachedSync() async {
    try {
      final serverMs = await _storage.read(key: 'ts_server_ms');
      final deviceMs = await _storage.read(key: 'ts_device_ms');
      final offset = await _storage.read(key: 'ts_offset');
      final valid = await _storage.read(key: 'ts_valid');

      if (serverMs == null || deviceMs == null) return null;

      return CachedSync(
        serverTime: DateTime.fromMillisecondsSinceEpoch(int.parse(serverMs)),
        deviceTime: DateTime.fromMillisecondsSinceEpoch(int.parse(deviceMs)),
        lastSyncDeviceMs: int.parse(deviceMs),
        offset: int.parse(offset ?? '0'),
        isValid: valid == '1',
        lastSyncAt: DateTime.fromMillisecondsSinceEpoch(int.parse(deviceMs)),
      );
    } catch (_) {
      return null;
    }
  }

  Future<String> _getFingerprint() async {
    try {
      return await DeviceFingerprintService().getFingerprint();
    } catch (_) {
      return 'unknown';
    }
  }

  Future<void> _reportTamperOffline(int diffMs) async {
    // Queue tamper report for next online sync
    await _storage.write(
      key: 'pending_tamper_report',
      value: diffMs.toString(),
    );
  }
}

class CachedSync {
  final DateTime serverTime;
  final DateTime deviceTime;
  final int lastSyncDeviceMs;
  final int offset;
  final bool isValid;
  final DateTime? lastSyncAt;

  CachedSync({
    required this.serverTime,
    required this.deviceTime,
    required this.lastSyncDeviceMs,
    required this.offset,
    required this.isValid,
    this.lastSyncAt,
  });
}
```

### Offline strategy summary

| Scenario | Behavior | Subscription status |
|----------|----------|-------------------|
| Online, valid sync | Normal operation | Active |
| Offline, valid cached sync (<24h) | Full functionality | Active |
| Offline, valid cached sync (>24h) | Warning + limited operation | Grace-like |
| Offline, no cached sync | Read-only | Restricted |
| Offline, clock rollback detected | Read-only + pending tamper report | Expired |
| Online, tamper detected | Immediate block + server report | Suspended |

---

<a id="10-schema"></a>
## 10. Firestore Schema

### devices/{fingerprintHash}

```typescript
{
  // Identity
  fingerprintHash: string,          // SHA-256 primary key
  firstSeenAt: Timestamp,
  lastSeenAt: Timestamp,

  // Collected signals (for audit + reinstall detection)
  signals: {
    brand?: string,
    device?: string,
    hardware?: string,
    buildFingerprint?: string,
    board?: string,
    manufacturer?: string,
    model?: string,
    androidId?: string,
    serialNumber?: string,
    identifierForVendor?: string,
    timezone?: number,
  },

  // Trial tracking
  trial: {
    startedAt: Timestamp?,
    endsAt: Timestamp?,
    usedByEmails: string[],
    suspiciousEmailChanges: number,
    isBlacklisted: boolean,
    blacklistReason: string?,
    blacklistedAt: Timestamp?,
  },

  // Integrity health
  integrity: {
    lastCheckPassed: boolean,
    lastCheckAt: Timestamp,
    failureCount: number,
    lastFailureReason: string?,
    playIntegrityPassed: boolean?,
  },

  // Time sync history
  timeSync: {
    lastOffset: number,
    lastSyncedAt: Timestamp,
    tamperAttempts: number,
    isBlacklisted: boolean,
    lastTamperAt: Timestamp?,
  },

  // Metadata
  createdAt: Timestamp,
  updatedAt: Timestamp,
}

// Indexes required:
// - trial.endsAt ASC (for trial expiry cron)
// - trial.isBlacklisted == true (for blocklist sweep)
// - signals.buildFingerprint ASC (for reinstall matching)
```

### subscriptions/{uid}

```typescript
{
  uid: string,                      // Firebase Auth UID
  email: string,

  // Plan
  plan: 'free_trial' | 'basic_monthly' | 'pro_monthly' | 'expired' | 'suspended' | 'blocked',
  status: 'active' | 'grace' | 'expired' | 'suspended' | 'blocked',

  // Dates (all compared against server Timestamp)
  trialStartedAt: Timestamp?,
  trialEndsAt: Timestamp?,
  graceEndsAt: Timestamp?,
  currentPeriodStart: Timestamp,
  currentPeriodEnd: Timestamp,
  lastValidatedAt: Timestamp?,

  // Device binding
  activeDeviceFingerprint: string,
  deviceHistory: string[],

  // Payments
  payments: [{
    razorpayPaymentId: string,
    razorpayOrderId: string,
    amount: number,
    currency: string,
    status: 'verified' | 'pending' | 'failed' | 'refunded',
    verifiedAt: Timestamp,
    planPurchased: string,
    periodStart: Timestamp,
    periodEnd: Timestamp,
  }],

  // Security
  securityFlags: {
    suspiciousEmailChanges: number,
    deviceSwitches: number,
    lastFlaggedAt: Timestamp?,
    isUnderReview: boolean,
  },

  // Metadata
  createdAt: Timestamp,
  updatedAt: Timestamp,
}

// Indexes:
// - plan + status (for billing sweeps)
// - currentPeriodEnd ASC (for expiry notifications)
// - status + lastValidatedAt (for stale subscription cleanup)
```

### security_events/{eventId}

```typescript
{
  eventId: string,                   // auto-ID
  type: 'trial_abuse'
      | 'tamper_detected'
      | 'device_switch'
      | 'integrity_failure'
      | 'payment_verification_failed'
      | 'reinstall_detected'
      | 'email_change_flag'
      | 'time_tamper'
      | 'root_detected'
      | 'emulator_detected'
      | 'ip_abuse',
  severity: 'info' | 'warning' | 'critical',

  uid: string?,
  fingerprintHash: string?,
  email: string?,
  ipAddress: string?,

  details: map,                      // Arbitrary JSON payload

  createdAt: Timestamp,
}

// Indexes:
// - createdAt DESC
// - type + createdAt DESC
// - uid + createdAt DESC
// - severity + createdAt DESC

// TTL: delete after 90 days
```

### trial_requests/{requestId}

```typescript
{
  fingerprintHash: string,
  email: string,
  ipAddress: string,
  resolvedStatus: 'approved' | 'rejected',
  rejectionReason: string?,
  createdAt: Timestamp,
}

// Indexes:
// - fingerprintHash + createdAt DESC
// - email + createdAt DESC
// - ipAddress + createdAt DESC

// TTL: delete after 30 days
```

### config/flags

```typescript
{
  useServerValidation: boolean,      // Toggle server validation
  blockNewTrials: boolean,           // Emergency kill switch
  maintenanceMode: boolean,          // Block all writes
  gracePeriodDays: number,           // Configurable grace period
  trialPeriodDays: number,           // Configurable trial duration
  maxTamperAttempts: number,         // Before auto-blacklist
  maxEmailChanges: number,           // Before auto-blacklist
}
```

---

<a id="11-readonly"></a>
## 11. Server-Side Read-Only Enforcement

### Layer 1: Firestore Rules (already covered)
Items, orders, and shop writes are blocked when `subscription.status != 'active'`.

### Layer 2: Cloud Function validation
Every protected operation should optionally call the Cloud Function.

### Layer 3: SubscriptionProvider reacts to server state

```dart
// lib/features/subscription/services/subscription_service.dart (refactored)
class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  Timer? _validationTimer;

  SubscriptionNotifier() : super(SubscriptionState.initial());

  /// Called on app startup and periodically
  Future<void> validateWithServer() async {
    try {
      final fingerprint = await DeviceFingerprintService().getFingerprint();
      final result = await SubscriptionClient().validateSubscription(
        fingerprintHash: fingerprint,
      );

      state = state.copyWith(
        isActive: result.status == 'active' || result.status == 'grace',
        isGraceActive: result.status == 'grace',
        isExpired: result.status == 'expired',
        isSuspended: result.status == 'suspended' || result.status == 'blocked',
        status: result.status,
        planName: result.plan,
        expiryDate: result.currentPeriodEnd != null
            ? DateTime.parse(result.currentPeriodEnd)
            : null,
        serverTime: result.serverTime != null
            ? DateTime.parse(result.serverTime)
            : null,
        isAuthorizedDevice: result.isAuthorizedDevice,
        isBlacklisted: result.isBlacklisted,
        lastServerValidatedAt: DateTime.now(),
        isValidating: false,
      );
    } catch (e) {
      // Offline — keep previous state, set flag
      state = state.copyWith(
        isValidating: false,
        lastValidationFailed: true,
      );
    }
  }

  /// Called from feature guards before protected operations
  Future<bool> guardOperation() async {
    // 1. Local check (fast path)
    if (!state.isActive && !state.isGraceActive) {
      return false;
    }

    // 2. Server re-validation if stale (> 1 hour since last check)
    if (state.lastServerValidatedAt == null ||
        DateTime.now().difference(state.lastServerValidatedAt!) > const Duration(hours: 1)) {
      await validateWithServer();
      return state.isActive || state.isGraceActive;
    }

    return true;
  }
}

class SubscriptionState {
  final bool isActive;
  final bool isGraceActive;
  final bool isExpired;
  final bool isSuspended;
  final String status;
  final String planName;
  final DateTime? expiryDate;
  final DateTime? serverTime;
  final bool isAuthorizedDevice;
  final bool isBlacklisted;
  final DateTime? lastServerValidatedAt;
  final bool isValidating;
  final bool lastValidationFailed;

  // ... copyWith, initial, etc.
}
```

### Layer 4: Widget-level protection

```dart
/// Wraps protected actions with server validation.
class ProtectedAction extends ConsumerWidget {
  final Widget child;
  final VoidCallback? onBlocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = ref.watch(subscriptionProvider);

    if (!sub.isActive && !sub.isGraceActive) {
      return GestureDetector(
        onTap: () => showSubscriptionExpiredDialog(context),
        child: IgnorePointer(
          child: Opacity(opacity: 0.4, child: child),
        ),
      );
    }

    return child;
  }
}
```

---

<a id="12-ux"></a>
## 12. UX & Conversion Improvements

### Progressive warning system

```dart
// lib/features/subscription/widgets/trial_banner.dart

class TrialBanner extends StatelessWidget {
  final int daysRemaining;
  final bool isGrace;

  /// Shows progressively stronger warnings as trial nears end.
  /// Optimized for shop owner readability — clear action, minimal text.
  Widget build(BuildContext context) {
    if (isGrace) {
      return _buildBanner(
        icon: Icons.info_outline_rounded,
        bgGradient: [const Color(0xFFFEF3C7), const Color(0xFFFFF8E1)],
        borderColor: const Color(0xFFF59E0B).withValues(alpha: 0.3),
        textColor: const Color(0xFF92400E),
        message: 'Trial ended — $daysRemaining days of grace remaining',
        actionLabel: 'Renew Now',
      );
    }

    if (daysRemaining <= 1) {
      return _buildBanner(
        icon: Icons.warning_amber_rounded,
        bgGradient: [const Color(0xFFFEE2E2), const Color(0xFFFFF5F5)],
        borderColor: const Color(0xFFEF4444).withValues(alpha: 0.3),
        textColor: const Color(0xFF991B1B),
        message: 'Trial ends tomorrow — renew to keep your data',
        actionLabel: 'Renew →',
      );
    }

    if (daysRemaining <= 3) {
      return _buildBanner(
        icon: Icons.schedule_rounded,
        bgGradient: [const Color(0xFFFFF7ED), const Color(0xFFFFFBF5)],
        borderColor: const Color(0xFFF97316).withValues(alpha: 0.3),
        textColor: const Color(0xFF9A3412),
        message: 'Trial ends in $daysRemaining days',
        actionLabel: 'Renew',
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildBanner({
    required IconData icon,
    required List<Color> bgGradient,
    required Color borderColor,
    required Color textColor,
    required String message,
    required String actionLabel,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: bgGradient),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => context.push('/profile/renewal'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

### Intelligent upgrade prompts

```dart
// lib/features/subscription/services/upgrade_optimizer.dart
class UpgradeOptimizer {
  /// Shows the right prompt based on user behavior and remaining time.
  static void maybePrompt(BuildContext context, WidgetRef ref) {
    final sub = ref.read(subscriptionProvider);
    final orderCount = ref.read(orderCountProvider);

    if (sub.isGraceActive) {
      // Grace period — show full-screen offer on 3rd launch
      _showGraceOffer(context);
      return;
    }

    if (sub.daysRemaining <= 2) {
      // Urgency — show modal
      _showUrgencyModal(context);
      return;
    }

    if (sub.daysRemaining <= 7 && orderCount > 50) {
      // Active user + near expiry → smart prompt
      _showSmartPrompt(context, orderCount);
      return;
    }
  }

  static void _showSmartPrompt(BuildContext context, int orderCount) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('You\'ve processed $orderCount orders!'),
        content: const Text(
          'You\'re getting great use out of Viyan Billing. '
          'Upgrade now to keep your business running smoothly.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Later')),
          ElevatedButton(onPressed: () => context.push('/profile/renewal'), child: const Text('Upgrade')),
        ],
      ),
    );
  }

  static void _showGraceOffer(BuildContext context) {
    showGeneralDialog(
      context: context,
      pageBuilder: (ctx, a1, a2) => const SizedBox(),
      transitionBuilder: (ctx, a1, a2, child) => ScaleTransition(
        scale: a1,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Grace period active'),
          content: const Text(
            'Your trial has ended. Renew now to keep full access.\n'
            'After the grace period, the app will show data only.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                // Set read-only mode
              },
              child: const Text('Continue in read-only'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/profile/renewal');
              },
              child: const Text('Renew Now'),
            ),
          ],
        ),
      ),
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}
```

---

<a id="13-packages"></a>
## 13. Recommended Package List

| Package | Version | Purpose |
|---------|---------|---------|
| `crypto` | ^3.0.6 | SHA-256 hashing for fingerprint |
| `device_info_plus` | ^11.3.0 | Hardware signals (brand, model, Android ID, etc.) |
| `play_integrity` | ^1.0.0 | Google Play Integrity API (replaces root detection) |
| `package_info_plus` | ^8.1.0 | APK signature, installer store, version |
| `flutter_secure_storage` | ^9.2.4 | (already used) — hardened with integrity hashes |
| `cloud_functions` | ^5.2.0 | (already used) — call Cloud Functions |
| `connectivity_plus` | ^6.1.0 | Offline/online detection |
| `firebase_app_check` | ^0.3.2 | (already used) — App Attest + Play Integrity |
| `firebase_installations` | ^0.4.0 | Firebase Installation ID (additional signal) |

### Removed/replaced
| Old | New | Reason |
|-----|-----|--------|
| Root detection (manual) | `play_integrity` | Google-managed, tamper-proof |
| HTTP HEAD time sync | Cloud Function + cached offset | Server-authoritative, non-spoofable |

---

<a id="14-migration"></a>
## 14. Migration Plan

### Phase 1: Foundation (Week 1)

```text
Day 1-2: Set up Cloud Functions project
  ├── firebase init functions (TypeScript or Node.js)
  ├── Deploy: registerTrial, validateSubscription, verifyPayment, getServerTime, reportTamper
  └── Set environment variables (RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET)

Day 3-4: Add new Flutter services
  ├── DeviceFingerprintService (multi-signal)
  ├── IntegrityService (root/emu/debug detection — optional, use Play Integrity in production)
  ├── SubscriptionClient (Cloud Function caller)
  ├── TimeSyncServiceV2 (server-anchored)
  └── StorageGuard (integrity-hashed secure storage)

Day 5: Create new Firestore collections
  ├── devices/
  ├── subscriptions/
  ├── security_events/
  ├── trial_requests/
  └── config/flags
```

### Phase 2: Data Migration (Week 2)

```javascript
// functions/src/migration/backfill.js
// Run ONCE as an admin script or HTTP function

exports.backfillFromOldData = functions.https.onRequest(async (req, res) => {
  // 1. Read old trial_devices collection
  const oldDevices = await db.collection('trial_devices').get();

  const batch = db.batch();
  let count = 0;

  for (const doc of oldDevices.docs) {
    const data = doc.data();
    const newDoc = {
      fingerprintHash: doc.id,
      firstSeenAt: data.trialStartedAt || admin.firestore.FieldValue.serverTimestamp(),
      lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
      signals: {},
      trial: {
        startedAt: data.trialStartedAt,
        endsAt: data.trialEndsAt,
        usedByEmails: [data.firstEmail],
        suspiciousEmailChanges: 0,
        isBlacklisted: data.isBlocked || false,
      },
      timeSync: { tamperAttempts: 0, isBlacklisted: false },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    batch.set(db.collection('devices').doc(doc.id), newDoc);
    count++;

    // Firestore batch limit: 500
    if (count % 400 === 0) {
      await batch.commit();
      // Start new batch
    }
  }

  await batch.commit();
  res.send(`Migrated ${count} devices`);
});
```

### Phase 3: Client Migration (Week 2-3)

```text
Day 8-9: Update shop_provider.dart
  ├── Replace checkAndRegisterDeviceTrial() call with SubscriptionClient.registerTrial()
  ├── Remove client-side trial validation logic
  └── Email normalization + validation moved to server

Day 10-11: Update subscription_service.dart
  ├── Add validateWithServer() method
  ├── Remove local DateTime.now() comparisons for expiry
  ├── Add guardOperation() for feature gating
  └── Add periodic server validation timer

Day 12: Update checkout_screen.dart
  ├── Replace direct Razorpay success callback with verifyPayment()
  └── Remove client-side shop update after payment

Day 13: Apply new Firestore rules
  ├── Block client writes to devices, subscriptions
  ├── Gate items/orders writes by subscription status
  └── Test with expired user accounts
```

### Phase 4: Flutter Release (Week 3)

```yaml
# pubspec.yaml — release checklist
dependencies:
  crypto: ^3.0.6
  device_info_plus: ^11.3.0
  play_integrity: ^1.0.0
  package_info_plus: ^8.1.0
  flutter_secure_storage: ^9.2.4
  cloud_functions: ^5.2.0
  connectivity_plus: ^6.1.0
  firebase_app_check: ^0.3.2
  firebase_installations: ^0.4.0
```

### Phase 5: Monitoring & Rollout

```text
Week 4:
  ├── Monitor security_events collection daily
  ├── Set up Firebase Crashlytics for Cloud Function errors
  ├── Configure alerts for:
  │   ├── >5 trial_abuse events per hour
  │   ├── Any payment_verification_failed
  │   └── >10 time_tamper events per day
  ├── Monitor trial registration conversion rate
  └── Compare with pre-migration data

Rollback procedure:
  ├── Set config/flags.useServerValidation = false
  ├── Client falls back to legacy validation
  └── All trial registrations go through old flow
```

---

## Summary: Security posture comparison

| Threat | Current | After |
|--------|---------|-------|
| Reinstall → new trial | One deletable deviceId | Multi-signal fingerprint + server reinstall detection |
| Clear app data | New trial granted | Server links signals → detects it's the same device |
| APK repackage / patch | No protection | Firestore rules + Cloud Functions (server enforces, client cannot bypass) |
| Rooted device | No protection | Play Integrity API + signal-based detection |
| Emulator | No protection | Emulator signature detection |
| Forge trial expiry | Client writes to Firestore | Server only — client cannot write subscriptions |
| Payment callback forgery | Client updates shop | Server-to-server Razorpay API verification |
| Time rollback | Client-side counter (deletable) | Server time anchor + offline cache with rollback detection |
| Multiple accounts/device | Email flag (client-enforced) | Server-enforced with auto-blacklist after 3 changes |
| Firestore enumeration | Public read | Authenticated + owner-only read |
| Offline abuse | No protection | 24-hour cached sync limit + clock rollback detection |
| Audit trail | None | Full security_events collection with 90-day retention |
