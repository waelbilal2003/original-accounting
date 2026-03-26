class BaitData {
  final String materialName;
  double receiptsCount;
  double purchasesCount;
  double salesCount;

  BaitData({
    required this.materialName,
    this.receiptsCount = 0.0,
    this.purchasesCount = 0.0,
    this.salesCount = 0.0,
  });

  // دالة لحساب البايت تلقائياً
  double get baitValue {
    return (receiptsCount + purchasesCount) - salesCount;
  }
}
