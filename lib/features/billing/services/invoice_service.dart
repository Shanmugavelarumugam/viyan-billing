import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../../../../data/models/item_model.dart';
import '../../../../data/models/shop_model.dart';
import '../../../../data/models/order_model.dart';

class InvoiceService {
  static Future<File> generateInvoice({
    required ShopModel shop,
    required List<CartItemModel> cart,
    required double total,
    required int token,
  }) async {
    final pdf = pw.Document();

    // Load Profile Image
    pw.MemoryImage? profileImage;
    if (shop.profilePhotoPath != null) {
      final imageFile = File(shop.profilePhotoPath!);
      if (await imageFile.exists()) {
        profileImage = pw.MemoryImage(await imageFile.readAsBytes());
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      if (profileImage != null)
                        pw.Container(
                          width: 40,
                          height: 40,
                          margin: const pw.EdgeInsets.only(right: 10),
                          decoration: pw.BoxDecoration(
                            shape: pw.BoxShape.circle,
                            image: pw.DecorationImage(
                              image: profileImage,
                              fit: pw.BoxFit.cover,
                            ),
                          ),
                        ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            shop.name,
                            style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.orange900,
                            ),
                          ),
                          if (shop.address != null)
                            pw.Text(
                              shop.address!,
                              style: const pw.TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'INVOICE',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text('Token: #$token'),
                      pw.Text(
                        'Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),
              pw.Divider(thickness: 2, color: PdfColors.grey300),
              pw.SizedBox(height: 10),

              // Items Table
              pw.TableHelper.fromTextArray(
                border: null,
                headerPadding: const pw.EdgeInsets.all(10),
                cellPadding: const pw.EdgeInsets.all(10),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.orange800,
                ),
                rowDecoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                  ),
                ),
                cellAlignment: pw.Alignment.centerLeft,
                headers: ['Item Description', 'Qty', 'Price', 'Total'],
                data: cart.map((item) {
                  return [
                    item.item.name,
                    item.quantity.toString(),
                    'Rs. ${item.item.price.toStringAsFixed(0)}',
                    'Rs. ${item.total.toStringAsFixed(0)}',
                  ];
                }).toList(),
              ),

              pw.SizedBox(height: 20),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Divider(thickness: 1, color: PdfColors.grey300),
                      pw.Row(
                        children: [
                          pw.Text(
                            'Grand Total: ',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(width: 20),
                          pw.Text(
                            'Rs. ${total.toStringAsFixed(0)}',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.orange900,
                            ),
                          ),
                        ],
                      ),
                      if (shop.upiId != null) ...[
                        pw.SizedBox(height: 10),
                        pw.Text(
                          'UPI ID: ${shop.upiId}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                ],
              ),

              pw.Spacer(),

              // Footer
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Thank you for your business!',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Generated via Viyan Billing',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/invoice_$token.pdf");
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static Future<File> generateReport({
    required ShopModel shop,
    required List<OrderModel> orders,
    required String filterName,
  }) async {
    final pdf = pw.Document();
    final totalSales = orders.fold(0.0, (sum, o) => sum + o.total);
    final totalOrders = orders.length;

    // Load Profile Image if exists
    pw.MemoryImage? profileImage;
    if (shop.profilePhotoPath != null) {
      final imageFile = File(shop.profilePhotoPath!);
      if (await imageFile.exists()) {
        profileImage = pw.MemoryImage(await imageFile.readAsBytes());
      }
    }

    // Aggregate Top Items
    final itemMap = <String, int>{};
    for (var o in orders) {
      for (var ci in o.items) {
        itemMap[ci.item.name] = (itemMap[ci.item.name] ?? 0) + ci.quantity;
      }
    }
    final topItems = itemMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final cashTotal = orders
        .where((o) => o.paymentMethod.toLowerCase() == 'cash')
        .fold(0.0, (sum, o) => sum + o.total);
    final upiTotal = orders
        .where((o) => o.paymentMethod.toLowerCase() == 'upi')
        .fold(0.0, (sum, o) => sum + o.total);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Premium Header
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 20),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.blue800, width: 2),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(
                      children: [
                        if (profileImage != null)
                          pw.Container(
                            width: 60,
                            height: 60,
                            margin: const pw.EdgeInsets.only(right: 15),
                            decoration: pw.BoxDecoration(
                              shape: pw.BoxShape.circle,
                              border: pw.Border.all(color: PdfColors.blue100, width: 2),
                              image: pw.DecorationImage(
                                image: profileImage,
                                fit: pw.BoxFit.cover,
                              ),
                            ),
                          ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              shop.name,
                              style: pw.TextStyle(
                                fontSize: 28,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue900,
                              ),
                            ),
                            if (shop.address != null)
                              pw.Container(
                                width: 200,
                                child: pw.Text(
                                  shop.address!,
                                  style: const pw.TextStyle(
                                    fontSize: 10,
                                    color: PdfColors.grey700,
                                  ),
                                ),
                              ),
                            if (shop.upiId != null)
                              pw.Text(
                                'UPI: ${shop.upiId}',
                                style: const pw.TextStyle(
                                  fontSize: 10,
                                  color: PdfColors.blue700,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          filterName,
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue800,
                          ),
                        ),
                        pw.Text(
                          'SALES REPORT',
                          style: pw.TextStyle(
                            fontSize: 10,
                            letterSpacing: 2,
                            color: PdfColors.grey600,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          DateFormat('dd MMMM yyyy').format(DateTime.now()),
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                        ),
                        pw.Text(
                          DateFormat('hh:mm a').format(DateTime.now()),
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 25),

              // Summary Section
              pw.Row(
                children: [
                  _buildPremiumStatCard(
                    'TOTAL REVENUE',
                    'Rs. ${totalSales.toStringAsFixed(0)}',
                    PdfColors.green50,
                    PdfColors.green900,
                  ),
                  pw.SizedBox(width: 15),
                  _buildPremiumStatCard(
                    'TOTAL ORDERS',
                    totalOrders.toString(),
                    PdfColors.blue50,
                    PdfColors.blue900,
                  ),
                  pw.SizedBox(width: 15),
                  _buildPremiumStatCard(
                    'AVERAGE BILL',
                    'Rs. ${totalOrders > 0 ? (totalSales / totalOrders).toStringAsFixed(0) : '0'}',
                    PdfColors.orange50,
                    PdfColors.orange900,
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Main Content: Top Items & Payments
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left Column: Top Items with Performance Bar
                  pw.Expanded(
                    flex: 3,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('TOP SELLING PERFORMANCE'),
                        pw.SizedBox(height: 15),
                        ...List.generate(topItems.take(8).length, (i) {
                          final entry = topItems[i];
                          final maxQty = topItems.first.value;
                          final percentage = entry.value / maxQty;
                          
                          return pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 12),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text(
                                      '${i + 1}. ${entry.key}',
                                      style: pw.TextStyle(
                                        fontSize: 11,
                                        fontWeight: pw.FontWeight.bold,
                                        color: PdfColors.grey800,
                                      ),
                                    ),
                                    pw.Text(
                                      '${entry.value} sold',
                                      style: const pw.TextStyle(
                                        fontSize: 10,
                                        color: PdfColors.grey600,
                                      ),
                                    ),
                                  ],
                                ),
                                pw.SizedBox(height: 4),
                                pw.Stack(
                                  children: [
                                    pw.Container(
                                      height: 6,
                                      width: double.infinity,
                                      decoration: pw.BoxDecoration(
                                        color: PdfColors.grey100,
                                        borderRadius: pw.BorderRadius.circular(3),
                                      ),
                                    ),
                                    pw.Container(
                                      height: 6,
                                      width: 250 * percentage, // Rough estimation for layout
                                      decoration: pw.BoxDecoration(
                                        color: i == 0 ? PdfColors.blue800 : PdfColors.blue400,
                                        borderRadius: pw.BorderRadius.circular(3),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 40),
                  // Right Column: Payment Breakdown
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('PAYMENT ANALYSIS'),
                        pw.SizedBox(height: 15),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(15),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey50,
                            borderRadius: pw.BorderRadius.circular(10),
                            border: pw.Border.all(color: PdfColors.grey200),
                          ),
                          child: pw.Column(
                            children: [
                              _buildPaymentAnalyticRow('Cash', cashTotal, PdfColors.teal700, (cashTotal / (totalSales > 0 ? totalSales : 1))),
                              pw.SizedBox(height: 15),
                              _buildPaymentAnalyticRow('UPI/Digital', upiTotal, PdfColors.indigo700, (upiTotal / (totalSales > 0 ? totalSales : 1))),
                              pw.Divider(color: PdfColors.grey300, height: 30),
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text(
                                    'NET TOTAL',
                                    style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 12,
                                      color: PdfColors.grey900,
                                    ),
                                  ),
                                  pw.Text(
                                    'Rs. ${totalSales.toStringAsFixed(0)}',
                                    style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 14,
                                      color: PdfColors.blue900,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 30),
                        // Quick Insights
                        pw.Container(
                          padding: const pw.EdgeInsets.all(12),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.blue50,
                            borderRadius: pw.BorderRadius.circular(8),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'QUICK INSIGHT',
                                style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.blue800,
                                  letterSpacing: 1,
                                ),
                              ),
                              pw.SizedBox(height: 5),
                              pw.Text(
                                totalSales > 0 
                                  ? 'Your average order value is Rs. ${(totalSales / totalOrders).toStringAsFixed(0)}. ${topItems.isNotEmpty ? "${topItems.first.key} is your most popular item." : ""}'
                                  : 'No sales data recorded for this period.',
                                style: const pw.TextStyle(fontSize: 9, color: PdfColors.blue900),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),
              
              // Premium Footer
              pw.Container(
                padding: const pw.EdgeInsets.only(top: 20),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Generated via Viyan Billing',
                      style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      'Business Intelligence Report',
                      style: pw.TextStyle(fontSize: 8, color: PdfColors.grey400, fontStyle: pw.FontStyle.italic),
                    ),
                    pw.Text(
                      'Page 1 of 1',
                      style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final fileName = "Report_${filterName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf";
    final file = File("${output.path}/$fileName");
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static pw.Widget _buildSectionHeader(String title) {
    return pw.Row(
      children: [
        pw.Container(
          width: 4,
          height: 14,
          decoration: const pw.BoxDecoration(
            color: PdfColors.blue800,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildPremiumStatCard(String title, String value, PdfColor bgColor, PdfColor textColor) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(15),
        decoration: pw.BoxDecoration(
          color: bgColor,
          borderRadius: pw.BorderRadius.circular(12),
          border: pw.Border.all(color: PdfColor(textColor.red, textColor.green, textColor.blue, 0.1), width: 1),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(color: textColor, fontSize: 8, fontWeight: pw.FontWeight.bold, letterSpacing: 0.5),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              value,
              style: pw.TextStyle(color: textColor, fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildPaymentAnalyticRow(String label, double amount, PdfColor color, double ratio) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.Text(
              'Rs. ${amount.toStringAsFixed(0)}',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: color),
            ),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.Stack(
          children: [
            pw.Container(
              height: 4,
              width: double.infinity,
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: pw.BorderRadius.circular(2),
              ),
            ),
            pw.Container(
              height: 4,
              width: 150 * ratio, // Adjusted for the sidebar width
              decoration: pw.BoxDecoration(
                color: color,
                borderRadius: pw.BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
