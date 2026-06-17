import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;

final storageRepositoryProvider = Provider((ref) => StorageRepository());

class StorageRepository {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> uploadItemImage(Uint8List imageBytes, String itemId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final bucket = _storage.app.options.storageBucket;
      debugPrint('ℹ️ Firebase Storage Bucket: $bucket');

      // Create a reference to "items/{userId}/{itemId}.jpg"
      final ref = _storage.ref().child('items').child(user.uid).child('$itemId.jpg');
      debugPrint('📤 Uploading item image to: ${ref.fullPath}');

      // Upload the bytes
      final uploadTask = await ref.putData(
        imageBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      
      // Get the download URL
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('❌ Error uploading image: $e');
      if (e is FirebaseException) {
        debugPrint('   Firebase Storage Error Code: ${e.code}');
        debugPrint('   Firebase Storage Error Message: ${e.message}');
      }
      return null;
    }
  }

  Future<void> deleteItemImage(String itemId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final ref = _storage.ref().child('items').child(user.uid).child('$itemId.jpg');
      
      try {
        // Check if the object exists first
        await ref.getMetadata();
        await ref.delete();
        debugPrint('🗑️ Deleted item image: ${ref.fullPath}');
      } on FirebaseException catch (e) {
        if (e.code == 'object-not-found') {
          debugPrint('ℹ️ No item image found at ${ref.fullPath} (Skip delete)');
        } else {
          debugPrint('⚠️ Firebase error checking/deleting ${ref.fullPath}: ${e.code} - ${e.message}');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error deleting image: $e');
    }
  }

  Future<String?> uploadShopLogo(File imageFile) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final bucket = _storage.app.options.storageBucket;
      debugPrint('ℹ️ Firebase Storage Bucket: $bucket');
      if (bucket == null || bucket.isEmpty) {
        debugPrint('⚠️ Warning: Firebase Storage bucket is empty or null in Firebase options.');
      }

      // 1. Detect dynamic file extension
      final extension = p.extension(imageFile.path).toLowerCase();
      final validExtensions = ['.jpg', '.jpeg', '.png', '.webp'];
      final ext = validExtensions.contains(extension) ? extension : '.jpg';
      
      debugPrint('ℹ️ Detected file extension: $ext');

      // 2. Select compression format
      CompressFormat compressFormat = CompressFormat.jpeg;
      String contentType = 'image/jpeg';
      if (ext == '.png') {
        compressFormat = CompressFormat.png;
        contentType = 'image/png';
      } else if (ext == '.webp') {
        compressFormat = CompressFormat.webp;
        contentType = 'image/webp';
      }

      // 3. Compress the image file to target ~200KB–500KB
      debugPrint('⚡ Compressing image at: ${imageFile.path}');
      Uint8List? compressedBytes;
      try {
        compressedBytes = await FlutterImageCompress.compressWithFile(
          imageFile.absolute.path,
          minWidth: 800,
          minHeight: 800,
          quality: 80,
          format: compressFormat,
        );
      } catch (e) {
        debugPrint('⚠️ Image compression failed, using original file bytes: $e');
      }

      final uploadBytes = compressedBytes ?? await imageFile.readAsBytes();
      debugPrint('⚡ Final image size for upload: ${(uploadBytes.lengthInBytes / 1024).toStringAsFixed(2)} KB');

      // 4. Create reference and upload
      final ref = _storage.ref().child('shop_logos').child('${user.uid}$ext');
      debugPrint('📤 Uploading shop logo to: ${ref.fullPath}');

      final uploadTask = await ref.putData(
        uploadBytes,
        SettableMetadata(contentType: contentType),
      );

      // 5. Get download URL and append cache-busting version parameter
      final url = await uploadTask.ref.getDownloadURL();
      final cacheBustedUrl = '$url&v=${DateTime.now().millisecondsSinceEpoch}';
      debugPrint('✅ Shop logo uploaded successfully: $cacheBustedUrl');

      // 6. Delete existing logo files with other extensions safely in the background
      _cleanupOrphanedLogos(user.uid, ext, validExtensions);

      return cacheBustedUrl;
    } catch (e) {
      debugPrint('❌ Error uploading shop logo: $e');
      if (e is FirebaseException) {
        debugPrint('   Firebase Storage Error Code: ${e.code}');
        debugPrint('   Firebase Storage Error Message: ${e.message}');
      }
      return null;
    }
  }

  // Safe background cleanup helper that checks metadata first
  void _cleanupOrphanedLogos(String userId, String currentExt, List<String> validExtensions) {
    Future.microtask(() async {
      for (final otherExt in validExtensions) {
        if (otherExt != currentExt) {
          try {
            final oldRef = _storage.ref().child('shop_logos').child('$userId$otherExt');
            try {
              await oldRef.getMetadata();
              await oldRef.delete();
              debugPrint('🗑️ Cleaned up orphaned logo: ${oldRef.fullPath}');
            } on FirebaseException catch (fe) {
              if (fe.code == 'object-not-found') {
                // Ignore quietly as it is expected
                debugPrint('ℹ️ No orphaned logo found at ${oldRef.fullPath} (Skip delete)');
              } else {
                debugPrint('⚠️ Firebase error checking/deleting ${oldRef.fullPath}: ${fe.code} - ${fe.message}');
              }
            }
          } catch (e) {
            debugPrint('⚠️ Unexpected error cleaning up orphaned logo: $e');
          }
        }
      }
    });
  }

  Future<void> deleteShopLogo() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final validExtensions = ['.jpg', '.jpeg', '.png', '.webp'];
      for (final ext in validExtensions) {
        try {
          final ref = _storage.ref().child('shop_logos').child('${user.uid}$ext');
          try {
            await ref.getMetadata();
            await ref.delete();
            debugPrint('🗑️ Deleted shop logo: ${ref.fullPath}');
          } on FirebaseException catch (fe) {
            if (fe.code != 'object-not-found') {
              debugPrint('⚠️ Error deleting ${ref.fullPath}: ${fe.code} - ${fe.message}');
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('⚠️ Error deleting shop logo: $e');
    }
  }
}
