import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../data/models/item_model.dart';
import '../../../core/localization/localization_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../../data/repositories/storage_repository.dart';
import '../../billing/providers/billing_provider.dart';
import '../../subscription/services/subscription_service.dart';
import '../../subscription/widgets/upgrade_pro_dialog.dart';

class ItemsScreen extends ConsumerStatefulWidget {
  const ItemsScreen({super.key});

  @override
  ConsumerState<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends ConsumerState<ItemsScreen>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(itemsProvider);
    final l10n = ref.watch(localizationProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    if (l10n == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Filter items based on search and category
    final filteredItems = items.where((item) {
      final matchesSearch = item.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'All' || item.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    // Get unique categories
    final categories = ['All', ...items.map((i) => i.category ?? 'Uncategorized').toSet()];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              primaryColor.withValues(alpha: 0.03),
              Colors.white,
              Colors.white,
            ],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SafeArea(
            child: Stack(
              children: [
                // Decorative circles in background
                ..._buildBackgroundCircles(primaryColor),
                
                // Main content
                CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  cacheExtent: 300.0,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          _buildHeader(l10n, primaryColor),
                          _buildCategoryFilter(categories, l10n, primaryColor),
                        ],
                      ),
                    ),
                    if (filteredItems.isEmpty)
                      SliverToBoxAdapter(
                        child: _buildEmptyState(l10n, primaryColor),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(20, 16, 20, 100 + MediaQuery.paddingOf(context).bottom),
                        sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isTablet ? 3 : 2,
                          childAspectRatio: 0.60,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return RepaintBoundary(
                              child: _MenuItemCard(
                                item: filteredItems[index],
                                onToggle: () {
                                  final subscription = ref.read(subscriptionProvider);
                                  if (!subscription.isActive) {
                                    showSubscriptionExpiredDialog(context);
                                    return;
                                  }
                                  ref
                                      .read(itemsProvider.notifier)
                                      .toggleAvailability(filteredItems[index].id);
                                },
                                onEdit: () {
                                  final subscription = ref.read(subscriptionProvider);
                                  if (!subscription.isActive) {
                                    showSubscriptionExpiredDialog(context);
                                    return;
                                  }
                                  _showAddEditDialog(
                                    context,
                                    ref,
                                    filteredItems[index],
                                  );
                                },
                                onDuplicate: () {
                                  final subscription = ref.read(subscriptionProvider);
                                  if (!subscription.isActive) {
                                    showSubscriptionExpiredDialog(context);
                                    return;
                                  }
                                  ref
                                      .read(itemsProvider.notifier)
                                      .duplicateItem(filteredItems[index]);
                                },
                                onDelete: () {
                                  final subscription = ref.read(subscriptionProvider);
                                  if (!subscription.isActive) {
                                    showSubscriptionExpiredDialog(context);
                                    return;
                                  }
                                  _showDeleteConfirm(
                                    context,
                                    ref,
                                    filteredItems[index],
                                    l10n,
                                  );
                                },
                                primaryColor: primaryColor,
                              ),
                            );
                          },
                          childCount: filteredItems.length,
                        ),
                      ),
                    ),
                ],
              ),
              
              // Floating Action Button
              Positioned(
                bottom: 110,
                right: 24,
                child: _buildFAB(l10n, primaryColor),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  List<Widget> _buildBackgroundCircles(Color primaryColor) {
    return [
      Positioned(
        top: -80,
        right: -50,
        child: Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                primaryColor.withValues(alpha: 0.15),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
      Positioned(
        bottom: -60,
        left: -60,
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                primaryColor.withValues(alpha: 0.1),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildHeader(AppLocalizations l10n, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.restaurant_menu_rounded, color: primaryColor, size: 28),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.translate('menu_items'),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Manage your food items',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey[100]!),
            ),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search dishes...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400], size: 22),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(List<String> categories, AppLocalizations l10n, Color primaryColor) {
    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? primaryColor : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isSelected ? primaryColor : Colors.grey[200]!,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    cat,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n, Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.restaurant_menu_rounded, size: 64, color: primaryColor.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 20),
          Text(
            'No items found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + button to add your first item',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB(AppLocalizations l10n, Color primaryColor) {
    return GestureDetector(
      onTap: () {
        final subscription = ref.read(subscriptionProvider);
        if (!subscription.isActive) {
          showSubscriptionExpiredDialog(context);
          return;
        }
        _showAddEditDialog(context, ref, null);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            Text(
              l10n.translate('add_item'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEditDialog(BuildContext context, WidgetRef ref, ItemModel? item) {
    final l10n = ref.read(localizationProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;
    if (l10n == null) return;

    final nameController = TextEditingController(text: item?.name);
    final priceController = TextEditingController(text: item?.price.toStringAsFixed(0));
    final categoryController = TextEditingController(text: item?.category);
    final barcodeController = TextEditingController(text: item?.barcode);
    String? currentImageUrl = item?.imageUrl;
    bool available = item?.isAvailable ?? true;

    final subscription = ref.read(subscriptionProvider);
    final bool isProUnlocked = subscription.planName == 'Pro' ||
                               subscription.planName == 'Enterprise' ||
                               subscription.planName == 'Free Trial';

    final stockCountController = TextEditingController(text: item?.stockCount?.toStringAsFixed(0) ?? '0');
    final lowStockThresholdController = TextEditingController(text: item?.lowStockThreshold?.toString() ?? '5');
    bool trackStock = item?.trackStock ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        File? selectedImageFile;
        bool isUploading = false;
        
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickImage() async {
              final picker = ImagePicker();
              final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
              if (pickedFile != null) {
                setModalState(() {
                  selectedImageFile = File(pickedFile.path);
                  currentImageUrl = pickedFile.path;
                });
              }
            }
            
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    item == null ? Icons.add_rounded : Icons.edit_rounded,
                                    color: primaryColor,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  item == null ? l10n.translate('add_item') : l10n.translate('edit_item'),
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                ),
                              ],
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(Icons.close_rounded, color: Colors.grey[400]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        // Image Upload Section
                        GestureDetector(
                          onTap: pickImage,
                          child: Container(
                            height: 160,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: currentImageUrl != null
                                ? Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(24),
                                        child: currentImageUrl!.startsWith('http')
                                            ? Image.network(currentImageUrl!, width: double.infinity, height: 160, fit: BoxFit.cover)
                                            : (File(currentImageUrl!).existsSync()
                                                ? Image.file(File(currentImageUrl!), width: double.infinity, height: 160, fit: BoxFit.cover)
                                                : Container(color: Colors.grey[200], child: const Icon(Icons.broken_image_rounded))),
                                      ),
                                      Positioned(
                                        right: 8,
                                        top: 8,
                                        child: CircleAvatar(
                                          backgroundColor: Colors.black.withValues(alpha: 0.5),
                                          radius: 16,
                                          child: IconButton(
                                            icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                                            onPressed: pickImage,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_photo_alternate_rounded, size: 40, color: primaryColor.withValues(alpha: 0.5)),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Upload Item Photo',
                                        style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        _buildDialogTextField(
                          controller: nameController,
                          label: l10n.translate('item_name'),
                          icon: Icons.title_rounded,
                          primaryColor: primaryColor,
                        ),
                        const SizedBox(height: 16),
                        
                        _buildDialogTextField(
                          controller: priceController,
                          label: l10n.translate('price'),
                          icon: Icons.payments_rounded,
                          keyboardType: TextInputType.number,
                          primaryColor: primaryColor,
                        ),
                        const SizedBox(height: 16),
                        
                        _buildDialogTextField(
                          controller: categoryController,
                          label: '${l10n.translate('category')} (Optional)',
                          icon: Icons.category_rounded,
                          primaryColor: primaryColor,
                        ),
                        const SizedBox(height: 16),

                        _buildDialogTextField(
                          controller: barcodeController,
                          label: 'Barcode (Optional)',
                          icon: Icons.qr_code_rounded,
                          primaryColor: primaryColor,
                        ),
                        const SizedBox(height: 16),
                        
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: SwitchListTile(
                            title: Text(
                              l10n.translate('available'),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            subtitle: Text(
                              l10n.translate('toggle_out_of_stock'),
                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                            ),
                            value: available,
                            onChanged: (val) => setModalState(() => available = val),
                            activeThumbColor: primaryColor,
                            contentPadding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Track Stock Toggle
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: SwitchListTile(
                            title: const Text(
                              'Track Stock',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            subtitle: const Text(
                              'Decrement stock automatically on checkout',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            value: trackStock,
                            onChanged: (val) {
                              if (!isProUnlocked) {
                                showDialog(
                                  context: context,
                                  builder: (context) => const UpgradeProDialog(featureName: 'Stock Tracking'),
                                );
                                return;
                              }
                              setModalState(() => trackStock = val);
                            },
                            activeThumbColor: primaryColor,
                            contentPadding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        
                        if (trackStock) ...[
                          const SizedBox(height: 16),
                          _buildDialogTextField(
                            controller: stockCountController,
                            label: 'Stock Count',
                            icon: Icons.inventory_2_rounded,
                            keyboardType: TextInputType.number,
                            primaryColor: primaryColor,
                            enabled: isProUnlocked,
                          ),
                          const SizedBox(height: 16),
                          _buildDialogTextField(
                            controller: lowStockThresholdController,
                            label: 'Low Stock Alert Threshold',
                            icon: Icons.notifications_active_rounded,
                            keyboardType: TextInputType.number,
                            primaryColor: primaryColor,
                            enabled: isProUnlocked,
                          ),
                        ],
                        const SizedBox(height: 24),
                        
                        ElevatedButton(
                          onPressed: isUploading ? null : () async {
                            final name = nameController.text;
                            final price = double.tryParse(priceController.text) ?? 0;
                            if (name.isNotEmpty && price > 0) {
                              setModalState(() => isUploading = true);
                              
                              final itemId = item?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
                              String? finalImageUrl = currentImageUrl;

                              // If a new image was picked, upload it
                              if (selectedImageFile != null) {
                                final bytes = await selectedImageFile!.readAsBytes();
                                final url = await ref.read(storageRepositoryProvider).uploadItemImage(
                                  bytes, 
                                  itemId
                                );
                                if (url != null) {
                                  finalImageUrl = url;
                                }
                              }

                              final newItem = ItemModel(
                                id: itemId,
                                name: name,
                                price: price,
                                category: categoryController.text.isNotEmpty ? categoryController.text : null,
                                imageUrl: finalImageUrl,
                                isAvailable: available,
                                costPrice: item?.costPrice,
                                barcode: barcodeController.text.isNotEmpty ? barcodeController.text : null,
                                stockCount: trackStock ? double.tryParse(stockCountController.text) ?? 0.0 : 0.0,
                                trackStock: trackStock,
                                lowStockThreshold: trackStock ? int.tryParse(lowStockThresholdController.text) ?? 5 : 5,
                              );

                              if (item == null) {
                                await ref.read(itemsProvider.notifier).addItem(newItem);
                              } else {
                                await ref.read(itemsProvider.notifier).updateItem(newItem);
                              }
                              
                              if (context.mounted) Navigator.pop(context);
                              HapticFeedback.mediumImpact();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            elevation: 0,
                          ),
                          child: isUploading 
                              ? const SizedBox(
                                  height: 20, 
                                  width: 20, 
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                                )
                              : Text(
                                  l10n.translate('save'),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color primaryColor,
    TextInputType? keyboardType,
    bool enabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: enabled ? Colors.grey[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: enabled ? Colors.grey[500] : Colors.grey[400], fontSize: 13),
          prefixIcon: Icon(icon, size: 20, color: enabled ? Colors.grey[500] : Colors.grey[400]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, WidgetRef ref, ItemModel item, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Item?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(itemsProvider.notifier).deleteItem(item.id);
              Navigator.pop(context);
              HapticFeedback.mediumImpact();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('DELETE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  final ItemModel item;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final Color primaryColor;

  const _MenuItemCard({
    required this.item,
    required this.onToggle,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.1,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                          ? (item.imageUrl!.startsWith('http')
                              ? Image.network(
                                  item.imageUrl!,
                                  fit: BoxFit.cover,
                                  cacheWidth: 300,
                                  errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                                )
                              : Image.file(
                                  File(item.imageUrl!),
                                  fit: BoxFit.cover,
                                  cacheWidth: 300,
                                  errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                                ))
                          : _buildPlaceholder(),
                    ),
                  ),
                  if (!item.isAvailable)
                    Container(
                      color: Colors.black.withValues(alpha: 0.6),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'DISABLED',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    )
                  else if (item.trackStock && (item.stockCount ?? 0.0) <= 0.0)
                    Container(
                      color: Colors.black.withValues(alpha: 0.6),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'OUT OF STOCK',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      height: 32,
                      width: 32,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: PopupMenuButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 20),
                        color: Colors.white,
                        elevation: 8,
                        offset: const Offset(0, 40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        itemBuilder: (context) => [
                          _buildPopupItem(Icons.edit_rounded, 'Edit', Colors.blue, onEdit),
                          _buildPopupItem(Icons.copy_rounded, 'Duplicate', Colors.purple, onDuplicate),
                          _buildPopupItem(Icons.delete_rounded, 'Delete', Colors.red, onDelete),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (item.category != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.category!.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: primaryColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      const Spacer(),
                      _buildAvailabilityToggle(),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₹${item.price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: primaryColor,
                        ),
                      ),
                      if (item.trackStock)
                        _buildStockBadge(item),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Center(
        child: Opacity(
          opacity: 0.2,
          child: Icon(Icons.restaurant_rounded, size: 40, color: primaryColor),
        ),
      ),
    );
  }

  PopupMenuItem _buildPopupItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return PopupMenuItem(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildAvailabilityToggle() {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 36,
        height: 20,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: item.isAvailable ? primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 300),
          alignment: item.isAvailable ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStockBadge(ItemModel item) {
    final bool isLowStock = item.stockCount != null && 
                            item.stockCount! <= (item.lowStockThreshold ?? 5);
    final color = isLowStock ? Colors.red : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isLowStock ? Icons.warning_amber_rounded : Icons.inventory_2_rounded, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            'Stock: ${item.stockCount?.toStringAsFixed(0) ?? "0"}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
