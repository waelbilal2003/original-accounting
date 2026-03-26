import 'dart:async';
import 'package:flutter/foundation.dart';
import 'supplier_index_service.dart';

class SupplierBalanceTracker {
  static final SupplierBalanceTracker _instance =
      SupplierBalanceTracker._internal();
  factory SupplierBalanceTracker() => _instance;
  SupplierBalanceTracker._internal();

  final SupplierIndexService _service = SupplierIndexService();

  /// التغييرات المؤقتة
  final Map<String, double> _pendingChanges = {};

  /// العمليات التي تم احتسابها (لمنع التكرار)
  final Set<String> _processedOperations = {};

  Timer? _debounceTimer;

  /// تسجيل تغيير (محمي ضد التكرار)
  void recordChange(
    String supplierName,
    double amount,
    String transactionType,
  ) {
    final normalizedName = _normalizeName(supplierName);

    /// بصمة فريدة للعملية
    final operationKey =
        '$normalizedName|$transactionType|${amount.toStringAsFixed(2)}';

    /// ⛔ منع التكرار نهائياً
    if (_processedOperations.contains(operationKey)) {
      if (kDebugMode) {
        print('⏭️ تجاهل عملية مكررة: $operationKey');
      }
      return;
    }

    _processedOperations.add(operationKey);

    _pendingChanges[normalizedName] = (_pendingChanges[normalizedName] ?? 0.0) +
        _calculateDelta(amount, transactionType);

    if (kDebugMode) {
      print('📊 تسجيل: $normalizedName | $transactionType | $amount');
    }

    _debounceTimer?.cancel();
    _debounceTimer =
        Timer(const Duration(milliseconds: 300), _savePendingChanges);
  }

  double _calculateDelta(double amount, String type) {
    switch (type) {
      case 'purchase_debt':
      case 'box_received':
        return amount; // علينا
      case 'box_paid':
      case 'receipt_payment':
      case 'receipt_load':
        return -amount; // لنا
      default:
        return amount;
    }
  }

  Future<void> _savePendingChanges() async {
    if (_pendingChanges.isEmpty) return;

    final changes = Map<String, double>.from(_pendingChanges);
    _pendingChanges.clear();

    for (final entry in changes.entries) {
      if (entry.value == 0) continue;

      try {
        await _service.updateSupplierBalance(entry.key, entry.value);
        if (kDebugMode) {
          print(
              '✅ تم حفظ رصيد المورد ${entry.key}: ${entry.value.toStringAsFixed(2)}');
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ خطأ حفظ ${entry.key}: $e');
        }
      }
    }
  }

  String _normalizeName(String name) {
    final n = name.trim();
    if (n.isEmpty) return n;
    return n[0].toUpperCase() + n.substring(1);
  }

  /// تنظيف كامل (عند تسجيل خروج أو إعادة تهيئة)
  void reset() {
    _pendingChanges.clear();
    _processedOperations.clear();
    _debounceTimer?.cancel();
  }

  void dispose() {
    _debounceTimer?.cancel();
    _savePendingChanges();
  }
}
