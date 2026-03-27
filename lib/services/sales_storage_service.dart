import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../models/sales_model.dart';
import 'package:flutter/foundation.dart';

class SalesStorageService {
  Future<String> _getBasePath() async {
    Directory? directory;

    if (Platform.isAndroid) {
      directory = await getExternalStorageDirectory();
    } else if (Platform.isWindows) {
      directory = await getApplicationDocumentsDirectory();
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    return directory!.path;
  }

  // اسم الملف الآن يحتوي فقط على التاريخ - مثل المشتريات
  String _createFileName(String date) {
    final dateParts = date.split('/');
    final formattedDate = dateParts.join('-');
    return 'sales-$formattedDate.json'; // فقط sales بدلاً من purchases
  }

  Future<bool> saveSalesDocument(SalesDocument document) async {
    try {
      final basePath = await _getBasePath();
      //  التعديل: تغيير اسم المجلد إلى SalesJournals
      final folderPath = '$basePath/SalesJournals';

      final folder = Directory(folderPath);
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }

      final fileName = _createFileName(document.date);
      final filePath = '$folderPath/$fileName';
      final file = File(filePath);

      SalesDocument? existingDocument;
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
        existingDocument = SalesDocument.fromJson(jsonMap);
      }

      // منطق تحديد رقم السجل الصحيح
      final String finalRecordNumber;
      if (existingDocument != null) {
        // إذا كانت اليومية موجودة بالفعل، نحافظ على رقمها
        finalRecordNumber = existingDocument.recordNumber;
      } else {
        // إذا كانت يومية جديدة تماماً، نطلب رقماً جديداً
        finalRecordNumber = await getNextJournalNumber();
      }

      // يتم دمج السجلات في شاشة المبيعات، لذلك نستخدم القائمة النهائية مباشرة
      final allSales = document.sales;
      final totals = _calculateSalesTotals(allSales);

      final updatedDocument = SalesDocument(
        recordNumber: finalRecordNumber, // استخدام الرقم الصحيح
        date: document.date,
        sellerName: document.sellerName,
        storeName: document.storeName,
        dayName: document.dayName,
        sales: allSales,
        totals: totals,
      );

      final updatedJsonString = jsonEncode(updatedDocument.toJson());
      await file.writeAsString(updatedJsonString);

      if (kDebugMode) {
        debugPrint('✅ تم حفظ سجل المبيعات رقم $finalRecordNumber: $filePath');
        debugPrint('📊 عدد السجلات: ${allSales.length}');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ خطأ في حفظ سجل المبيعات: $e');
      }
      return false;
    }
  }

  // قراءة مستند المبيعات
  Future<SalesDocument?> loadSalesDocument(String date) async {
    try {
      final basePath = await _getBasePath();
      //  التعديل: تغيير اسم المجلد إلى SalesJournals
      final folderPath = '$basePath/SalesJournals';
      final fileName = _createFileName(date);
      final filePath = '$folderPath/$fileName';

      final file = File(filePath);
      if (!await file.exists()) {
        if (kDebugMode) {
          debugPrint('⚠️ ملف المبيعات غير موجود: $filePath');
        }
        return null;
      }

      final jsonString = await file.readAsString();
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      final document = SalesDocument.fromJson(jsonMap);

      if (kDebugMode) {
        debugPrint('✅ تم تحميل ملف المبيعات: $filePath');
      }

      return document;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ خطأ في قراءة ملف المبيعات: $e');
      }
      return null;
    }
  }

  // الحصول على التواريخ المتاحة مع أرقام اليوميات
  Future<List<Map<String, String>>> getAvailableDatesWithNumbers() async {
    try {
      final basePath = await _getBasePath();
      //  التعديل: تغيير اسم المجلد إلى SalesJournals
      final folderPath = '$basePath/SalesJournals';

      final folder = Directory(folderPath);
      if (!await folder.exists()) {
        return [];
      }

      final files = await folder.list().toList();
      final datesWithNumbers = <Map<String, String>>[];

      for (var file in files) {
        if (file is File && file.path.endsWith('.json')) {
          try {
            final fileName = file.path.split('/').last;

            // التأكد من أن الملف هو لـ SALES فقط
            if (fileName.startsWith('sales-')) {
              final jsonString = await file.readAsString();
              final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
              final date = jsonMap['date']?.toString() ?? '';
              final journalNumber = jsonMap['recordNumber']?.toString() ?? '1';

              if (date.isNotEmpty) {
                datesWithNumbers.add({
                  'date': date,
                  'journalNumber': journalNumber,
                  'fileName': fileName,
                });
              }
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('❌ خطأ في قراءة ملف: ${file.path}, $e');
            }
          }
        }
      }

      datesWithNumbers.sort((a, b) {
        try {
          final dateA = _parseDate(a['date'] ?? '');
          final dateB = _parseDate(b['date'] ?? '');
          return dateB.compareTo(dateA);
        } catch (e) {
          return 0;
        }
      });

      return datesWithNumbers;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ خطأ في قراءة التواريخ: $e');
      }
      return [];
    }
  }

  Future<String> getNextJournalNumber() async {
    try {
      final basePath = await _getBasePath();
      //  التعديل: تغيير اسم المجلد إلى SalesJournals
      final folderPath = '$basePath/SalesJournals';
      final folder = Directory(folderPath);

      if (!await folder.exists()) {
        return '1'; // أول يومية على الإطلاق
      }

      final files = await folder.list().toList();
      int maxJournalNumber = 0;

      for (var file in files) {
        if (file is File &&
            file.path.split('/').last.startsWith('sales-') &&
            file.path.endsWith('.json')) {
          try {
            final jsonString = await file.readAsString();
            final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
            final journalNumber =
                int.tryParse(jsonMap['recordNumber'] ?? '0') ?? 0;

            if (journalNumber > maxJournalNumber) {
              maxJournalNumber = journalNumber;
            }
          } catch (e) {
            // تجاهل الملفات التالفة
          }
        }
      }

      return (maxJournalNumber + 1).toString();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ خطأ في الحصول على رقم يومية المبيعات التالي: $e');
      }
      return '1';
    }
  }

  // دالة مساعدة لحساب مجاميع المبيعات
  Map<String, String> _calculateSalesTotals(List<Sale> sales) {
    double totalCount = 0;
    double totalBase = 0;
    double totalNet = 0;
    double totalGrand = 0;

    for (var sale in sales) {
      try {
        totalCount += double.tryParse(sale.count) ?? 0;
        totalBase += double.tryParse(sale.standing) ?? 0;
        totalNet += double.tryParse(sale.net) ?? 0;
        totalGrand += double.tryParse(sale.total) ?? 0;
      } catch (e) {}
    }

    return {
      'totalCount': totalCount.toStringAsFixed(0),
      'totalBase': totalBase.toStringAsFixed(2),
      'totalNet': totalNet.toStringAsFixed(2),
      'totalGrand': totalGrand.toStringAsFixed(2),
      'totalPayments':
          totalGrand.toStringAsFixed(2), // مطلوب لـ account_summary_screen
    };
  }

  // الحصول على قائمة أرقام السجلات المتاحة لتاريخ معين
  Future<List<String>> getAvailableRecords(String date) async {
    try {
      final basePath = await _getBasePath();
      final folderPath = '$basePath/AlhalJournals';
      final fileName = _createFileName(date);
      final filePath = '$folderPath/$fileName';

      // التحقق من وجود الملف
      final file = File(filePath);
      if (!await file.exists()) {
        return [];
      }

      // في الهيكل الجديد، الملف الواحد يحتوي كل السجلات
      // لذا نرجع قائمة تحتوي على رقم السجل الوحيد
      final jsonString = await file.readAsString();
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      final recordNumber = jsonMap['recordNumber']?.toString() ?? '1';

      return [recordNumber];
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ خطأ في قراءة سجلات المبيعات: $e');
      }
      return [];
    }
  }

  // الحصول على الرقم التالي المتاح لسجل جديد
  Future<String> getNextRecordNumber(String date) async {
    try {
      final file = await _getSalesFile(date);
      if (!await file.exists()) {
        return '1';
      }

      // قراءة الرقم الموجود في الملف
      final jsonString = await file.readAsString();
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      final currentNumber = int.tryParse(jsonMap['recordNumber'] ?? '1') ?? 1;

      return currentNumber.toString(); // نفس الرقم (ملف واحد لكل تاريخ)
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ خطأ في الحصول على الرقم التسلسلي التالي: $e');
      }
      return '1';
    }
  }

  // دالة مساعدة للحصول على ملف المبيعات
  Future<File> _getSalesFile(String date) async {
    final basePath = await _getBasePath();
    final folderPath = '$basePath/AlhalJournals';
    final fileName = _createFileName(date);
    return File('$folderPath/$fileName');
  }

  // حذف سجل معين
  Future<bool> deleteSalesDocument(String date, String recordNumber) async {
    try {
      // الحصول على المسار الأساسي
      final basePath = await _getBasePath();

      // إنشاء مسار المجلد
      final folderPath = '$basePath/AlhalJournals';

      // إنشاء اسم الملف
      final fileName = _createFileName(date);
      final filePath = '$folderPath/$fileName';

      // حذف الملف
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();

        if (kDebugMode) {
          debugPrint('✅ تم حذف ملف المبيعات: $filePath');
        }

        return true;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ خطأ في حذف ملف المبيعات: $e');
      }
      return false;
    }
  }

  // الحصول على مسار الملف لمشاركته
  Future<String?> getFilePath(String date, String recordNumber) async {
    try {
      final basePath = await _getBasePath();
      final folderPath = '$basePath/AlhalJournals';
      final fileName = _createFileName(date);
      final filePath = '$folderPath/$fileName';

      // التحقق من وجود الملف
      final file = File(filePath);
      if (await file.exists()) {
        return filePath;
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ خطأ في الحصول على مسار ملف المبيعات: $e');
      }
      return null;
    }
  }

  // دالة جديدة: حساب إجمالي المبيعات النقدية ليوم محدد
  Future<double> getTotalCashSales(String date) async {
    double totalCashSales = 0;

    try {
      // التصحيح: استدعاء الدالة بمعامل واحد فقط
      final doc = await loadSalesDocument(date);
      if (doc != null) {
        for (var sale in doc.sales) {
          if (sale.cashOrDebt == 'نقدي') {
            totalCashSales += double.tryParse(sale.total) ?? 0;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error calculating cash sales: $e');
      }
    }

    return totalCashSales;
  }

  // دالة جديدة: حساب إجمالي جميع المبيعات (نقدي ودين)
  Future<double> getTotalSales(String date) async {
    double totalSales = 0;

    try {
      // التصحيح: استدعاء الدالة بمعامل واحد فقط
      final doc = await loadSalesDocument(date);
      if (doc != null) {
        for (var sale in doc.sales) {
          totalSales += double.tryParse(sale.total) ?? 0;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error calculating total sales: $e');
      }
    }

    return totalSales;
  }

// دالة مساعدة لتحويل التاريخ من صيغة dd/MM/yyyy إلى DateTime
  DateTime _parseDate(String dateString) {
    final parts = dateString.split('/');
    if (parts.length == 3) {
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      return DateTime(year, month, day);
    }
    return DateTime.now();
  }

// الحصول على رقم اليومية لتاريخ معين
  Future<String> getJournalNumberForDate(String date) async {
    try {
      final basePath = await _getBasePath();
      final folderPath = '$basePath/SalesJournals';
      final fileName = _createFileName(date);
      final filePath = '$folderPath/$fileName';

      final file = File(filePath);
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
        return jsonMap['recordNumber'] ?? '1';
      }
      return await getNextJournalNumber();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ خطأ في الحصول على رقم اليومية للتاريخ $date: $e');
      }
      return '1';
    }
  }

  Future<List<String>> getAllAvailableDates() async {
    try {
      final basePath = await _getBasePath();
      final folderPath = '$basePath/SalesJournals';
      final folder = Directory(folderPath);
      if (!await folder.exists()) return [];
      final files = await folder.list().toList();
      final dates = <String>[];
      for (var f in files) {
        if (f is File && f.path.endsWith('.json')) {
          try {
            final j =
                jsonDecode(await f.readAsString()) as Map<String, dynamic>;
            final date = j['date']?.toString() ?? '';
            if (date.isNotEmpty) dates.add(date);
          } catch (_) {}
        }
      }
      return dates;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ خطأ في جلب تواريخ المبيعات: $e');
      return [];
    }
  }

  Future<SalesDocument?> loadDocumentForDate(String date) async {
    try {
      final basePath = await _getBasePath();
      final folderPath = '$basePath/SalesJournals';
      final fileName = _createFileName(date);
      final filePath = '$folderPath/$fileName';

      final file = File(filePath);
      if (!await file.exists()) return null;

      final jsonString = await file.readAsString();
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      return SalesDocument.fromJson(jsonMap);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ خطأ في قراءة يومية المبيعات: $e');
      return null;
    }
  }
}
