import '../models/sales_model.dart';
import '../models/invoice_model.dart';
import '../models/receipt_model.dart';
import '../models/purchase_model.dart';
import 'sales_storage_service.dart';
import 'purchase_storage_service.dart';

// نموذج يحتوي على كل البيانات المطلوبة لشاشة المورد
class SupplierReportData {
  final List<InvoiceItem> sales;
  final List<Receipt> receipts;
  final List<MaterialSummary> summary;

  SupplierReportData({
    required this.sales,
    required this.receipts,
    required this.summary,
  });
}

// نموذج بيانات لملخص المواد (البايت)
class MaterialSummary {
  final String material;
  final double receiptCount;
  final double salesCount;
  final double balance;

  MaterialSummary({
    required this.material,
    required this.receiptCount,
    required this.salesCount,
    required this.balance,
  });
}

class InvoicesService {
  final SalesStorageService _salesStorageService = SalesStorageService();
  final PurchaseStorageService _purchaseStorageService =
      PurchaseStorageService();

  // 1. دالة جلب فواتير الزبائن (صحيحة)
  Future<List<InvoiceItem>> getInvoicesForCustomer(
      String date, String customerName) async {
    final SalesDocument? salesDocument =
        await _salesStorageService.loadSalesDocument(date);

    if (salesDocument == null || salesDocument.sales.isEmpty) {
      return [];
    }

    final List<InvoiceItem> customerInvoices = salesDocument.sales
        .where((sale) =>
            sale.customerName?.trim() == customerName.trim() &&
            sale.cashOrDebt == 'دين')
        .map((sale) => InvoiceItem(
              serialNumber: sale.serialNumber,
              material: sale.material,
              affiliation: sale.affiliation,
              sValue: sale.sValue,
              count: sale.count,
              packaging: sale.packaging,
              standing: sale.standing,
              net: sale.net,
              price: sale.price,
              total: sale.total,
              empties: sale.empties,
              customerName: sale.customerName,
              sellerName: sale.sellerName,
              date: date, // أضف التاريخ هنا
            ))
        .toList();

    return customerInvoices;
  }

  // 2. دالة جلب تقرير المورد الشامل (صحيحة)
  Future<SupplierReportData> getSupplierReport(
      String date, String supplierName) async {
    final cleanSupplierName = supplierName.trim();
    List<InvoiceItem> supplierSales = [];
    List<Receipt> supplierReceipts = [];
    Map<String, MaterialSummary> summaryMap = {};

    // أ) جلب المبيعات الخاصة بالمورد
    final SalesDocument? salesDocument =
        await _salesStorageService.loadSalesDocument(date);

    if (salesDocument != null) {
      for (var sale in salesDocument.sales) {
        if (sale.affiliation.trim() == cleanSupplierName) {
          supplierSales.add(InvoiceItem(
            serialNumber: sale.serialNumber,
            material: sale.material,
            affiliation: sale.affiliation,
            sValue: sale.sValue,
            count: sale.count,
            packaging: sale.packaging,
            standing: sale.standing,
            net: sale.net,
            price: sale.price,
            total: sale.total,
            empties: sale.empties,
            customerName: sale.customerName,
            sellerName: sale.sellerName,
            date: date, // أضف التاريخ هنا
          ));

          // *** بداية التعديل: استخدام اسم المادة فقط كمفتاح للتجميع ***
          final key = sale.material.trim();
          final count = double.tryParse(sale.count) ?? 0;
          summaryMap.update(
            key,
            (value) => MaterialSummary(
              material: value.material,
              receiptCount: value.receiptCount,
              salesCount: value.salesCount + count,
              balance: value.receiptCount - (value.salesCount + count),
            ),
            ifAbsent: () => MaterialSummary(
              material: key, // استخدام اسم المادة مباشرة
              receiptCount: 0,
              salesCount: count,
              balance: -count,
            ),
          );
          // *** نهاية التعديل ***
        }
      }
    }

    final summaryList = summaryMap.values.toList();
    summaryList.sort((a, b) => a.material.compareTo(b.material));

    return SupplierReportData(
      sales: supplierSales,
      receipts: supplierReceipts,
      summary: summaryList,
    );
  }

  // 3. دالة جلب مشتريات مورد معين (تم التصحيح هنا)
  Future<List<Purchase>> getPurchasesForSupplier(
      String date, String supplierName) async {
    final PurchaseDocument? purchaseDocument =
        await _purchaseStorageService.loadPurchaseDocument(date);

    if (purchaseDocument == null || purchaseDocument.purchases.isEmpty) {
      return [];
    }

    // البحث في حقل "affiliation" (العائدية) بدلاً من "supplierName" غير الموجود
    final List<Purchase> supplierPurchases = purchaseDocument.purchases
        .where((purchase) {
          final purchaseAffiliation = purchase.affiliation.trim();
          final targetSupplierName = supplierName.trim();

          // المقارنة تتم الآن مع الحقل الصحيح
          return purchaseAffiliation.toLowerCase() ==
              targetSupplierName.toLowerCase();
        })
        .map((purchase) => Purchase(
              material: purchase.material,
              affiliation: purchase.affiliation,
              count: purchase.count,
              packaging: purchase.packaging,
              standing: purchase.standing,
              net: purchase.net,
              price: purchase.price,
              total: purchase.total,
              cashOrDebt: purchase.cashOrDebt,
              sellerName: purchase.sellerName,
              date: date, // أضف التاريخ هنا
            ))
        .toList();

    return supplierPurchases;
  }
}
