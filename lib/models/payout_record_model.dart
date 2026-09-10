class PayoutRecord {
  final int? id;
  final double amount;
  final String? note;
  final DateTime timestamp;
  final String? recordedBy; // admin email who recorded the payout
  final double totalProfitAtTime; // total net profit at the moment of payout
  final double cumulativePaidAtTime; // running total paid out up to and including this payout
  final double balanceAfterPayout; // remaining balance after this payout
  final bool isSynced;

  PayoutRecord({
    this.id,
    required this.amount,
    this.note,
    required this.timestamp,
    this.recordedBy,
    required this.totalProfitAtTime,
    required this.cumulativePaidAtTime,
    required this.balanceAfterPayout,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'note': note,
      'timestamp': timestamp.toIso8601String(),
      'recordedBy': recordedBy,
      'totalProfitAtTime': totalProfitAtTime,
      'cumulativePaidAtTime': cumulativePaidAtTime,
      'balanceAfterPayout': balanceAfterPayout,
      'isSynced': isSynced ? 1 : 0,
    };
  }

  factory PayoutRecord.fromMap(Map<String, dynamic> map) {
    return PayoutRecord(
      id: map['id'] as int?,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      note: map['note'] as String?,
      timestamp: DateTime.parse(map['timestamp'].toString()),
      recordedBy: map['recordedBy'] as String?,
      totalProfitAtTime: (map['totalProfitAtTime'] as num?)?.toDouble() ?? 0.0,
      cumulativePaidAtTime: (map['cumulativePaidAtTime'] as num?)?.toDouble() ?? 0.0,
      balanceAfterPayout: (map['balanceAfterPayout'] as num?)?.toDouble() ?? 0.0,
      isSynced: map['isSynced'] == 1 || map['isSynced'] == true,
    );
  }

  PayoutRecord copyWith({
    int? id,
    double? amount,
    String? note,
    DateTime? timestamp,
    String? recordedBy,
    double? totalProfitAtTime,
    double? cumulativePaidAtTime,
    double? balanceAfterPayout,
    bool? isSynced,
  }) {
    return PayoutRecord(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      timestamp: timestamp ?? this.timestamp,
      recordedBy: recordedBy ?? this.recordedBy,
      totalProfitAtTime: totalProfitAtTime ?? this.totalProfitAtTime,
      cumulativePaidAtTime: cumulativePaidAtTime ?? this.cumulativePaidAtTime,
      balanceAfterPayout: balanceAfterPayout ?? this.balanceAfterPayout,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
