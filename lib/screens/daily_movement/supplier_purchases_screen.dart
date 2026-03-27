import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../models/purchase_model.dart';
import '../../services/invoices_service.dart';

class SupplierPurchasesScreen extends StatefulWidget {
  final String selectedDate;
  final String supplierName;

  const SupplierPurchasesScreen({
    Key? key,
    required this.selectedDate,
    required this.supplierName,
  }) : super(key: key);

  @override
  _SupplierPurchasesScreenState createState() =>
      _SupplierPurchasesScreenState();
}

class _SupplierPurchasesScreenState extends State<SupplierPurchasesScreen> {
  final InvoicesService _invoicesService = InvoicesService();
  late Future<List<Purchase>> _purchasesDataFuture;

  @override
  void initState() {
    super.initState();
    _purchasesDataFuture = _invoicesService.getPurchasesForSupplier(
        widget.selectedDate, widget.supplierName);
  }

  // --- دالة توليد الـ PDF والمشاركة ---
  Future<void> _generateAndSharePdf(List<Purchase> items) async {
    final pdf = pw.Document();

    // تحميل الخط العربي
    var arabicFont;
    try {
      final fontData = await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
      arabicFont = pw.Font.ttf(fontData);
    } catch (e) {
      arabicFont = pw.Font.courier();
      debugPrint("Error loading font: $e");
    }

    // حساب المجاميع
    double totalStanding = 0;
    double totalNet = 0;
    double totalCount = 0;
    double totalGrand = 0;
    for (var item in items) {
      totalStanding += double.tryParse(item.standing) ?? 0;
      totalNet += double.tryParse(item.net) ?? 0;
      totalCount += double.tryParse(item.count) ?? 0;
      totalGrand += double.tryParse(item.total) ?? 0;
    }

    // تعريف الألوان (Theme: Red)
    final PdfColor headerColor = PdfColor.fromInt(0xFFEF5350); // Red 400
    final PdfColor headerTextColor = PdfColors.white;
    final PdfColor rowEvenColor = PdfColors.white;
    final PdfColor rowOddColor = PdfColor.fromInt(0xFFFFEBEE); // Red 50
    final PdfColor borderColor = PdfColor.fromInt(0xFFE0E0E0); // Grey 300
    final PdfColor totalRowColor = PdfColor.fromInt(0xFFFFCDD2); // Red 100
    final PdfColor grandTotalColor = PdfColor.fromInt(0xFFC62828); // Red 800

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(
          base: arabicFont,
          bold: arabicFont,
        ),
        build: (pw.Context context) {
          return [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                children: [
                  // --- العناوين ---
                  pw.Center(
                    child: pw.Text(
                      'مشتريات من المورد',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textDirection: pw.TextDirection.rtl,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Center(
                    child: pw.Text(
                      'بتاريخ ${widget.selectedDate}',
                      style: const pw.TextStyle(
                          fontSize: 14, color: PdfColors.grey700),
                      textDirection: pw.TextDirection.rtl,
                    ),
                  ),
                  pw.SizedBox(height: 15),

                  // --- الجدول ---
                  pw.Table(
                    border: pw.TableBorder.all(color: borderColor, width: 0.5),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(4), // المادة
                      1: const pw.FlexColumnWidth(2), // العدد
                      2: const pw.FlexColumnWidth(3), // العبوة
                      3: const pw.FlexColumnWidth(2), // القائم
                      4: const pw.FlexColumnWidth(2), // الصافي
                      5: const pw.FlexColumnWidth(2), // السعر
                      6: const pw.FlexColumnWidth(3), // الإجمالي
                    },
                    children: [
                      // رأس الجدول
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: headerColor),
                        children: [
                          _buildPdfHeaderCell('المادة', headerTextColor),
                          _buildPdfHeaderCell('العدد', headerTextColor),
                          _buildPdfHeaderCell('العبوة', headerTextColor),
                          _buildPdfHeaderCell('القائم', headerTextColor),
                          _buildPdfHeaderCell('الصافي', headerTextColor),
                          _buildPdfHeaderCell('السعر', headerTextColor),
                          _buildPdfHeaderCell('الإجمالي', headerTextColor),
                        ],
                      ),
                      // البيانات
                      ...items.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final color =
                            index % 2 == 0 ? rowEvenColor : rowOddColor;
                        return pw.TableRow(
                          decoration: pw.BoxDecoration(color: color),
                          children: [
                            _buildPdfCell(item.material),
                            _buildPdfCell(item.count),
                            _buildPdfCell(item.packaging),
                            _buildPdfCell(item.standing),
                            _buildPdfCell(item.net),
                            _buildPdfCell(item.price),
                            _buildPdfCell(item.total,
                                textColor: grandTotalColor, isBold: true),
                          ],
                        );
                      }).toList(),
                      // سطر المجموع
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: totalRowColor),
                        children: [
                          _buildPdfCell('م', isBold: true),
                          _buildPdfCell(totalCount.toStringAsFixed(0),
                              isBold: true),
                          _buildPdfCell(''),
                          _buildPdfCell(totalStanding.toStringAsFixed(2),
                              isBold: true),
                          _buildPdfCell(totalNet.toStringAsFixed(2),
                              isBold: true),
                          _buildPdfCell(''),
                          _buildPdfCell(totalGrand.toStringAsFixed(2),
                              textColor: grandTotalColor, isBold: true),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 20),

                  // المجموع النهائي
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: grandTotalColor,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        'المجموع ${totalGrand.toStringAsFixed(2)} ليرة سورية فقط لا غير .',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textDirection: pw.TextDirection.rtl,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/مشتريات_${widget.supplierName}.pdf");
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)],
        text:
            'مشتريات المورد ${widget.supplierName} بتاريخ ${widget.selectedDate}');
  }

  // --- دوال مساعدة للـ PDF ---
  pw.Widget _buildPdfHeaderCell(String text, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        textDirection: pw.TextDirection.rtl,
        style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold, color: color, fontSize: 10),
      ),
    );
  }

  pw.Widget _buildPdfCell(String text,
      {PdfColor textColor = PdfColors.black, bool isBold = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        textDirection: pw.TextDirection.rtl,
        style: pw.TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  // --- دوال بناء الواجهة ---
  Widget _buildHeaderCell(String text, int flex, {Color color = Colors.white}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildDataCell(String text, int flex,
      {Color color = Colors.black87,
      FontWeight fontWeight = FontWeight.normal}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontWeight: fontWeight,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'مشتريات من المورد ${widget.supplierName}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'مشاركة PDF',
            onPressed: () async {
              final data = await _purchasesDataFuture;
              if (data.isNotEmpty) {
                _generateAndSharePdf(data);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('لا توجد بيانات لمشاركتها')),
                );
              }
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20.0),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'بتاريخ ${widget.selectedDate}',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: FutureBuilder<List<Purchase>>(
          future: _purchasesDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('حدث خطأ: ${snapshot.error}'));
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text(
                  'لا توجد مشتريات من هذا المورد في اليوم المحدد',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              );
            }

            final purchases = snapshot.data!;

            // --- حساب مجاميع المشتريات UI ---
            double totalStanding = 0;
            double totalNet = 0;
            double totalCount = 0;
            double totalGrand = 0;
            for (var item in purchases) {
              totalStanding += double.tryParse(item.standing) ?? 0;
              totalNet += double.tryParse(item.net) ?? 0;
              totalCount += double.tryParse(item.count) ?? 0;
              totalGrand += double.tryParse(item.total) ?? 0;
            }

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    // --- جدول المشتريات UI ---
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        children: [
                          Container(
                            color: Colors.red.shade400,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                _buildHeaderCell('المادة', 4),
                                _buildHeaderCell('العدد', 2),
                                _buildHeaderCell('العبوة', 3),
                                _buildHeaderCell('القائم', 2),
                                _buildHeaderCell('الصافي', 2),
                                _buildHeaderCell('السعر', 2),
                                _buildHeaderCell('الإجمالي', 3),
                              ],
                            ),
                          ),
                          ...purchases.map((item) => Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: purchases.indexOf(item) % 2 == 0
                                      ? Colors.white
                                      : Colors.red.shade50,
                                  border: Border(
                                      bottom: BorderSide(
                                          color: Colors.grey.shade300)),
                                ),
                                child: Row(
                                  children: [
                                    _buildDataCell(item.material, 4),
                                    _buildDataCell(item.count, 2),
                                    _buildDataCell(item.packaging, 3),
                                    _buildDataCell(item.standing, 2),
                                    _buildDataCell(item.net, 2),
                                    _buildDataCell(item.price, 2),
                                    _buildDataCell(item.total, 3,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red.shade900),
                                  ],
                                ),
                              )),
                          Container(
                            color: Colors.red.shade100,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                _buildDataCell('المجموع', 1,
                                    fontWeight: FontWeight.bold),
                                _buildDataCell(totalCount.toStringAsFixed(0), 2,
                                    fontWeight: FontWeight.bold),
                                _buildDataCell('', 3),
                                _buildDataCell(
                                    totalStanding.toStringAsFixed(2), 2,
                                    fontWeight: FontWeight.bold),
                                _buildDataCell(totalNet.toStringAsFixed(2), 2,
                                    fontWeight: FontWeight.bold),
                                _buildDataCell('', 2,
                                    fontWeight: FontWeight.bold),
                                _buildDataCell(totalGrand.toStringAsFixed(2), 3,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade900),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
