import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class UpgradeProDialog extends StatelessWidget {
  final String featureName;

  const UpgradeProDialog({
    super.key,
    required this.featureName,
  });

  @override
  Widget build(BuildContext context) {
    final proColor = Colors.purple[700]!;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    proColor,
                    Colors.purple[500]!,
                  ],
                ),
              ),
              child: Column(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 56),
                  const SizedBox(height: 12),
                  const Text(
                    'Upgrade to Pro',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Unlock $featureName',
                    style: TextStyle(
                      color: Colors.purple[100],
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Inventory Management is only available on the Pro & Enterprise plans.',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13, height: 1.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  _buildProBenefit(context, 'Real-time Stock Tracking'),
                  const SizedBox(height: 8),
                  _buildProBenefit(context, 'Low Stock Warning Badges'),
                  const SizedBox(height: 8),
                  _buildProBenefit(context, 'Auto-decrement on Checkout'),
                  const SizedBox(height: 8),
                  _buildProBenefit(context, 'Multi-Branch Sync & Loyalty Features'),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                          child: Text('CLOSE', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            GoRouter.of(context).push('/profile/renewal');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: proColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('UPGRADE', style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
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

  Widget _buildProBenefit(BuildContext context, String text) {
    return Row(
      children: [
        const Icon(Icons.stars_rounded, color: Colors.amber, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
