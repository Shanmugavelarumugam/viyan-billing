import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../shop_setup/providers/shop_provider.dart';
import '../../../data/models/shop_model.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _ownerController;
  late TextEditingController _addressController;
  late TextEditingController _upiController;
  late TextEditingController _phoneController;
  late TextEditingController _gstController;
  String? _selectedType;
  String? _profilePhotoPath;
  bool _isSaving = false;

  final _shopTypes = [
    'Tea Shop',
    'Food Truck',
    'Tiffin Stall',
    'Bakery',
    'Juice Shop',
    'Restaurant'
  ];

  @override
  void initState() {
    super.initState();
    final shop = ref.read(shopProvider).shop;
    _nameController = TextEditingController(text: shop?.name ?? '');
    _ownerController = TextEditingController(text: shop?.ownerName ?? '');
    _addressController = TextEditingController(text: shop?.address ?? '');
    _upiController = TextEditingController(text: shop?.upiId ?? '');
    _phoneController = TextEditingController(text: shop?.phone ?? '');
    _gstController = TextEditingController(text: shop?.gstNumber ?? '');
    _selectedType = shop?.shopType ?? 'Tea Shop';
    final path = shop?.logoPath ?? shop?.profilePhotoPath;
    if (path != null && (path.startsWith('http') || File(path).existsSync())) {
      _profilePhotoPath = path;
    } else {
      _profilePhotoPath = null;
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        _profilePhotoPath = image.path;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ownerController.dispose();
    _addressController.dispose();
    _upiController.dispose();
    _phoneController.dispose();
    _gstController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final shop = ref.watch(shopProvider).shop;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
        leading: Center(
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 18),
            onPressed: () => context.pop(),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            // Profile Photo Header
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.15),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                      image: (_profilePhotoPath != null && (_profilePhotoPath!.startsWith('http') || File(_profilePhotoPath!).existsSync()))
                          ? DecorationImage(
                              image: _profilePhotoPath!.startsWith('http')
                                  ? NetworkImage(_profilePhotoPath!) as ImageProvider
                                  : FileImage(File(_profilePhotoPath!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: (_profilePhotoPath == null || (!_profilePhotoPath!.startsWith('http') && !File(_profilePhotoPath!).existsSync()))
                        ? Icon(Icons.store_rounded, size: 60, color: Colors.grey[200])
                        : null,
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            _buildEditField(
              controller: _nameController,
              label: 'Shop Name',
              icon: Icons.store_rounded,
              color: primaryColor,
            ),
            const SizedBox(height: 24),
            _buildEditField(
              controller: _ownerController,
              label: 'Owner Name',
              icon: Icons.person_rounded,
              color: primaryColor,
            ),
            const SizedBox(height: 24),
            _buildEditField(
              controller: _addressController,
              label: 'Address',
              icon: Icons.location_on_rounded,
              color: primaryColor,
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            _buildEditField(
              controller: _upiController,
              label: 'UPI ID for QR',
              icon: Icons.qr_code_rounded,
              color: primaryColor,
              hint: 'e.g., example@upi',
            ),
            const SizedBox(height: 24),
            _buildEditField(
              controller: _phoneController,
              label: 'Phone Number',
              icon: Icons.phone_rounded,
              color: primaryColor,
              hint: 'e.g., +91 9876543210',
            ),
            const SizedBox(height: 24),
            _buildEditField(
              controller: _gstController,
              label: 'GST Number',
              icon: Icons.receipt_rounded,
              color: primaryColor,
              hint: 'e.g., 22AAAAA0000A1Z5',
            ),
            const SizedBox(height: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Business Type',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _shopTypes.map((type) {
                    final isSelected = _selectedType == type;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedType = type),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? primaryColor : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? primaryColor : const Color(0xFFE2E8F0),
                            width: 1.5,
                          ),
                          boxShadow: isSelected ? [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ] : [],
                        ),
                        child: Text(
                          type,
                          style: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF475569),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 48),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isSaving ? null : () async {
                  if (shop == null) return;
                  
                  if (_nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Shop name cannot be empty'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  setState(() => _isSaving = true);
                  try {
                    String? finalPhotoPath = _profilePhotoPath;
                    String? finalLogoPath = shop.logoPath;
                    
                    // If a new local image was picked, process and copy/save locally
                    if (_profilePhotoPath != null && !_profilePhotoPath!.startsWith('http')) {
                      final file = File(_profilePhotoPath!);
                      if (!await file.exists()) {
                        throw Exception('Selected profile picture file does not exist locally.');
                      }

                      // Determine extension
                      final extension = p.extension(file.path).toLowerCase();
                      final validExtensions = ['.jpg', '.jpeg', '.png', '.webp'];
                      final ext = validExtensions.contains(extension) ? extension : '.jpg';

                      // Select compression format
                      CompressFormat compressFormat = CompressFormat.jpeg;
                      if (ext == '.png') {
                        compressFormat = CompressFormat.png;
                      } else if (ext == '.webp') {
                        compressFormat = CompressFormat.webp;
                      }

                      // Compress the image file to optimize storage
                      debugPrint('⚡ Compressing image locally: ${file.path}');
                      Uint8List? compressedBytes;
                      try {
                        compressedBytes = await FlutterImageCompress.compressWithFile(
                          file.absolute.path,
                          minWidth: 800,
                          minHeight: 800,
                          quality: 80,
                          format: compressFormat,
                        );
                      } catch (e) {
                        debugPrint('⚠️ Image compression failed, using original file: $e');
                      }

                      final uploadBytes = compressedBytes ?? await file.readAsBytes();

                      // Write to App Documents Directory (Permanent Local Storage)
                      final appDir = await getApplicationDocumentsDirectory();
                      final newLogoFile = File('${appDir.path}/shop_logo_${DateTime.now().millisecondsSinceEpoch}$ext');
                      await newLogoFile.writeAsBytes(uploadBytes);
                      
                      // Delete old logo to free space
                      if (shop.logoPath != null) {
                        try {
                          final oldFile = File(shop.logoPath!);
                          if (await oldFile.exists()) {
                            await oldFile.delete();
                            debugPrint('🗑️ Cleaned up old local logo: ${oldFile.path}');
                          }
                        } catch (e) {
                          debugPrint('⚠️ Failed to delete old logo file: $e');
                        }
                      }

                      finalPhotoPath = newLogoFile.path;
                      finalLogoPath = newLogoFile.path;
                      debugPrint('💾 Logo saved locally at: $finalLogoPath');
                    }

                    final updatedShop = shop.copyWith(
                      name: _nameController.text.trim(),
                      ownerName: _ownerController.text.trim(),
                      address: _addressController.text.trim(),
                      upiId: _upiController.text.trim(),
                      phone: _phoneController.text.trim(),
                      gstNumber: _gstController.text.trim(),
                      shopType: _selectedType,
                      profilePhotoPath: finalPhotoPath,
                      logoPath: finalLogoPath,
                    );

                    await ref.read(shopProvider.notifier).saveShop(updatedShop);
                    
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 12),
                              Text('Profile updated successfully!', style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          backgroundColor: Colors.green[600],
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.all(20),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      context.pop();
                    }
                  } catch (e) {
                    debugPrint('❌ Error saving profile: $e');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error updating profile: ${e.toString().replaceAll('Exception: ', '')}'),
                          backgroundColor: Colors.red[600],
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.all(20),
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _isSaving = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: primaryColor.withValues(alpha: 0.6),
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : const Text(
                        'SAVE CHANGES',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEditField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
    int maxLines = 1,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.normal),
            prefixIcon: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              child: Icon(icon, color: color, size: 20),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 40),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: color, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
