import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/record_model.dart';
import '../models/app_config_model.dart';
import '../models/payout_record_model.dart';
import 'database_helper.dart';

class SyncService with ChangeNotifier {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  FirebaseFirestore? _firestore;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  StreamSubscription<QuerySnapshot>? _recordsSubscription;
  StreamSubscription<DocumentSnapshot>? _configSubscription;
  StreamSubscription<QuerySnapshot>? _payoutSubscription;
  VoidCallback? _onRecordsChangedCallback;
  Function(AppConfig)? _onConfigChangedCallback;
  VoidCallback? _onPayoutsChangedCallback;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  /// Registers a callback to be notified whenever records are automatically synced in
  void registerOnRecordsChanged(VoidCallback callback) {
    _onRecordsChangedCallback = callback;
  }

  /// Starts listening for real-time updates from Cloud Firestore.
  /// Any records added or modified on other devices are automatically
  /// synced down to the local SQLite database in real time.
  void startRealtimeSync([VoidCallback? onRecordsChanged]) {
    if (onRecordsChanged != null) {
      _onRecordsChangedCallback = onRecordsChanged;
    }

    if (_recordsSubscription != null) return; // Already listening

    final firestore = _getFirestoreInstance();
    if (firestore == null) {
      debugPrint('startRealtimeSync: Firestore not ready yet.');
      return;
    }

    try {
      debugPrint('startRealtimeSync: Starting real-time Firestore listener...');
      _recordsSubscription = firestore
          .collection('printing_records')
          .snapshots()
          .listen(
        (snapshot) async {
          bool anyNewOrUpdated = false;
          final localRecords = await _dbHelper.getRecords();
          final localMap = {
            for (var r in localRecords) r.timestamp.toIso8601String(): r
          };

          for (final docChange in snapshot.docChanges) {
            final data = docChange.doc.data();
            if (data == null) continue;

            final rawTimestamp = data['timestamp'];
            if (rawTimestamp == null) continue;
            final timestampStr = rawTimestamp.toString();

            try {
              final DateTime recordTime = DateTime.parse(timestampStr);

              // Check if we already have this record locally
              final existingLocal = localMap[timestampStr];

              if (existingLocal == null) {
                // New record added on another device -> insert locally
                final newRecord = PrintingRecord(
                  customerName: data['customerName'] ?? 'Walk-in Customer',
                  jobDescription: data['jobDescription'] ?? '',
                  quantity: (data['quantity'] as num?)?.toInt() ?? 1,
                  copies: (data['copies'] as num?)?.toInt() ?? 1,
                  pages: (data['pages'] as num?)?.toInt() ?? 1,
                  pricePerUnit: (data['pricePerUnit'] as num?)?.toDouble() ?? 0.0,
                  totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
                  paidAmount: (data['paidAmount'] as num?)?.toDouble() ?? 0.0,
                  balance: (data['balance'] as num?)?.toDouble() ?? 0.0,
                  paymentMode: data['paymentMode']?.toString() ?? 'Cash',
                  timestamp: recordTime,
                  isSynced: true,
                  createdBy: data['createdBy']?.toString(),
                );
                await _dbHelper.insertRecord(newRecord);
                localMap[timestampStr] = newRecord;
                anyNewOrUpdated = true;
                debugPrint('Real-time auto-sync: Imported new record for ${newRecord.customerName}');
              } else if (docChange.type == DocumentChangeType.modified) {
                // Modified on cloud -> update local
                final updatedRecord = PrintingRecord(
                  id: existingLocal.id,
                  customerName: data['customerName'] ?? existingLocal.customerName,
                  jobDescription: data['jobDescription'] ?? existingLocal.jobDescription,
                  quantity: (data['quantity'] as num?)?.toInt() ?? existingLocal.quantity,
                  copies: (data['copies'] as num?)?.toInt() ?? existingLocal.copies,
                  pages: (data['pages'] as num?)?.toInt() ?? existingLocal.pages,
                  pricePerUnit: (data['pricePerUnit'] as num?)?.toDouble() ?? existingLocal.pricePerUnit,
                  totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? existingLocal.totalAmount,
                  paidAmount: (data['paidAmount'] as num?)?.toDouble() ?? existingLocal.paidAmount,
                  balance: (data['balance'] as num?)?.toDouble() ?? existingLocal.balance,
                  paymentMode: data['paymentMode']?.toString() ?? existingLocal.paymentMode,
                  timestamp: recordTime,
                  isSynced: true,
                  createdBy: data['createdBy']?.toString() ?? existingLocal.createdBy,
                );
                await _dbHelper.updateRecord(updatedRecord);
                anyNewOrUpdated = true;
                debugPrint('Real-time auto-sync: Updated record id ${existingLocal.id}');
              }
            } catch (e) {
              debugPrint('Error parsing real-time record change: $e');
            }
          }

          if (anyNewOrUpdated) {
            _onRecordsChangedCallback?.call();
            notifyListeners();
          }
        },
        onError: (e) {
          debugPrint('Real-time sync subscription error: $e');
        },
      );
    } catch (e) {
      debugPrint('Failed to start real-time sync: $e');
    }
  }

