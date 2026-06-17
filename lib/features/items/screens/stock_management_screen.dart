import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/item_model.dart';
import '../../billing/providers/billing_provider.dart';

class StockManagementScreen extends ConsumerStatefulWidget {
  const StockManagementScreen({super.key});

  @override
  ConsumerState<StockManagementScreen> createState() => _StockManagementScreenState();
}

class _StockManagementScreenState extends ConsumerState<StockManagementScreen> {
  String _searchQuery = '';
  String _filterStatus = 'All'; // 'All', 'Low Stock', 'Out of Stock'

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(itemsProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;

    // Filter items based on search and selected stock status
    final filteredItems = items.where((item) {
      final matchesSearch = item.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final isTracking = item.trackStock;
      final stock = item.stockCount ?? 0.0;
      final threshold = item.lowStockThreshold ?? 5;

      bool matchesStatus = true;
      if (_filterStatus == 'Low Stock') {
        matchesStatus = isTracking && stock > 0 && stock <= threshold;
      } else if (_filterStatus == 'Out of Stock') {
        matchesStatus = isTracking && stock <= 0;
      }

      return matchesSearch && matchesStatus;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Stock Management',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF1E293B)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        centerTitle: false,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              primaryColor.withValues(alpha: 0.01),
              primaryColor.withValues(alpha: 0.03),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Search & Filter Header Card
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: 'Search stock items...',
                          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                          prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400], size: 20),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Quick Status Filters
                    Row(
                      children: [
                        _buildFilterChip('All', Icons.all_inbox_rounded, primaryColor),
                        const SizedBox(width: 8),
                        _buildFilterChip('Low Stock', Icons.warning_amber_rounded, Colors.orange),
                        const SizedBox(width: 8),
                        _buildFilterChip('Out of Stock', Icons.error_outline_rounded, Colors.red),
                      ],
                    ),
                  ],
                ),
              ),

              // Items List
              Expanded(
                child: filteredItems.isEmpty
                    ? _buildEmptyState(primaryColor)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          return _buildStockItemCard(item, primaryColor);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon, Color color) {
    final isSelected = _filterStatus == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filterStatus = label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.1) : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color.withValues(alpha: 0.3) : Colors.grey[200]!,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isSelected ? color : Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? color : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockItemCard(ItemModel item, Color primaryColor) {
    final bool isTracking = item.trackStock;
    final double stock = item.stockCount ?? 0.0;
    final int threshold = item.lowStockThreshold ?? 5;
    
    Color statusColor = Colors.green;
    String statusLabel = 'In Stock';
    
    if (isTracking) {
      if (stock <= 0) {
        statusColor = Colors.red;
        statusLabel = 'Out of Stock';
      } else if (stock <= threshold) {
        statusColor = Colors.orange;
        statusLabel = 'Low Stock';
      }
    } else {
      statusColor = Colors.grey;
      statusLabel = 'Not Tracked';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Row(
        children: [
          // Item Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ),
                    if (item.category != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        item.category!,
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      ),
                    ]
                  ],
                ),
              ],
            ),
          ),
          
          // Stock Controls
          if (isTracking)
            Row(
              children: [
                _buildAdjustButton(
                  icon: Icons.remove_rounded,
                  onTap: () {
                    if (stock > 0) {
                      ref.read(itemsProvider.notifier).updateItem(
                            item.copyWith(stockCount: stock - 1),
                          );
                      HapticFeedback.lightImpact();
                    }
                  },
                ),
                Container(
                  width: 50,
                  alignment: Alignment.center,
                  child: Text(
                    stock.toStringAsFixed(0),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                _buildAdjustButton(
                  icon: Icons.add_rounded,
                  onTap: () {
                    ref.read(itemsProvider.notifier).updateItem(
                          item.copyWith(stockCount: stock + 1),
                        );
                    HapticFeedback.lightImpact();
                  },
                ),
              ],
            )
          else
            TextButton.icon(
              onPressed: () {
                ref.read(itemsProvider.notifier).updateItem(
                      item.copyWith(trackStock: true, stockCount: 10.0),
                    );
                HapticFeedback.mediumImpact();
              },
              icon: Icon(Icons.add_chart_rounded, size: 14, color: primaryColor),
              label: Text(
                'Track Stock',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor),
              ),
              style: TextButton.styleFrom(
                backgroundColor: primaryColor.withValues(alpha: 0.08),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAdjustButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Icon(icon, size: 16, color: const Color(0xFF475569)),
      ),
    );
  }

  Widget _buildEmptyState(Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.inventory_2_rounded, size: 48, color: primaryColor.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 16),
          const Text(
            'No matching items found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting your filters or search query',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
