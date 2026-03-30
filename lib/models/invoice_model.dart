class InvoiceItem {
  final String serialNumber;
  final String material;
  final String affiliation;
  final String sValue;
  final String count;
  final String packaging;
  final String standing;
  final String net;
  final String price;
  final String total;
  final String empties;
  final String? customerName;
  final String sellerName;
  final String date; // أضف هذا الحقل

  InvoiceItem({
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
    required this.empties,
    this.customerName,
    required this.sellerName,
    required this.date, // أضف هذا في المُنشئ
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
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
      empties: json['empties'] ?? '',
      customerName: json['customerName'],
      sellerName: json['sellerName'] ?? '',
      date: json['date'] ?? '', // أضف هذا
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
      'net': net,
      'price': price,
      'total': total,
      'empties': empties,
      'customerName': customerName,
      'sellerName': sellerName,
      'date': date, // أضف هذا
    };
  }
}
