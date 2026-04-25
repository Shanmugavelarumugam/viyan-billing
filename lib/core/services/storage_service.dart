import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class StorageService {
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

      // Read file as bytes to use putData (more reliable for small files)
      final bytes = await imageFile.readAsBytes();
      
      // Create a reference to "shop_logos/{userId}.jpg"
      final ref = _storage.ref().child('shop_logos').child('${user.uid}.jpg');
      
      debugPrint('📤 Uploading to bucket: ${_storage.app.options.storageBucket}');
      debugPrint('📤 Uploading shop logo to: ${ref.fullPath}');

      // Upload the bytes
      final uploadTask = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      
      // Get the download URL
      final url = await uploadTask.ref.getDownloadURL();
      debugPrint('✅ Shop logo uploaded: $url');
      return url;
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

      final ref = _storage.ref().child('shop_logos').child('${user.uid}.jpg');
      await ref.delete();
    } catch (e) {
      debugPrint('⚠️ Error deleting shop logo: $e');
    }
  }
}
