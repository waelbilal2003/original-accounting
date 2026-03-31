import '../models/bait_model.dart';
import 'purchase_storage_service.dart';
import 'sales_storage_service.dart';

class BaitService {
  final PurchaseStorageService _purchaseService = PurchaseStorageService();
  final SalesStorageService _salesService = SalesStorageService();

  Future<List<BaitData>> getBaitDataForDate(String date) async {
    final Map<String, BaitData> materialSummary = {};

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

    final result = materialSummary.values.toList();
    result.sort((a, b) => a.materialName.compareTo(b.materialName));
    return result;
  }

  Future<List<BaitData>> getBaitDataForDateRange(
      DateTime fromDate, DateTime toDate) async {
    final Map<String, BaitData> aggregated = {};

    int daysDiff = toDate.difference(fromDate).inDays;
    for (int i = 0; i <= daysDiff; i++) {
      final currentDate = fromDate.add(Duration(days: i));
      final dateString =
          '${currentDate.year}/${currentDate.month}/${currentDate.day}';
      final dailyData = await getBaitDataForDate(dateString);
      for (var item in dailyData) {
        aggregated.putIfAbsent(
            item.materialName, () => BaitData(materialName: item.materialName));
        aggregated[item.materialName]!.purchasesCount += item.purchasesCount;
        aggregated[item.materialName]!.salesCount += item.salesCount;
      }
    }

    final result = aggregated.values.toList();
    result.sort((a, b) => a.materialName.compareTo(b.materialName));
    return result;
  }
}
