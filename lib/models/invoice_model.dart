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
  });
}
