import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class MaterialIndexService {
  static final MaterialIndexService _instance =
      MaterialIndexService._internal();
  factory MaterialIndexService() => _instance;
  MaterialIndexService._internal();

  static const String _fileName = 'material_index.json';
  Map<int, String> _materialMap = {}; // <-- خريطة تربط الرقم بالمادة
  bool _isInitialized = false;
  int _nextId = 1; // <-- رقم المادة التالي للإضافة

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _loadMaterials();
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

    final folderPath = '${directory!.path}/MaterialIndex';
    final folder = Directory(folderPath);
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    return '$folderPath/$_fileName';
  }

  Future<void> _loadMaterials() async {
    try {
      final filePath = await _getFilePath();
      final file = File(filePath);

      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final Map<String, dynamic> jsonData = jsonDecode(jsonString);

        if (jsonData.containsKey('materials') &&
            jsonData.containsKey('nextId')) {
          final Map<String, dynamic> materialsJson = jsonData['materials'];

          // تحميل الخريطة من JSON
          _materialMap.clear();
          materialsJson.forEach((key, value) {
            _materialMap[int.parse(key)] = value.toString();
          });

          _nextId = jsonData['nextId'] ?? 1;

          if (kDebugMode) {
            debugPrint('✅ تم تحميل ${_materialMap.length} مادة من الفهرس');
            debugPrint(
                'المواد: ${_materialMap.entries.map((e) => '${e.key}:${e.value}').join(', ')}');
          }
        } else {
          // دعم الملفات القديمة
          _materialMap.clear();
          if (jsonData is List) {
            // تنسيق قديم: قائمة فقط
            for (int i = 0; i < jsonData.length; i++) {
              _materialMap[i + 1] = jsonData[i].toString();
            }
            _nextId = jsonData.length + 1;
          } else if (jsonData.containsKey('materials')) {
            // تنسيق قديم آخر
            final List<dynamic> jsonList = jsonData['materials'];
            for (int i = 0; i < jsonList.length; i++) {
              _materialMap[i + 1] = jsonList[i].toString();
            }
            _nextId = jsonList.length + 1;
          }

          // حفظ بالتنسيق الجديد
          await _saveToFile();
        }
      } else {
        _materialMap.clear();
        _nextId = 1;
        if (kDebugMode) {
          debugPrint('✅ فهرس المواد جديد - لا توجد مواد مخزنة');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ خطأ في تحميل فهرس المواد: $e');
      }
      _materialMap.clear();
      _nextId = 1;
    }
  }

  Future<void> saveMaterial(String material) async {
    await _ensureInitialized();

    if (material.trim().isEmpty) return;

    final normalizedMaterial = _normalizeMaterial(material);

    // التحقق من عدم وجود المادة مسبقاً
    if (!_materialMap.values
        .any((m) => m.toLowerCase() == normalizedMaterial.toLowerCase())) {
      // إضافة مع رقم ثابت جديد
      _materialMap[_nextId] = normalizedMaterial;
      _nextId++;

      await _saveToFile();

      if (kDebugMode) {
        debugPrint(
            '✅ تم إضافة مادة جديدة: $normalizedMaterial (رقم: ${_nextId - 1})');
      }
    }
  }

  String _normalizeMaterial(String material) {
    String normalized = material.trim();
    if (normalized.isNotEmpty) {
      normalized = normalized[0].toUpperCase() + normalized.substring(1);
    }
    return normalized;
  }

  Future<List<String>> getSuggestions(String query) async {
    await _ensureInitialized();

    if (query.isEmpty) return [];

    final normalizedQuery = query.toLowerCase().trim();

    return _materialMap.entries
        .where((entry) => entry.value.toLowerCase().contains(normalizedQuery))
        .map((entry) => entry.value)
        .toList();
  }

  Future<List<String>> getSuggestionsByFirstLetter(String letter) async {
    await _ensureInitialized();

    if (letter.isEmpty) return [];

    final normalizedLetter = letter.toLowerCase().trim();

    return _materialMap.entries
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

      // البحث عن المادة بهذا الرقم
      if (_materialMap.containsKey(queryNumber)) {
        return [_materialMap[queryNumber]!];
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

  Future<List<String>> getAllMaterials() async {
    await _ensureInitialized();

    // ترتيب أبجدي للعرض فقط (لا يؤثر على الأرقام)
    final materials = _materialMap.values.toList();
    materials.sort((a, b) => a.compareTo(b));
    return materials;
  }

  // دالة جديدة للحصول على المواد حسب ترتيب الإضافة (حسب الرقم)
  Future<List<String>> getAllMaterialsByInsertionOrder() async {
    await _ensureInitialized();

    // ترتيب حسب الرقم (ترتيب الإضافة)
    final sortedEntries = _materialMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return sortedEntries.map((entry) => entry.value).toList();
  }

  // دالة جديدة للحصول على رقم المادة الثابت
  Future<int?> getMaterialPosition(String material) async {
    await _ensureInitialized();

    final normalizedMaterial = _normalizeMaterial(material);

    // البحث عن المادة وإرجاع رقمها
    for (var entry in _materialMap.entries) {
      if (entry.value.toLowerCase() == normalizedMaterial.toLowerCase()) {
        return entry.key;
      }
    }

    return null;
  }

  Future<void> removeMaterial(String material) async {
    await _ensureInitialized();

    final normalizedMaterial = _normalizeMaterial(material);

    // البحث عن الرقم الخاص بالمادة وحذفها
    int? keyToRemove;
    for (var entry in _materialMap.entries) {
      if (entry.value.toLowerCase() == normalizedMaterial.toLowerCase()) {
        keyToRemove = entry.key;
        break;
      }
    }

    if (keyToRemove != null) {
      _materialMap.remove(keyToRemove);
      await _saveToFile();

      if (kDebugMode) {
        debugPrint('✅ تم حذف المادة: $material (رقم: $keyToRemove)');
      }
    }
  }

  Future<void> clearAll() async {
    _materialMap.clear();
    _nextId = 1;
    await _saveToFile();

    if (kDebugMode) {
      debugPrint('✅ تم مسح جميع المواد من الفهرس');
    }
  }

  Future<void> _saveToFile() async {
    try {
      final filePath = await _getFilePath();
      final file = File(filePath);

      // تحويل الخريطة إلى Map<String, dynamic> للتخزين
      final Map<String, dynamic> materialsJson = {};
      _materialMap.forEach((key, value) {
        materialsJson[key.toString()] = value;
      });

      // حفظ البيانات مع الأرقام الثابتة
      final Map<String, dynamic> jsonData = {
        'materials': materialsJson,
        'nextId': _nextId,
      };

      final jsonString = jsonEncode(jsonData);
      await file.writeAsString(jsonString);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ خطأ في حفظ فهرس المواد: $e');
      }
    }
  }

  Future<int> getCount() async {
    await _ensureInitialized();
    return _materialMap.length;
  }

  Future<bool> exists(String material) async {
    await _ensureInitialized();
    return _materialMap.values
        .any((m) => m.toLowerCase() == material.toLowerCase());
  }

  // دالة جديدة: الحصول على جميع المواد مع أرقامها
  Future<Map<int, String>> getAllMaterialsWithNumbers() async {
    await _ensureInitialized();
    return Map.from(_materialMap);
  }
}