  /// Registers a callback to be notified whenever configurations are updated
  void registerOnConfigChanged(Function(AppConfig) callback) {
    _onConfigChangedCallback = callback;
  }

  /// Starts listening to real-time configuration changes from Cloud Firestore
  void startConfigSync([Function(AppConfig)? onConfigChanged]) {
    if (onConfigChanged != null) {
      _onConfigChangedCallback = onConfigChanged;
    }

    if (_configSubscription != null) return;

    final firestore = _getFirestoreInstance();
    if (firestore == null) {
      debugPrint('startConfigSync: Firestore not ready yet.');
      return;
    }

    try {
      debugPrint('startConfigSync: Listening to app configuration from Firestore...');
      _configSubscription = firestore
          .collection('app_settings')
          .doc('general_config')
          .snapshots()
          .listen(
        (snapshot) async {
          if (!snapshot.exists || snapshot.data() == null) return;
          try {
            final cloudConfig = AppConfig.fromMap(snapshot.data()!);
            // Save to local SQLite
            await _dbHelper.saveAppConfig(cloudConfig);
            _onConfigChangedCallback?.call(cloudConfig);
            notifyListeners();
            debugPrint('App configuration synchronized from cloud: price=${cloudConfig.pricePerPaper}');
          } catch (e) {
            debugPrint('Error parsing cloud config: $e');
          }
        },
        onError: (e) {
          debugPrint('Config sync subscription error: $e');
        },
      );
    } catch (e) {
      debugPrint('Failed to start config sync: $e');
    }
  }

