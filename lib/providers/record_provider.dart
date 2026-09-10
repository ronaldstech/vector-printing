import 'package:flutter/material.dart';
import '../models/record_model.dart';
import '../models/app_config_model.dart';
import '../models/payout_record_model.dart';
import '../services/database_helper.dart';
import '../services/sync_service.dart';

class RecordProvider with ChangeNotifier {
  List<PrintingRecord> _records = [];
  List<PayoutRecord> _payoutRecords = [];
  AppConfig _config = AppConfig(updatedAt: DateTime.now());
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SyncService _syncService = SyncService();

  List<PrintingRecord> get records => _records;
  List<PayoutRecord> get payoutRecords => _payoutRecords;
  AppConfig get config => _config;

  RecordProvider() {
    // 1. Automatically start listening for any records synced/added by other devices
    _syncService.startRealtimeSync(() {
      fetchRecords();
    });

    // 2. Load local config and listen to real-time configuration changes from Cloud
    _loadConfig();
    _syncService.startConfigSync((updatedConfig) {
      _config = updatedConfig;
      notifyListeners();
    });

    // 3. Load payout records and listen for real-time payout updates
    fetchPayoutRecords();
    _syncService.startPayoutSync(() {
      fetchPayoutRecords();
    });
  }

  Future<void> _loadConfig() async {
    final localConfig = await _dbHelper.getAppConfig();
    if (localConfig != null) {
      _config = localConfig;
      notifyListeners();
    }
  }

  Future<void> updateConfig(AppConfig newConfig) async {
    _config = newConfig;
    notifyListeners();
    await _syncService.saveConfig(newConfig);
  }

  Future<void> fetchPayoutRecords() async {
    _payoutRecords = await _dbHelper.getPayoutRecords();
    notifyListeners();
  }

  Future<void> fetchRecords() async {
    _records = await _dbHelper.getRecords();
    notifyListeners();
  }

  Future<void> addRecord(PrintingRecord record) async {
    // 1. Save to local database first (isSynced=false by default)
    final id = await _dbHelper.insertRecord(record);
    final savedRecord = record.copyWith(id: id, isSynced: false);

    // 2. Auto-decrement the paper stock by pages used in this print job
    final newStock = (_config.papersStock - record.quantity).clamp(0, 9999999);
    final updatedConfig = _config.copyWith(
      papersStock: newStock,
      updatedAt: DateTime.now(),
    );
    await updateConfig(updatedConfig); // persists locally + syncs to Firestore

    await fetchRecords();

    // 3. Sync to Cloud Firestore in background, then refresh to show synced status
    _syncService.syncSingleRecord(savedRecord).then((_) => fetchRecords());
  }

  Future<void> updateRecord(PrintingRecord record) async {
    // 1. Update local database first, mark as unsynced until confirmed
    await _dbHelper.updateRecord(record.copyWith(isSynced: false));
    await fetchRecords();

    // 2. Sync updated record to Firestore, then refresh
    _syncService.syncSingleRecord(record).then((_) => fetchRecords());
  }

  Future<void> deleteRecord(int id) async {
    await _dbHelper.deleteRecord(id);
    await fetchRecords();
  }

  double get totalSales {
    return _records.fold(0, (sum, item) => sum + item.totalAmount);
  }

  double get totalPaid {
    return _records.fold(0, (sum, item) => sum + item.paidAmount);
  }

  double get totalBalance {
    return _records.fold(0, (sum, item) => sum + item.balance);
  }

  // Papers stock tracker: config.papersStock IS the current remaining stock (set by admin).
  // It decrements automatically each time a print job is added.
  int get paperStock => _config.papersStock;

  // Total pages printed across all records (informational only)
  int get totalPagesPrinted {
    return _records.fold(0, (sum, item) => sum + item.quantity);
  }

  // Papers remaining = current stock as stored in config (admin manages this directly)
  int get papersRemaining => _config.papersStock < 0 ? 0 : _config.papersStock;

  // Today filters
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  List<PrintingRecord> get todayRecords {
    return _records.where((r) => _isToday(r.timestamp)).toList();
  }

