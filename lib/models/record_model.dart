class PrintingRecord {
  final int? id;
  /// The Firestore document ID — globally unique across all devices.
  /// Used as the single source of truth for cross-device deduplication.
  final String? firestoreId;
  final String customerName;
  final String jobDescription;
  final int quantity;
  final int copies;
  final int pages;
  final double pricePerUnit;
  final double totalAmount;
  final double paidAmount;
  final double balance;
  final String paymentMode;
  final DateTime timestamp;
  final bool isSynced;
  final String? createdBy;
  /// Client-written UTC edit time. Compared against the cloud copy so an
  /// offline device cannot silently overwrite a newer edit made elsewhere.
  /// This is deliberately not the Firestore `syncedAt` server timestamp,
  /// because that value is not readable from the local SQLite side.
  final DateTime updatedAt;

  PrintingRecord({
    this.id,
    this.firestoreId,
    required this.customerName,
    required this.jobDescription,
    required this.quantity,
    this.copies = 1,
    this.pages = 1,
    required this.pricePerUnit,
    required this.totalAmount,
    required this.paidAmount,
    required this.balance,
    this.paymentMode = 'Cash',
    required this.timestamp,
    this.isSynced = false,
    this.createdBy,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? timestamp;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firestoreId': firestoreId,
      'customerName': customerName,
      'jobDescription': jobDescription,
      'quantity': quantity,
      'copies': copies,
      'pages': pages,
      'pricePerUnit': pricePerUnit,
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'balance': balance,
      'paymentMode': paymentMode,
      'timestamp': timestamp.toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'isSynced': isSynced ? 1 : 0,
      'createdBy': createdBy,
    };
  }

  factory PrintingRecord.fromMap(Map<String, dynamic> map) {
    return PrintingRecord(
      id: map['id'],
      firestoreId: map['firestoreId'],
      customerName: map['customerName'] ?? 'Walk-in Customer',
      jobDescription: map['jobDescription'] ?? '',
      quantity: map['quantity'] ?? 1,
      copies: map['copies'] ?? (map['quantity'] ?? 1),
      pages: map['pages'] ?? 1,
      pricePerUnit: (map['pricePerUnit'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (map['paidAmount'] as num?)?.toDouble() ?? 0.0,
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      paymentMode: map['paymentMode'] ?? 'Cash',
      timestamp: DateTime.parse(map['timestamp']),
      isSynced: (map['isSynced'] is int ? map['isSynced'] == 1 : map['isSynced'] == true),
      createdBy: map['createdBy'],
      // Legacy rows have no updatedAt; fall back to the creation timestamp so
      // they sort sensibly instead of defaulting to the epoch.
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.parse(map['timestamp']),
    );
  }

  PrintingRecord copyWith({
    int? id,
    String? firestoreId,
    String? customerName,
    String? jobDescription,
    int? quantity,
    int? copies,
    int? pages,
    double? pricePerUnit,
    double? totalAmount,
    double? paidAmount,
    double? balance,
    String? paymentMode,
    DateTime? timestamp,
    bool? isSynced,
    String? createdBy,
    DateTime? updatedAt,
  }) {
    return PrintingRecord(
      id: id ?? this.id,
      firestoreId: firestoreId ?? this.firestoreId,
      customerName: customerName ?? this.customerName,
      jobDescription: jobDescription ?? this.jobDescription,
      quantity: quantity ?? this.quantity,
      copies: copies ?? this.copies,
      pages: pages ?? this.pages,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      balance: balance ?? this.balance,
      paymentMode: paymentMode ?? this.paymentMode,
      timestamp: timestamp ?? this.timestamp,
      isSynced: isSynced ?? this.isSynced,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
