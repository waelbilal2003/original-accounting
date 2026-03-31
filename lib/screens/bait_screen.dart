import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/bait_model.dart';
import '../services/bait_service.dart';
import '../widgets/date_range_filter.dart';

class BaitScreen extends StatefulWidget {
  final String selectedDate;

  const BaitScreen({
    Key? key,
    required this.selectedDate,
  }) : super(key: key);

  @override
  _BaitScreenState createState() => _BaitScreenState();
}

class _BaitScreenState extends State<BaitScreen> {
  final BaitService _baitService = BaitService();
  late Future<List<BaitData>> _baitDataFuture;

  DateTime? _filterFrom;
  DateTime? _filterTo;

  @override
  void initState() {
    super.initState();
    _filterFrom = _parseDate(widget.selectedDate);
    _filterTo = _parseDate(widget.selectedDate);
    _loadData();
  }

  DateTime _parseDate(String dateStr) {
    final parts = dateStr.split('/');
    return DateTime(
        int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  void _loadData({DateTime? from, DateTime? to}) {
    setState(() {
      _filterFrom = from ?? _filterFrom;
      _filterTo = to ?? _filterTo;
      if (_filterFrom != null && _filterTo != null) {
        _baitDataFuture =
            _baitService.getBaitDataForDateRange(_filterFrom!, _filterTo!);
      } else {
        // Fallback to single date if filter not set (should not happen)
        _baitDataFuture = _baitService.getBaitDataForDate(widget.selectedDate);
      }
    });
  }

  void _clearFilter() {
    setState(() {
      _filterFrom = _parseDate(widget.selectedDate);
      _filterTo = _parseDate(widget.selectedDate);
    });
    _loadData();
  }

  Widget _buildHeaderCell(String text, int flex) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style:
            const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  Widget _buildDataCell(String text, int flex,
      {Color color = Colors.black, FontWeight fontWeight = FontWeight.normal}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: color, fontWeight: fontWeight),
      ),
    );
  }

  Future<void> _generateAndSharePdf() async {
    if (_filterFrom == null || _filterTo == null) return;
    final List<BaitData> data =
        await _baitService.getBaitDataForDateRange(_filterFrom!, _filterTo!);
    if (!mounted) return;

    try {
      final pdf = pw.Document();
      var arabicFont;
      try {
        final fontData =
            await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
        arabicFont = pw.Font.ttf(fontData);
      } catch (e) {
        arabicFont = pw.Font.courier();
      }

      final PdfColor headerColor = PdfColor.fromInt(0xFF00695C);
      final PdfColor headerTextColor = PdfColors.white;
      final PdfColor rowEvenColor = PdfColors.white;
      final PdfColor rowOddColor = PdfColor.fromInt(0xFFE0F2F1);
      final PdfColor borderColor = PdfColor.fromInt(0xFFB2DFDB);

      final fromStr =
          '${_filterFrom!.year}/${_filterFrom!.month}/${_filterFrom!.day}';
      final toStr = '${_filterTo!.year}/${_filterTo!.month}/${_filterTo!.day}';

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFont),
          build: (pw.Context context) {
            return [
              pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Center(
                      child: pw.Text(
                        'تقرير البايت',
                        style: pw.TextStyle(
                            fontSize: 18, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Center(
                      child: pw.Text(
                        'من $fromStr إلى $toStr',
                        style: const pw.TextStyle(
                            fontSize: 14, color: PdfColors.grey700),
                      ),
                    ),
                    pw.SizedBox(height: 16),
                    if (data.isEmpty)
                      pw.Center(
                        child: pw.Text('لا توجد حركة مواد في هذا النطاق',
                            style: const pw.TextStyle(color: PdfColors.grey)),
                      )
                    else
                      pw.Table(
                        border:
                            pw.TableBorder.all(color: borderColor, width: 0.5),
                        columnWidths: const {
                          0: pw.FlexColumnWidth(4),
                          1: pw.FlexColumnWidth(2),
                          2: pw.FlexColumnWidth(2),
                          3: pw.FlexColumnWidth(2),
                        },
                        children: [
                          pw.TableRow(
                            decoration: pw.BoxDecoration(color: headerColor),
                            children: [
                              _buildPdfHeaderCell('المادة', headerTextColor),
                              _buildPdfHeaderCell('المشتريات', headerTextColor),
                              _buildPdfHeaderCell('المبيعات', headerTextColor),
                              _buildPdfHeaderCell('البايت', headerTextColor),
                            ],
                          ),
                          ...data.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;
                            final color =
                                idx % 2 == 0 ? rowEvenColor : rowOddColor;
                            return pw.TableRow(
                              decoration: pw.BoxDecoration(color: color),
                              children: [
                                _buildPdfCell(item.materialName),
                                _buildPdfCell(
                                    item.purchasesCount.toStringAsFixed(0)),
                                _buildPdfCell(
                                    item.salesCount.toStringAsFixed(0)),
                                _buildPdfCell(
                                  item.baitValue.toStringAsFixed(0),
                                  isBold: true,
                                  color: item.baitValue >= 0
                                      ? PdfColors.green
                                      : PdfColors.red,
                                ),
                              ],
                            );
                          }).toList(),
                        ],
                      ),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final safeFrom = fromStr.replaceAll('/', '-');
      final safeTo = toStr.replaceAll('/', '-');
      final fileName = 'تقرير_البايت_${safeFrom}_إلى_${safeTo}.pdf';
      final file = File("${output.path}/$fileName");
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)],
          text: 'تقرير البايت للفترة $fromStr إلى $toStr');
    } catch (e) {
      debugPrint("PDF Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('حدث خطأ أثناء تصدير PDF: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  pw.Widget _buildPdfHeaderCell(String text, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      alignment: pw.Alignment.center,
      child: pw.Text(text,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
              color: color, fontSize: 14, fontWeight: pw.FontWeight.bold)),
    );
  }

  pw.Widget _buildPdfCell(String text, {bool isBold = false, PdfColor? color}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      alignment: pw.Alignment.center,
      child: pw.Text(text,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color,
          )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('شاشة البايت'),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          DateRangeFilterIcon(
            from: _filterFrom,
            to: _filterTo,
            onFromChanged: (date) => _loadData(from: date, to: _filterTo),
            onToChanged: (date) => _loadData(from: _filterFrom, to: date),
            onClear: _clearFilter,
            color: Colors.white,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'تصدير PDF',
            onPressed: _generateAndSharePdf,
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: FutureBuilder<List<BaitData>>(
          future: _baitDataFuture,
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
                  'لا توجد حركة مواد لهذا النطاق',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              );
            }

            final baitList = snapshot.data!;

            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  FilterChipWidget(
                    from: _filterFrom,
                    to: _filterTo,
                    onClear: _clearFilter,
                    color: Colors.teal,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    decoration: BoxDecoration(
                        color: Colors.teal.shade100,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                        border: Border.all(color: Colors.teal.shade200)),
                    child: Row(
                      children: [
                        _buildHeaderCell('المادة', 4),
                        _buildHeaderCell('المشتريات', 2),
                        _buildHeaderCell('المبيعات', 2),
                        _buildHeaderCell('البايت', 2),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: baitList.length,
                      itemBuilder: (context, index) {
                        final data = baitList[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 10.0),
                          decoration: BoxDecoration(
                            color: index.isEven
                                ? Colors.white
                                : Colors.grey.shade100,
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade300),
                              left: BorderSide(color: Colors.grey.shade300),
                              right: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          child: Row(
                            children: [
                              _buildDataCell(data.materialName, 4),
                              _buildDataCell(
                                  data.purchasesCount.toStringAsFixed(0), 2),
                              _buildDataCell(
                                  data.salesCount.toStringAsFixed(0), 2),
                              _buildDataCell(
                                data.baitValue.toStringAsFixed(0),
                                2,
                                color: data.baitValue >= 0
                                    ? Colors.green.shade800
                                    : Colors.red.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
