class AppConfig {
  final int papersStock;
  final double pricePerPaper;
  final double buyingPricePerPaper;
  final double inkPricePerPaper;
  final double serviceFeePerPaper;
  final double paidOutToUser;
  final DateTime updatedAt;

  const AppConfig({
    this.papersStock = 500,
    this.pricePerPaper = 150.0,
    this.buyingPricePerPaper = 35.0,
    this.inkPricePerPaper = 25.0,
    this.serviceFeePerPaper = 10.0,
    this.paidOutToUser = 0.0,
    required this.updatedAt,
  });

  /// Total expense per paper = buying price + ink price + service fee
  double get totalExpensePerPaper =>
      buyingPricePerPaper + inkPricePerPaper + serviceFeePerPaper;

  /// Net profit per paper = price per paper - total expenses
  double get netProfitPerPaper => pricePerPaper - totalExpensePerPaper;

  Map<String, dynamic> toMap() {
    return {
      'papersStock': papersStock,
      'pricePerPaper': pricePerPaper,
      'buyingPricePerPaper': buyingPricePerPaper,
      'inkPricePerPaper': inkPricePerPaper,
      'serviceFeePerPaper': serviceFeePerPaper,
      'paidOutToUser': paidOutToUser,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory AppConfig.fromMap(Map<String, dynamic> map) {
    return AppConfig(
      papersStock: (map['papersStock'] as num?)?.toInt() ?? 500,
      pricePerPaper: (map['pricePerPaper'] as num?)?.toDouble() ?? 150.0,
      buyingPricePerPaper: (map['buyingPricePerPaper'] as num?)?.toDouble() ?? 35.0,
      inkPricePerPaper: (map['inkPricePerPaper'] as num?)?.toDouble() ?? 25.0,
      serviceFeePerPaper: (map['serviceFeePerPaper'] as num?)?.toDouble() ?? 10.0,
      paidOutToUser: (map['paidOutToUser'] as num?)?.toDouble() ?? 0.0,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  AppConfig copyWith({
    int? papersStock,
    double? pricePerPaper,
    double? buyingPricePerPaper,
    double? inkPricePerPaper,
    double? serviceFeePerPaper,
    double? paidOutToUser,
    DateTime? updatedAt,
  }) {
    return AppConfig(
      papersStock: papersStock ?? this.papersStock,
      pricePerPaper: pricePerPaper ?? this.pricePerPaper,
      buyingPricePerPaper: buyingPricePerPaper ?? this.buyingPricePerPaper,
      inkPricePerPaper: inkPricePerPaper ?? this.inkPricePerPaper,
      serviceFeePerPaper: serviceFeePerPaper ?? this.serviceFeePerPaper,
      paidOutToUser: paidOutToUser ?? this.paidOutToUser,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
