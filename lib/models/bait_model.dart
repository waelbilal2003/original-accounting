class BaitData {
  final String materialName;
  double purchasesCount;
  double salesCount;

  BaitData({
    required this.materialName,
    this.purchasesCount = 0.0,
    this.salesCount = 0.0,
  });

  // دالة لحساب البايت تلقائياً
  double get baitValue {
    return purchasesCount - salesCount;
  }
}
