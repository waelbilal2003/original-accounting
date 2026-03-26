class Sale {
  final String serialNumber;
  final String material;
  final String affiliation;
  final String sValue; // حقل "س" الجديد
  final String count;
  final String packaging;
  final String standing;
  final String net;
  final String price;
  final String total;
  final String cashOrDebt;
  final String empties;
  final String? customerName; // اسم الزبون (اختياري، فقط للدين)
  final String sellerName; // إضافة اسم البائع لكل سجل (صف)

  Sale({
    required this.serialNumber,
    required this.material,
    required this.affiliation,
    required this.sValue,
    required this.count,
    required this.packaging,
    required this.standing,
    required this.net,
    required this.price,
    required this.total,
    required this.cashOrDebt,
    required this.empties,
    this.customerName,
    required this.sellerName,
  });

  // تحويل من JSON إلى كائن
  factory Sale.fromJson(Map<String, dynamic> json) {
    return Sale(
      serialNumber: json['serialNumber'] ?? '',
      material: json['material'] ?? '',
      affiliation: json['affiliation'] ?? '',
      sValue: json['sValue'] ?? '',
      count: json['count'] ?? '',
      packaging: json['packaging'] ?? '',
      standing: json['standing'] ?? '',
      net: json['net'] ?? '',
      price: json['price'] ?? '',
      total: json['total'] ?? '',
      cashOrDebt: json['cashOrDebt'] ?? '',
      empties: json['empties'] ?? '',
      customerName: json['customerName'],
      sellerName: json['sellerName'] ?? '',
    );
  }

  // تحويل من كائن إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'serialNumber': serialNumber,
      'material': material,
      'affiliation': affiliation,
      'sValue': sValue,
      'count': count,
      'packaging': packaging,
      'standing': standing,
      'net': net,
      'price': price,
      'total': total,
      'cashOrDebt': cashOrDebt,
      'empties': empties,
      'customerName': customerName,
      'sellerName': sellerName,
    };
  }
}

class SalesDocument {
  final String recordNumber;
  final String date;
  final String sellerName;
  final String storeName;
  final String dayName;
  final List<Sale> sales;
  final Map<String, String> totals;

  SalesDocument({
    required this.recordNumber,
    required this.date,
    required this.sellerName,
    required this.storeName,
    required this.dayName,
    required this.sales,
    required this.totals,
  });

  // تحويل من JSON إلى كائن
  factory SalesDocument.fromJson(Map<String, dynamic> json) {
    return SalesDocument(
      recordNumber: json['recordNumber'] ?? '',
      date: json['date'] ?? '',
      sellerName: json['sellerName'] ?? '',
      storeName: json['storeName'] ?? '',
      dayName: json['dayName'] ?? '',
      sales: (json['sales'] as List<dynamic>?)
              ?.map((item) => Sale.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      totals: Map<String, String>.from(json['totals'] ?? {}),
    );
  }

  // تحويل من كائن إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'recordNumber': recordNumber,
      'date': date,
      'sellerName': sellerName,
      'storeName': storeName,
      'dayName': dayName,
      'sales': sales.map((s) => s.toJson()).toList(),
      'totals': totals,
    };
  }
}