  /// Saves the updated configuration to Cloud Firestore and local SQLite
  Future<bool> saveConfig(AppConfig config) async {
    // 1. Save to local SQLite immediately
    await _dbHelper.saveAppConfig(config);
    _onConfigChangedCallback?.call(config);
    notifyListeners();

    // 2. Save to Cloud Firestore to propagate to all other devices
    final firestore = _getFirestoreInstance();
    if (firestore == null) return true;

    try {
      await firestore
          .collection('app_settings')
          .doc('general_config')
          .set(
            {
              ...config.toMap(),
              'syncedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
      debugPrint('Configuration saved and pushed to Firestore!');
      return true;
    } catch (e) {
      debugPrint('Error uploading config to Firestore: $e');
      return false;
    }
  }

  /// Stops real-time listener (e.g. on logout)
  void stopRealtimeSync() {
    _recordsSubscription?.cancel();
    _recordsSubscription = null;
    _configSubscription?.cancel();
    _configSubscription = null;
    _payoutSubscription?.cancel();
    _payoutSubscription = null;
    debugPrint('stopRealtimeSync: Stopped real-time Firestore listeners.');
  }

  FirebaseFirestore? _getFirestoreInstance() {
    if (_firestore != null) return _firestore;
    try {
      if (Firebase.apps.isNotEmpty) {
        _firestore = FirebaseFirestore.instance;
        return _firestore;
      }
    } catch (e) {
      debugPrint('Firestore not ready yet: $e');
    }
    return null;
  }

  /// Saves a payout record to local SQLite and syncs to Firestore.
  /// Returns the local SQLite ID of the inserted record.
  Future<int> savePayout(PayoutRecord record) async {
    // 1. Save to local SQLite
    final id = await _dbHelper.insertPayoutRecord(record);

    // 2. Push to Firestore
    final firestore = _getFirestoreInstance();
    if (firestore != null) {
      try {
        final docId = 'payout_${record.timestamp.millisecondsSinceEpoch}';
        await firestore.collection('payout_records').doc(docId).set(
          {
            ...record.toMap(),
            'isSynced': 1,
            'id': id,
            'syncedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        await _dbHelper.markPayoutSynced(id);
        debugPrint('Payout record synced to Firestore: $docId');
      } catch (e) {
        debugPrint('Error syncing payout to Firestore: $e');
      }
    }
    return id;
  }

  /// Starts listening for real-time payout record changes from Firestore.
  void startPayoutSync([VoidCallback? onPayoutsChanged]) {
    if (onPayoutsChanged != null) _onPayoutsChangedCallback = onPayoutsChanged;
    if (_payoutSubscription != null) return;

    final firestore = _getFirestoreInstance();
    if (firestore == null) {
      debugPrint('startPayoutSync: Firestore not ready.');
      return;
    }

    try {
      _payoutSubscription = firestore
          .collection('payout_records')
          .snapshots()
          .listen((snapshot) async {
        bool anyNew = false;
        final localPayouts = await _dbHelper.getPayoutRecords();
        // Build a set of existing timestamps to avoid duplicates
        final existingTimestamps =
            localPayouts.map((p) => p.timestamp.toIso8601String()).toSet();

        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data == null) continue;
            final rawTs = data['timestamp']?.toString();
            if (rawTs == null) continue;
            if (existingTimestamps.contains(rawTs)) continue;
            try {
              final payout = PayoutRecord.fromMap(data);
              await _dbHelper.insertPayoutRecord(payout);
              existingTimestamps.add(rawTs);
              anyNew = true;
              debugPrint('Real-time: imported payout of MWK ${payout.amount}');
            } catch (e) {
              debugPrint('Error importing payout from Firestore: $e');
            }
          }
        }
        if (anyNew) {
          _onPayoutsChangedCallback?.call();
          notifyListeners();
        }
      }, onError: (e) => debugPrint('Payout sync error: $e'));
    } catch (e) {
      debugPrint('Failed to start payout sync: $e');
    }
  }

  /// Syncs all unsynced or local SQLite records to Cloud Firestore
  Future<int> syncLocalRecordsToCloud() async {
    final firestore = _getFirestoreInstance();
    if (firestore == null) {
      debugPrint('Cloud Firestore not connected yet. Records remain safely saved in local database.');
      return 0;
    }

    if (_isSyncing) return 0;
    _isSyncing = true;
    notifyListeners();

    int syncedCount = 0;
    try {
      final records = await _dbHelper.getRecords();
      final unsyncedRecords = records.where((r) => !r.isSynced).toList();
      if (unsyncedRecords.isEmpty) {
        debugPrint('All records are already synced.');
        return 0;
      }

      final batch = firestore.batch();

      for (var record in unsyncedRecords) {
        final docId = 'record_${record.id ?? record.timestamp.millisecondsSinceEpoch}';
        final docRef = firestore.collection('printing_records').doc(docId);

        batch.set(
          docRef,
          {
            ...record.toMap(),
            'isSynced': 1,
            'syncedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();

      // Mark records as synced in local SQLite
      for (var record in unsyncedRecords) {
        await _dbHelper.updateRecord(record.copyWith(isSynced: true));
        syncedCount++;
      }
      debugPrint('Successfully synced $syncedCount records to Firestore!');
    } catch (e) {
      debugPrint('Firestore sync error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
    return syncedCount;
  }

  /// Syncs an individual newly created record to Firestore and marks local SQLite
  Future<bool> syncSingleRecord(PrintingRecord record) async {
    final firestore = _getFirestoreInstance();
    if (firestore == null) return false;

    try {
      final docId = 'record_${record.id ?? record.timestamp.millisecondsSinceEpoch}';
      await firestore.collection('printing_records').doc(docId).set(
        {
          ...record.toMap(),
          'isSynced': 1,
          'syncedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      if (record.id != null) {
        await _dbHelper.updateRecord(record.copyWith(isSynced: true));
      }
      debugPrint('Single record synced to Firestore: $docId');
      return true;
    } catch (e) {
      debugPrint('Error syncing single record to Firestore: $e');
      return false;
    }
  }

  /// Pulls all records from Firestore and saves any that don't exist locally.
  /// Used on login to sync in records created on other devices.
  /// Returns the number of new records imported.
  Future<int> syncFromCloud() async {
    final firestore = _getFirestoreInstance();
    if (firestore == null) {
      debugPrint('syncFromCloud: Firestore not ready.');
      return 0;
    }

    if (_isSyncing) return 0;
    _isSyncing = true;
    notifyListeners();

    int importedCount = 0;
    try {
      // 1. Load all existing local records to build a deduplication set
      final localRecords = await _dbHelper.getRecords();
      // Use timestamp string as a unique key for deduplication
      final localTimestamps = localRecords
          .map((r) => r.timestamp.toIso8601String())
          .toSet();

      // 2. Fetch all records from Firestore
      final snapshot = await firestore.collection('printing_records').get();
      debugPrint('syncFromCloud: found ${snapshot.docs.length} records on Firestore.');

      for (final doc in snapshot.docs) {
        final data = doc.data();
        try {
          // Parse the timestamp from the document
          final rawTimestamp = data['timestamp'];
          if (rawTimestamp == null) continue;
          final timestampStr = rawTimestamp.toString();

          // Skip if this timestamp already exists locally (record already there)
          if (localTimestamps.contains(timestampStr)) continue;

          // Build the local record (isSynced=true since it came from cloud)
          final record = PrintingRecord(
            customerName: data['customerName'] ?? 'Walk-in Customer',
            jobDescription: data['jobDescription'] ?? '',
            quantity: (data['quantity'] as num?)?.toInt() ?? 1,
            copies: (data['copies'] as num?)?.toInt() ?? 1,
            pages: (data['pages'] as num?)?.toInt() ?? 1,
            pricePerUnit: (data['pricePerUnit'] as num?)?.toDouble() ?? 0.0,
            totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
            paidAmount: (data['paidAmount'] as num?)?.toDouble() ?? 0.0,
            balance: (data['balance'] as num?)?.toDouble() ?? 0.0,
            paymentMode: data['paymentMode']?.toString() ?? 'Cash',
            timestamp: DateTime.parse(timestampStr),
            isSynced: true,
            createdBy: data['createdBy']?.toString(),
          );

          await _dbHelper.insertRecord(record);
          localTimestamps.add(timestampStr); // prevent duplicate inserts within same batch
          importedCount++;
        } catch (e) {
          debugPrint('syncFromCloud: error importing doc ${doc.id}: $e');
        }
      }

      debugPrint('syncFromCloud: imported $importedCount new records from Firestore.');
    } catch (e) {
      debugPrint('syncFromCloud error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
    return importedCount;
  }
}
