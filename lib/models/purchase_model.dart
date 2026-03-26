class Purchase {
  final String material;
  final String affiliation; // المورد
  final String count;
  final String packaging;
  final String standing;
  final String net;
  final String price;
  final String total;
  final String cashOrDebt;
  final String sellerName;

  Purchase({
    required this.material,
    required this.affiliation,
    required this.count,
    required this.packaging,
    required this.standing,
    required this.net,
    required this.price,
    required this.total,
    required this.cashOrDebt,
    required this.sellerName,
  });

  Purchase copyWith({
    String? material,
    String? affiliation,
    String? count,
    String? packaging,
    String? standing,
    String? net,
    String? price,
    String? total,
    String? cashOrDebt,
    String? sellerName,
  }) {
    return Purchase(
      material: material ?? this.material,
      affiliation: affiliation ?? this.affiliation,
      count: count ?? this.count,
      packaging: packaging ?? this.packaging,
      standing: standing ?? this.standing,
      net: net ?? this.net,
      price: price ?? this.price,
      total: total ?? this.total,
      cashOrDebt: cashOrDebt ?? this.cashOrDebt,
      sellerName: sellerName ?? this.sellerName,
    );
  }

  factory Purchase.fromJson(Map<String, dynamic> json) {
    return Purchase(
      material: json['material'] ?? '',
      affiliation: json['affiliation'] ?? '',
      count: json['count'] ?? '',
      packaging: json['packaging'] ?? '',
      standing: json['standing'] ?? '',
      net: json['net'] ?? '',
      price: json['price'] ?? '',
      total: json['total'] ?? '',
      cashOrDebt: json['cashOrDebt'] ?? '',
      sellerName: json['sellerName'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'material': material,
      'affiliation': affiliation,
      'count': count,
      'packaging': packaging,
      'standing': standing,
      'net': net,
      'price': price,
      'total': total,
      'cashOrDebt': cashOrDebt,
      'sellerName': sellerName,
    };
  }
}

class PurchaseDocument {
  final String recordNumber;
  final String date;
  final String sellerName;
  final String storeName;
  final String dayName;
  final List<Purchase> purchases;
  final Map<String, String> totals;

  PurchaseDocument({
    required this.recordNumber,
    required this.date,
    required this.sellerName,
    required this.storeName,
    required this.dayName,
    required this.purchases,
    required this.totals,
  });

  factory PurchaseDocument.fromJson(Map<String, dynamic> json) {
    return PurchaseDocument(
      recordNumber: json['recordNumber'] ?? '',
      date: json['date'] ?? '',
      sellerName: json['sellerName'] ?? '',
      storeName: json['storeName'] ?? '',
      dayName: json['dayName'] ?? '',
      purchases: (json['purchases'] as List<dynamic>?)
              ?.map((item) => Purchase.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      totals: Map<String, String>.from(json['totals'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'recordNumber': recordNumber,
      'date': date,
      'sellerName': sellerName,
      'storeName': storeName,
      'dayName': dayName,
      'purchases': purchases.map((p) => p.toJson()).toList(),
      'totals': totals,
    };
  }
}
