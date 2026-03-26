class Receipt {
  final String serialNumber;
  final String material;
  final String affiliation;
  final String sValue;
  final String count;
  final String packaging;
  final String standing;
  final String payment;
  final String load;
  final String sellerName;

  Receipt({
    required this.serialNumber,
    required this.material,
    required this.affiliation,
    required this.sValue,
    required this.count,
    required this.packaging,
    required this.standing,
    required this.payment,
    required this.load,
    required this.sellerName,
  });

  // *** إضافة دالة copyWith هنا ***
  Receipt copyWith({
    String? serialNumber,
    String? material,
    String? affiliation,
    String? sValue,
    String? count,
    String? packaging,
    String? standing,
    String? payment,
    String? load,
    String? sellerName,
  }) {
    return Receipt(
      serialNumber: serialNumber ?? this.serialNumber,
      material: material ?? this.material,
      affiliation: affiliation ?? this.affiliation,
      sValue: sValue ?? this.sValue,
      count: count ?? this.count,
      packaging: packaging ?? this.packaging,
      standing: standing ?? this.standing,
      payment: payment ?? this.payment,
      load: load ?? this.load,
      sellerName: sellerName ?? this.sellerName,
    );
  }

  factory Receipt.fromJson(Map<String, dynamic> json) {
    return Receipt(
      serialNumber: json['serialNumber'] ?? '',
      material: json['material'] ?? '',
      affiliation: json['affiliation'] ?? '',
      sValue: json['sValue'] ?? '',
      count: json['count'] ?? '',
      packaging: json['packaging'] ?? '',
      standing: json['standing'] ?? '',
      payment: json['payment'] ?? '',
      load: json['load'] ?? '',
      sellerName: json['sellerName'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'serialNumber': serialNumber,
      'material': material,
      'affiliation': affiliation,
      'sValue': sValue,
      'count': count,
      'packaging': packaging,
      'standing': standing,
      'payment': payment,
      'load': load,
      'sellerName': sellerName,
    };
  }
}

class ReceiptDocument {
  final String recordNumber;
  final String date;
  final String sellerName;
  final String storeName;
  final String dayName;
  final List<Receipt> receipts;
  final Map<String, String> totals;

  ReceiptDocument({
    required this.recordNumber,
    required this.date,
    required this.sellerName,
    required this.storeName,
    required this.dayName,
    required this.receipts,
    required this.totals,
  });

  factory ReceiptDocument.fromJson(Map<String, dynamic> json) {
    return ReceiptDocument(
      recordNumber: json['recordNumber'] ?? '',
      date: json['date'] ?? '',
      sellerName: json['sellerName'] ?? '',
      storeName: json['storeName'] ?? '',
      dayName: json['dayName'] ?? '',
      receipts: (json['receipts'] as List<dynamic>?)
              ?.map((item) => Receipt.fromJson(item as Map<String, dynamic>))
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
      'receipts': receipts.map((r) => r.toJson()).toList(),
      'totals': totals,
    };
  }
}
