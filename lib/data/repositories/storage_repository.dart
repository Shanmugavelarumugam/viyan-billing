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

      // Create a reference to "items/{userId}/{itemId}.jpg"
      final ref = _storage.ref().child('items').child(user.uid).child('$itemId.jpg');

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
      return null;
    }
  }

  Future<void> deleteItemImage(String itemId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final ref = _storage.ref().child('items').child(user.uid).child('$itemId.jpg');
      await ref.delete();
    } catch (e) {
      debugPrint('⚠️ Error deleting image (might not exist): $e');
    }
  }

  Future<String?> uploadShopLogo(File imageFile) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

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
      final Uint8List? compressedBytes = await FlutterImageCompress.compressWithFile(
        imageFile.absolute.path,
        minWidth: 800,
        minHeight: 800,
        quality: 80,
        format: compressFormat,
      );

      final uploadBytes = compressedBytes ?? await imageFile.readAsBytes();
      debugPrint('⚡ Final image size for upload: ${(uploadBytes.lengthInBytes / 1024).toStringAsFixed(2)} KB');

      // 4. Delete existing logo files with other extensions to prevent orphaned files
      for (final otherExt in validExtensions) {
        if (otherExt != ext) {
          try {
            final oldRef = _storage.ref().child('shop_logos').child('${user.uid}$otherExt');
            await oldRef.delete();
            debugPrint('🗑️ Cleaned up orphaned logo: ${oldRef.fullPath}');
          } catch (_) {
            // Safe to ignore file not found errors
          }
        }
      }

      // 5. Create reference and upload
      final ref = _storage.ref().child('shop_logos').child('${user.uid}$ext');
      debugPrint('📤 Uploading shop logo to: ${ref.fullPath}');

      final uploadTask = await ref.putData(
        uploadBytes,
        SettableMetadata(contentType: contentType),
      );

      // 6. Get download URL and append cache-busting version parameter
      final url = await uploadTask.ref.getDownloadURL();
      final cacheBustedUrl = '$url&v=${DateTime.now().millisecondsSinceEpoch}';
      debugPrint('✅ Shop logo uploaded successfully: $cacheBustedUrl');
      return cacheBustedUrl;
    } catch (e) {
      debugPrint('❌ Error uploading shop logo: $e');
      if (e is FirebaseException) {
        debugPrint('   Code: ${e.code}');
        debugPrint('   Message: ${e.message}');
      }
      return null;
    }
  }

  Future<void> deleteShopLogo() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final validExtensions = ['.jpg', '.jpeg', '.png', '.webp'];
      for (final ext in validExtensions) {
        try {
          final ref = _storage.ref().child('shop_logos').child('${user.uid}$ext');
          await ref.delete();
          debugPrint('🗑️ Deleted shop logo: ${ref.fullPath}');
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('⚠️ Error deleting shop logo: $e');
    }
  }
}
