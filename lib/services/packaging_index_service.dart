import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class PackagingIndexService {
  static final PackagingIndexService _instance =
      PackagingIndexService._internal();
  factory PackagingIndexService() => _instance;
  PackagingIndexService._internal();

  static const String _fileName = 'packaging_index.json';
  Map<int, String> _packagingMap = {}; // <-- خريطة تربط الرقم بالعبوة
  bool _isInitialized = false;
  int _nextId = 1; // <-- رقم العبوة التالي للإضافة

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _loadPackagings();
      _isInitialized = true;
    }
  }

  Future<String> _getFilePath() async {
    Directory? directory;

    if (Platform.isAndroid) {
      directory = await getExternalStorageDirectory();
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    final folderPath = '${directory!.path}/PackagingIndex';
    final folder = Directory(folderPath);
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    return '$folderPath/$_fileName';
  }

  Future<void> _loadPackagings() async {
    try {
      final filePath = await _getFilePath();
      final file = File(filePath);

      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final Map<String, dynamic> jsonData = jsonDecode(jsonString);

        if (jsonData.containsKey('packagings') &&
            jsonData.containsKey('nextId')) {
          final Map<String, dynamic> packagingsJson = jsonData['packagings'];

          // تحميل الخريطة من JSON
          _packagingMap.clear();
          packagingsJson.forEach((key, value) {
            _packagingMap[int.parse(key)] = value.toString();
          });

          _nextId = jsonData['nextId'] ?? 1;

          if (kDebugMode) {
            debugPrint('✅ تم تحميل ${_packagingMap.length} عبوة من الفهرس');
            debugPrint(
                'العبوات: ${_packagingMap.entries.map((e) => '${e.key}:${e.value}').join(', ')}');
          }
        } else {
          // دعم الملفات القديمة
          _packagingMap.clear();
          if (jsonData is List) {
            // تنسيق قديم: قائمة فقط
            for (int i = 0; i < jsonData.length; i++) {
              _packagingMap[i + 1] = jsonData[i].toString();
            }
            _nextId = jsonData.length + 1;
          } else if (jsonData.containsKey('packagings')) {
            // تنسيق قديم آخر
            final List<dynamic> jsonList = jsonData['packagings'];
            for (int i = 0; i < jsonList.length; i++) {
              _packagingMap[i + 1] = jsonList[i].toString();
            }
            _nextId = jsonList.length + 1;
          }

          // حفظ بالتنسيق الجديد
          await _saveToFile();
        }
      } else {
        _packagingMap.clear();
        _nextId = 1;
        if (kDebugMode) {
          debugPrint('✅ فهرس العبوات جديد - لا توجد عبوات مخزنة');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ خطأ في تحميل فهرس العبوات: $e');
      }
      _packagingMap.clear();
      _nextId = 1;
    }
  }

  Future<void> savePackaging(String packaging) async {
    await _ensureInitialized();

    if (packaging.trim().isEmpty) return;

    final normalizedPackaging = _normalizePackaging(packaging);

    // التحقق من عدم وجود العبوة مسبقاً
    if (!_packagingMap.values
        .any((p) => p.toLowerCase() == normalizedPackaging.toLowerCase())) {
      // إضافة مع رقم ثابت جديد
      _packagingMap[_nextId] = normalizedPackaging;
      _nextId++;

      await _saveToFile();

      if (kDebugMode) {
        debugPrint(
            '✅ تم إضافة عبوة جديدة: $normalizedPackaging (رقم: ${_nextId - 1})');
      }
    }
  }

  String _normalizePackaging(String packaging) {
    String normalized = packaging.trim();
    if (normalized.isNotEmpty) {
      normalized = normalized[0].toUpperCase() + normalized.substring(1);
    }
    return normalized;
  }

  Future<List<String>> getSuggestions(String query) async {
    await _ensureInitialized();

    if (query.isEmpty) return [];

    final normalizedQuery = query.toLowerCase().trim();

    return _packagingMap.entries
        .where((entry) => entry.value.toLowerCase().contains(normalizedQuery))
        .map((entry) => entry.value)
        .toList();
  }

  Future<List<String>> getSuggestionsByFirstLetter(String letter) async {
    await _ensureInitialized();

    if (letter.isEmpty) return [];

    final normalizedLetter = letter.toLowerCase().trim();

    return _packagingMap.entries
        .where(
            (entry) => entry.value.toLowerCase().startsWith(normalizedLetter))
        .map((entry) => entry.value)
        .toList();
  }

  // دالة جديدة: الحصول على اقتراحات حسب الرقم (رقم الفهرس الثابت)
  Future<List<String>> getSuggestionsByNumber(String numberQuery) async {
    await _ensureInitialized();

    if (numberQuery.isEmpty) return [];

    try {
      final int queryNumber = int.parse(numberQuery);

      // البحث عن العبوة بهذا الرقم
      if (_packagingMap.containsKey(queryNumber)) {
        return [_packagingMap[queryNumber]!];
      } else {
        return [];
      }
    } catch (e) {
      // إذا لم يكن النص رقماً، نعيد قائمة فارغة
      return [];
    }
  }

  // دالة متعددة الاستخدامات: تبحث حسب النص أو الرقم
  Future<List<String>> getEnhancedSuggestions(String query) async {
    await _ensureInitialized();

    if (query.isEmpty) return [];

    final normalizedQuery = query.trim();

    // محاولة البحث كرقم أولاً
    if (RegExp(r'^\d+$').hasMatch(normalizedQuery)) {
      final numberResults = await getSuggestionsByNumber(normalizedQuery);
      if (numberResults.isNotEmpty) {
        return numberResults;
      }
    }

    // إذا لم تكن نتيجة البحث كرقم، نبحث كنص
    return await getSuggestions(normalizedQuery);
  }

  Future<List<String>> getAllPackagings() async {
    await _ensureInitialized();

    // ترتيب أبجدي للعرض فقط (لا يؤثر على الأرقام)
    final packagings = _packagingMap.values.toList();
    packagings.sort((a, b) => a.compareTo(b));
    return packagings;
  }

  // دالة جديدة للحصول على العبوات حسب ترتيب الإضافة (حسب الرقم)
  Future<List<String>> getAllPackagingsByInsertionOrder() async {
    await _ensureInitialized();

    // ترتيب حسب الرقم (ترتيب الإضافة)
    final sortedEntries = _packagingMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return sortedEntries.map((entry) => entry.value).toList();
  }

  // دالة جديدة للحصول على رقم العبوة الثابت
  Future<int?> getPackagingPosition(String packaging) async {
    await _ensureInitialized();

    final normalizedPackaging = _normalizePackaging(packaging);

    // البحث عن العبوة وإرجاع رقمها
    for (var entry in _packagingMap.entries) {
      if (entry.value.toLowerCase() == normalizedPackaging.toLowerCase()) {
        return entry.key;
      }
    }

    return null;
  }

  Future<void> removePackaging(String packaging) async {
    await _ensureInitialized();

    final normalizedPackaging = _normalizePackaging(packaging);

    // البحث عن الرقم الخاص بالعبوة وحذفها
    int? keyToRemove;
    for (var entry in _packagingMap.entries) {
      if (entry.value.toLowerCase() == normalizedPackaging.toLowerCase()) {
        keyToRemove = entry.key;
        break;
      }
    }

    if (keyToRemove != null) {
      _packagingMap.remove(keyToRemove);
      await _saveToFile();

      if (kDebugMode) {
        debugPrint('✅ تم حذف العبوة: $packaging (رقم: $keyToRemove)');
      }
    }
  }

  Future<void> clearAll() async {
    _packagingMap.clear();
    _nextId = 1;
    await _saveToFile();

    if (kDebugMode) {
      debugPrint('✅ تم مسح جميع العبوات من الفهرس');
    }
  }

  Future<void> _saveToFile() async {
    try {
      final filePath = await _getFilePath();
      final file = File(filePath);

      // تحويل الخريطة إلى Map<String, dynamic> للتخزين
      final Map<String, dynamic> packagingsJson = {};
      _packagingMap.forEach((key, value) {
        packagingsJson[key.toString()] = value;
      });

      // حفظ البيانات مع الأرقام الثابتة
      final Map<String, dynamic> jsonData = {
        'packagings': packagingsJson,
        'nextId': _nextId,
      };

      final jsonString = jsonEncode(jsonData);
      await file.writeAsString(jsonString);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ خطأ في حفظ فهرس العبوات: $e');
      }
    }
  }

  Future<int> getCount() async {
    await _ensureInitialized();
    return _packagingMap.length;
  }

  Future<bool> exists(String packaging) async {
    await _ensureInitialized();
    return _packagingMap.values
        .any((p) => p.toLowerCase() == packaging.toLowerCase());
  }

  // دالة جديدة: الحصول على جميع العبوات مع أرقامها
  Future<Map<int, String>> getAllPackagingsWithNumbers() async {
    await _ensureInitialized();
    return Map.from(_packagingMap);
  }
}
