import '../models/bait_model.dart';
import 'purchase_storage_service.dart';
import 'sales_storage_service.dart';

class BaitService {
  final PurchaseStorageService _purchaseService = PurchaseStorageService();
  final SalesStorageService _salesService = SalesStorageService();

  Future<List<BaitData>> getBaitDataForDate(String date) async {
    // استخدام خريطة لتجميع البيانات حسب اسم المادة لتجنب التكرار
    final Map<String, BaitData> materialSummary = {};

    // 2. تحميل وتجميع بيانات المشتريات
    final purchaseDoc = await _purchaseService.loadPurchaseDocument(date);
    if (purchaseDoc != null) {
      for (var purchase in purchaseDoc.purchases) {
        final material = purchase.material.trim();
        if (material.isNotEmpty) {
          final count = double.tryParse(purchase.count) ?? 0.0;
          materialSummary.putIfAbsent(
              material, () => BaitData(materialName: material));
          materialSummary[material]!.purchasesCount += count;
        }
      }
    }

    // 3. تحميل وتجميع بيانات المبيعات
    final salesDoc = await _salesService.loadSalesDocument(date);
    if (salesDoc != null) {
      for (var sale in salesDoc.sales) {
        final material = sale.material.trim();
        if (material.isNotEmpty) {
          final count = double.tryParse(sale.count) ?? 0.0;
          materialSummary.putIfAbsent(
              material, () => BaitData(materialName: material));
          materialSummary[material]!.salesCount += count;
        }
      }
    }

    // تحويل الخريطة إلى قائمة وترتيبها أبجدياً حسب اسم المادة
    final result = materialSummary.values.toList();
    result.sort((a, b) => a.materialName.compareTo(b.materialName));

    return result;
  }
}
