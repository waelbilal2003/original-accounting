import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../models/purchase_model.dart';
import '../../services/invoices_service.dart';
import '../../services/supplier_index_service.dart';

class SupplierPurchasesScreen extends StatefulWidget {
  final String selectedDate;
  final String supplierName;
  final String storeName;

  const SupplierPurchasesScreen({
    Key? key,
    required this.selectedDate,
    required this.supplierName,
    required this.storeName,
  }) : super(key: key);

  @override
  _SupplierPurchasesScreenState createState() =>
      _SupplierPurchasesScreenState();
}

class _SupplierPurchasesScreenState extends State<SupplierPurchasesScreen> {
  final InvoicesService _invoicesService = InvoicesService();
  final SupplierIndexService _supplierIndexService = SupplierIndexService();
  late Future<List<Purchase>> _purchasesDataFuture;
  double? _supplierBalance;

  // متغيرات الفلترة
  DateTime? _filterFrom;
  DateTime? _filterTo;
  List<Purchase> _allItems = [];
  List<Purchase> _filteredItems = [];
  bool _isFiltered = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
    _loadSupplierBalance();
  }

  Future<void> _loadSupplierBalance() async {
    final allSuppliers = await _supplierIndexService.getAllSuppliersWithData();
    for (var entry in allSuppliers.entries) {
      if (entry.value.name.toLowerCase() ==
          widget.supplierName.trim().toLowerCase()) {
        if (mounted) {
          setState(() {
            _supplierBalance = entry.value.balance;
          });
        }
        return;
      }
    }
  }

  // دالة تطبيق الفلترة
  void _applyFilter() {
    _loadItems();
  }

  void _clearFilter() {
    setState(() {
      _filterFrom = null;
      _filterTo = null;
      _isFiltered = false;
    });
    _loadItems();
  }

  // 4. دالة تحويل التاريخ
  DateTime? _parseDateFromString(String dateStr) {
    try {
      final parts = dateStr.split('/');
      if (parts.length != 3) return null;
      return DateTime(
          int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    } catch (_) {
      return null;
    }
  }

// 5. نافذة اختيار التاريخ
  Future<void> _showDateRangeDialog() async {
    final now = DateTime.now();
    DateTime tempFrom = _filterFrom ?? now;
    DateTime tempTo = _filterTo ?? now;

    DateTime _clampDay(int y, int m, int d) {
      final max = DateUtils.getDaysInMonth(y, m);
      return DateTime(y, m, d > max ? max : d);
    }

    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر'
    ];

    Widget miniPicker({
      required String label,
      required String display,
      required VoidCallback onUp,
      required VoidCallback onDown,
      required Color color,
    }) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 28,
                  width: 28,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.arrow_drop_up,
                        size: 22, color: Colors.green[600]),
                    onPressed: onUp,
                  ),
                ),
                SizedBox(
                  height: 26,
                  child: Center(
                    child: Text(display,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                SizedBox(
                  height: 28,
                  width: 28,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.arrow_drop_down,
                        size: 22, color: Colors.red[600]),
                    onPressed: onDown,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    Widget datePicker({
      required String sectionLabel,
      required DateTime date,
      required Color color,
      required void Function(DateTime) onChanged,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, size: 13, color: color),
              const SizedBox(width: 4),
              Text(sectionLabel,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(width: 8),
              Text(
                '${date.year}/${date.month}/${date.day}',
                style: TextStyle(
                    fontSize: 12, color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              miniPicker(
                label: 'اليوم',
                display: date.day.toString(),
                color: color,
                onUp: () =>
                    onChanged(_clampDay(date.year, date.month, date.day + 1)),
                onDown: () =>
                    onChanged(_clampDay(date.year, date.month, date.day - 1)),
              ),
              miniPicker(
                label: 'الشهر',
                display: months[date.month - 1],
                color: color,
                onUp: () {
                  final m = date.month < 12 ? date.month + 1 : 1;
                  onChanged(_clampDay(date.year, m, date.day));
                },
                onDown: () {
                  final m = date.month > 1 ? date.month - 1 : 12;
                  onChanged(_clampDay(date.year, m, date.day));
                },
              ),
              miniPicker(
                label: 'السنة',
                display: date.year.toString(),
                color: color,
                onUp: () =>
                    onChanged(_clampDay(date.year + 1, date.month, date.day)),
                onDown: () =>
                    onChanged(_clampDay(date.year - 1, date.month, date.day)),
              ),
            ],
          ),
        ],
      );
    }

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              title: const Row(
                children: [
                  Icon(Icons.date_range, color: Colors.red),
                  SizedBox(width: 8),
                  Text('فلترة بالتاريخ',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // صف أفقي يحتوي على "من تاريخ" (يمين) و "إلى تاريخ" (يسار)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: datePicker(
                          sectionLabel: 'من تاريخ',
                          date: tempFrom,
                          color: Colors.red[700]!,
                          onChanged: (d) => setDialogState(() => tempFrom = d),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: datePicker(
                          sectionLabel: 'إلى تاريخ',
                          date: tempTo,
                          color: Colors.red[800]!,
                          onChanged: (d) => setDialogState(() => tempTo = d),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                TextButton(
                  onPressed: () {
                    _clearFilter();
                    Navigator.pop(ctx);
                  },
                  child: const Text('مسح الفلتر',
                      style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700]),
                  onPressed: () {
                    if (tempFrom.isAfter(tempTo)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('تاريخ البداية يجب أن يكون قبل النهاية'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    setState(() {
                      _filterFrom = tempFrom;
                      _filterTo = tempTo;
                    });
                    _applyFilter();
                    Navigator.pop(ctx);
                  },
                  child: const Text('تطبيق',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  // --- دالة توليد الـ PDF والمشاركة (تستخدم البيانات المفلترة) ---
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

    // وصف نطاق الفلتر للـ PDF
    String filterDesc = 'الفترة: حتى تاريخ ${widget.selectedDate}';
    if (_filterFrom != null || _filterTo != null) {
      final from = _filterFrom != null
          ? '${_filterFrom!.year}/${_filterFrom!.month}/${_filterFrom!.day}'
          : 'البداية';
      final to = _filterTo != null
          ? '${_filterTo!.year}/${_filterTo!.month}/${_filterTo!.day}'
          : 'النهاية';
      filterDesc = 'الفترة: من $from إلى $to';
    }

    final String balanceTextPdf =
        _supplierBalance != null ? _supplierBalance!.toStringAsFixed(2) : '---';

    // تعريف الألوان (Theme: Red)
    final PdfColor headerColor = PdfColor.fromInt(0xFFEF5350);
    final PdfColor headerTextColor = PdfColors.white;
    final PdfColor rowEvenColor = PdfColors.white;
    final PdfColor rowOddColor = PdfColor.fromInt(0xFFFFEBEE);
    final PdfColor borderColor = PdfColor.fromInt(0xFFE0E0E0);
    final PdfColor totalRowColor = PdfColor.fromInt(0xFFFFCDD2);
    final PdfColor grandTotalColor = PdfColor.fromInt(0xFFC62828);

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
                      'مشتريات من المورد ${widget.supplierName}',
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
                      '${filterDesc} لمحل ${widget.storeName}',
                      style: const pw.TextStyle(
                          fontSize: 14, color: PdfColors.grey700),
                      textDirection: pw.TextDirection.rtl,
                    ),
                  ),
                  pw.SizedBox(height: 15),

                  // --- الجدول (معكوس) ---
                  pw.Table(
                    border: pw.TableBorder.all(color: borderColor, width: 0.5),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(3), // الإجمالي
                      1: const pw.FlexColumnWidth(2), // السعر
                      2: const pw.FlexColumnWidth(2), // الصافي
                      3: const pw.FlexColumnWidth(2), // القائم
                      4: const pw.FlexColumnWidth(3), // العبوة
                      5: const pw.FlexColumnWidth(2), // العدد
                      6: const pw.FlexColumnWidth(4), // المادة
                    },
                    children: [
                      // رأس الجدول (معكوس)
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: headerColor),
                        children: [
                          _buildPdfHeaderCell('الإجمالي', headerTextColor),
                          _buildPdfHeaderCell('السعر', headerTextColor),
                          _buildPdfHeaderCell('الصافي', headerTextColor),
                          _buildPdfHeaderCell('القائم', headerTextColor),
                          _buildPdfHeaderCell('العبوة', headerTextColor),
                          _buildPdfHeaderCell('العدد', headerTextColor),
                          _buildPdfHeaderCell('المادة', headerTextColor),
                        ],
                      ),
                      // البيانات (معكوسة)
                      ...items.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final color =
                            index % 2 == 0 ? rowEvenColor : rowOddColor;
                        return pw.TableRow(
                          decoration: pw.BoxDecoration(color: color),
                          children: [
                            _buildPdfCell(item.total,
                                textColor: grandTotalColor, isBold: true),
                            _buildPdfCell(item.price),
                            _buildPdfCell(item.net),
                            _buildPdfCell(item.standing),
                            _buildPdfCell(item.packaging),
                            _buildPdfCell(item.count),
                            _buildPdfCell(item.material),
                          ],
                        );
                      }).toList(),
                      // سطر المجموع (معكوس)
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: totalRowColor),
                        children: [
                          _buildPdfCell(totalGrand.toStringAsFixed(2),
                              textColor: grandTotalColor, isBold: true),
                          _buildPdfCell(''),
                          _buildPdfCell(totalNet.toStringAsFixed(2),
                              isBold: true),
                          _buildPdfCell(totalStanding.toStringAsFixed(2),
                              isBold: true),
                          _buildPdfCell(''),
                          _buildPdfCell(totalCount.toStringAsFixed(0),
                              isBold: true),
                          _buildPdfCell('المجموع', isBold: true),
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
                        'المجموع ${totalGrand.toStringAsFixed(2)} ليرة سورية فقط لا غير  الرصيد : $balanceTextPdf.',
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
        text: 'مشتريات المورد ${widget.supplierName} - ${filterDesc}');
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
          fontSize: 18,
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
          fontSize: 17,
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
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.date_range),
                if (_isFiltered)
                  Positioned(
                    top: -4,
                    left: -4,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'فلترة بالتاريخ',
            onPressed: _showDateRangeDialog,
          ),
          if (_isFiltered)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              tooltip: 'مسح الفلتر',
              onPressed: _clearFilter,
            ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'مشاركة PDF',
            onPressed: () async {
              if (_filteredItems.isNotEmpty) {
                _generateAndSharePdf(_filteredItems);
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
              'بتاريخ ${widget.selectedDate} لمحل ${widget.storeName}',
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

            // تخزين البيانات الأصلية
            if (_allItems.isEmpty) {
              _allItems = snapshot.data!;
              _filteredItems = List.from(_allItems);
            }

            final displayItems = _filteredItems;

            if (displayItems.isEmpty && _isFiltered) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.filter_alt_off,
                        size: 48, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'لا توجد بيانات في النطاق الزمني المحدد',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _clearFilter,
                      child: const Text('مسح الفلتر'),
                    ),
                  ],
                ),
              );
            }

            // --- حساب مجاميع المشتريات UI ---
            double totalStanding = 0;
            double totalNet = 0;
            double totalCount = 0;
            double totalGrand = 0;
            for (var item in displayItems) {
              totalStanding += double.tryParse(item.standing) ?? 0;
              totalNet += double.tryParse(item.net) ?? 0;
              totalCount += double.tryParse(item.count) ?? 0;
              totalGrand += double.tryParse(item.total) ?? 0;
            }

            final bool hasFilter = _filterFrom != null || _filterTo != null;

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    // شريط الفلتر الفعّال
                    if (hasFilter)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            border: Border.all(color: Colors.red[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.filter_alt,
                                  color: Colors.red[700], size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'الفلتر: '
                                  '${_filterFrom != null ? '${_filterFrom!.year}/${_filterFrom!.month}/${_filterFrom!.day}' : '—'}'
                                  ' ← '
                                  '${_filterTo != null ? '${_filterTo!.year}/${_filterTo!.month}/${_filterTo!.day}' : '—'}',
                                  style: TextStyle(
                                      color: Colors.red[800], fontSize: 12),
                                ),
                              ),
                              GestureDetector(
                                onTap: _clearFilter,
                                child: Icon(Icons.close,
                                    color: Colors.red[700], size: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
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
                          ...displayItems.map((item) => Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: displayItems.indexOf(item) % 2 == 0
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
                                _buildDataCell('المجموع', 4,
                                    fontWeight: FontWeight.bold), // المادة
                                _buildDataCell(totalCount.toStringAsFixed(0), 2,
                                    fontWeight: FontWeight.bold), // العدد
                                _buildDataCell('', 3,
                                    fontWeight: FontWeight.bold), // العبوة
                                _buildDataCell(
                                    totalStanding.toStringAsFixed(2), 2,
                                    fontWeight: FontWeight.bold), // القائم
                                _buildDataCell(totalNet.toStringAsFixed(2), 2,
                                    fontWeight: FontWeight.bold), // الصافي
                                _buildDataCell('', 2,
                                    fontWeight: FontWeight.bold), // السعر
                                _buildDataCell(totalGrand.toStringAsFixed(2), 3,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade900), // الإجمالي
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // --- شريط الرصيد ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16.0),
                      margin: const EdgeInsets.only(top: 8.0),
                      decoration: BoxDecoration(
                        color: Colors.red.shade800,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'المجموع ${totalGrand.toStringAsFixed(2)} ليرة سورية فقط لا غير  الرصيد : ${_supplierBalance != null ? _supplierBalance!.toStringAsFixed(2) : '---'}.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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

  Future<void> _loadItems() async {
    if (!mounted) return;
    setState(() {
      _isFiltered = _filterFrom != null || _filterTo != null;
    });

    final selectedDate = _parseDateFromString(widget.selectedDate);
    if (selectedDate == null) return;

    DateTime rangeStart;
    DateTime rangeEnd;

    if (_filterFrom != null || _filterTo != null) {
      rangeStart = _filterFrom ?? DateTime(2000, 1, 1);
      rangeEnd = _filterTo ?? DateTime.now();
    } else {
      rangeStart = DateTime(2000, 1, 1);
      rangeEnd = DateTime.now();
    }

    final List<Purchase> items = [];

    int daysDiff = rangeEnd.difference(rangeStart).inDays;
    for (int i = 0; i <= daysDiff; i++) {
      final currentDate = rangeStart.add(Duration(days: i));
      final dateString =
          '${currentDate.year}/${currentDate.month}/${currentDate.day}';
      final dayItems = await _invoicesService.getPurchasesForSupplier(
          dateString, widget.supplierName);
      items.addAll(dayItems);
    }

    if (!mounted) return;
    setState(() {
      _allItems = items;
      _filteredItems = items;
      _purchasesDataFuture = Future.value(items);
    });
  }
}