  double get totalToday {
    return todayRecords.fold(0, (sum, item) => sum + item.totalAmount);
  }

  // Net Profit today = total sheets printed today * net profit per paper
  double get profitToday {
    final netPerPaper = _config.netProfitPerPaper;
    return todayRecords.fold(0.0, (sum, item) {
      return sum + (item.quantity * netPerPaper);
    });
  }

  // Total Net Profit across all records
  double get totalNetProfit {
    final netPerPaper = _config.netProfitPerPaper;
    return _records.fold(0.0, (sum, item) {
      return sum + (item.quantity * netPerPaper);
    });
  }

  // User profit share ratio (50% of total net profit)
  double get myProfitShareRatio => 0.50;

  // 50% of total profit earned across all records
  double get totalUserProfitShare => totalNetProfit * myProfitShareRatio;

  // Amount already paid out to user by admin
  double get totalPaidOutToUser => _config.paidOutToUser;

  // Balance remaining to be paid out to user
  double get userPayoutBalance {
    final balance = totalUserProfitShare - totalPaidOutToUser;
    return balance < 0 ? 0.0 : balance;
  }

  // Admin pays an amount to the user, reducing remaining balance
  Future<void> recordPayoutToUser(
    double amount, {
    String? note,
    String? recordedBy,
  }) async {
    final now = DateTime.now();
    final newPaidOut = _config.paidOutToUser + amount;
    final totalUserShare = totalUserProfitShare;
    final balanceAfter = (totalUserShare - newPaidOut).clamp(0.0, double.infinity);

    // 1. Save the detailed payout record
    final payoutEntry = PayoutRecord(
      amount: amount,
      note: note,
      timestamp: now,
      recordedBy: recordedBy,
      totalProfitAtTime: totalUserShare,
      cumulativePaidAtTime: newPaidOut,
      balanceAfterPayout: balanceAfter,
    );
    await _syncService.savePayout(payoutEntry);
    await fetchPayoutRecords();

    // 2. Update the cumulative paidOutToUser in config (kept for fast balance calc)
    final updatedConfig = _config.copyWith(
      paidOutToUser: newPaidOut,
      updatedAt: now,
    );
    await updateConfig(updatedConfig);
  }

  // Reset payout records if needed by admin
  Future<void> resetUserPayout() async {
    final updatedConfig = _config.copyWith(
      paidOutToUser: 0.0,
      updatedAt: DateTime.now(),
    );
    await updateConfig(updatedConfig);
  }

  // Pending sync records (records not yet successfully pushed to Firestore)
  int get pendingSyncRecordsCount {
    return _records.where((r) => !r.isSynced).length;
  }

  // ─── Profit Projections ────────────────────────────────────────────────────

  /// Number of unique calendar days that had at least one transaction.
  int get activeDayCount {
    final days = _records
        .map((r) =>
            DateTime(r.timestamp.year, r.timestamp.month, r.timestamp.day))
        .toSet();
    return days.isEmpty ? 1 : days.length; // avoid divide-by-zero
  }

  /// Average net profit generated per active business day.
  double get avgDailyNetProfit {
    if (_records.isEmpty) return 0.0;
    return totalNetProfit / activeDayCount;
  }

  /// Projected total net profit per day (based on historical average).
  double get expectedDailyNetProfit => avgDailyNetProfit;

  /// Projected total net profit per week (7 days × daily avg).
  double get expectedWeeklyNetProfit => avgDailyNetProfit * 7;

  /// Projected total net profit per month (30 days × daily avg).
  double get expectedMonthlyNetProfit => avgDailyNetProfit * 30;

  /// Expected USER profit per day (50% of projected daily net profit).
  double get expectedDailyUserProfit => expectedDailyNetProfit * myProfitShareRatio;

  /// Expected USER profit per week (50% of projected weekly net profit).
  double get expectedWeeklyUserProfit => expectedWeeklyNetProfit * myProfitShareRatio;

  /// Expected USER profit per month (50% of projected monthly net profit).
  double get expectedMonthlyUserProfit => expectedMonthlyNetProfit * myProfitShareRatio;
}
