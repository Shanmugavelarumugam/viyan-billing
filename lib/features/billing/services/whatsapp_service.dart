import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../data/models/item_model.dart';
import '../../../../data/models/shop_model.dart';
import '../../../../data/models/order_model.dart';
import 'invoice_service.dart';

class WhatsappService {
  static Future<void> sendBill({
    required ShopModel shop,
    required List<CartItemModel> cart,
    required double total,
    required int token,
    String? phone,
    String? customerName,
    Rect? sharePositionOrigin,
  }) async {
    final StringBuffer buffer = StringBuffer();
    final now = DateTime.now();
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(now);

    final bool hasName = customerName != null && customerName.trim().isNotEmpty;

    if (hasName) {
      // Case 1: Name provided (Professional with Bold)
      buffer.writeln('Dear ${customerName.trim()}, \n');
      buffer.writeln('Thank you for your recent order at *${shop.name}*! ');
      buffer.writeln('Your invoice is now available. 🪄 \n');
      buffer.writeln('💰 Amount : *Rs.${total.toStringAsFixed(0)}*');
      buffer.writeln('📅 Date : $dateStr');
      buffer.writeln('🎟️ Token : #$token \n');
      buffer.writeln('How was your experience with your order at *${shop.name}* today?');
    } else {
      // Case 2: No Name provided (Simple Standard)
      buffer.writeln('Thank you for your recent order at ${shop.name}! ');
      buffer.writeln('Your invoice is now available. 🪄 \n');
      buffer.writeln('💰 Amount : Rs.${total.toStringAsFixed(0)}');
      buffer.writeln('📅 Date : $dateStr');
      buffer.writeln('🎟️ Token : #$token \n');
      buffer.writeln('How was your experience with your order at ${shop.name} today?');
    }

    final message = buffer.toString();

    if (phone == null || phone.isEmpty) {
      throw "Enter customer number";
    }

    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (!cleanPhone.startsWith('91')) {
      cleanPhone = '91$cleanPhone';
    }

    // Direct WhatsApp Chat - Force external application mode
    final whatsappUrl = Uri.parse(
      'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}',
    );

    await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    return;
  }

  static Future<void> sendPdfBill({
    required ShopModel shop,
    required List<CartItemModel> cart,
    required double total,
    required int token,
    String? phone,
    Rect? sharePositionOrigin,
  }) async {
    final file = await InvoiceService.generateInvoice(
      shop: shop,
      cart: cart,
      total: total,
      token: token,
    );

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Invoice from ${shop.name} - Token #$token',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  static Future<void> sendReportSummary({
    required ShopModel shop,
    required List<OrderModel> orders,
    required String filterName,
    Rect? sharePositionOrigin,
  }) async {
    final totalSales = orders.fold(0.0, (sum, o) => sum + o.total);
    final totalOrders = orders.length;

    // Aggregate Top Items
    final itemMap = <String, int>{};
    for (var o in orders) {
      for (var ci in o.items) {
        itemMap[ci.item.name] = (itemMap[ci.item.name] ?? 0) + ci.quantity;
      }
    }
    final topItems = itemMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final StringBuffer buffer = StringBuffer();
    buffer.writeln('📊 *POS REPORT: ${filterName.toUpperCase()}*');
    buffer.writeln('🏪 Shop: ${shop.name}');
    buffer.writeln(
      '📅 Generated: ${DateFormat('dd-MMM hh:mm a').format(DateTime.now())}',
    );
    buffer.writeln('--------------------------');

    buffer.writeln('💰 *Total Sales: ₹${totalSales.toStringAsFixed(0)}*');
    buffer.writeln('📦 *Total Orders: $totalOrders*');
    buffer.writeln(
      '🎟️ Avg Bill: ₹${totalOrders > 0 ? (totalSales / totalOrders).toStringAsFixed(0) : '0'}',
    );
    buffer.writeln('--------------------------');

    if (topItems.isNotEmpty) {
      buffer.writeln('🏆 *TOP ITEMS:*');
      for (var entry in topItems.take(3)) {
        buffer.writeln('- ${entry.key}: ${entry.value}');
      }
      buffer.writeln('--------------------------');
    }

    final cashTotal = orders
        .where((o) => o.paymentMethod == 'Cash')
        .fold(0.0, (sum, o) => sum + o.total);
    final upiTotal = orders
        .where((o) => o.paymentMethod == 'UPI')
        .fold(0.0, (sum, o) => sum + o.total);

    buffer.writeln('💳 *PAYMENTS:*');
    buffer.writeln('💵 Cash: ₹${cashTotal.toStringAsFixed(0)}');
    buffer.writeln('📱 UPI: ₹${upiTotal.toStringAsFixed(0)}');
    buffer.writeln('--------------------------');
    buffer.writeln('Generated via *Viyan Billing* 🏛️');

    await SharePlus.instance.share(
      ShareParams(
        text: buffer.toString(),
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  static Future<void> sendPdfReport({
    required ShopModel shop,
    required List<OrderModel> orders,
    required String filterName,
    Rect? sharePositionOrigin,
  }) async {
    final file = await InvoiceService.generateReport(
      shop: shop,
      orders: orders,
      filterName: filterName,
    );

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Sales Report for ${shop.name} ($filterName)',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  static Future<void> launchSupport() async {
    const supportPhone = '919000000000'; // Replace with real support number
    final whatsappUrl = Uri.parse(
      'https://wa.me/$supportPhone?text=${Uri.encodeComponent("Hello Viyan Billing Support, I need help with...")}',
    );
    await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
  }
}
