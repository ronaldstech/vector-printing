import 'dart:async';
import 'dart:math';
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

  // Prevents concurrent realtime-listener inserts from racing with syncFromCloud
  bool _isImporting = false;

  /// Retries queued local changes.  A deletion made while offline would
  /// otherwise stay in SQLite forever unless the user happened to press a sync
  /// button, which left the order alive in Firestore indefinitely.
  Timer? _pendingRetryTimer;
  static const Duration _retryInterval = Duration(seconds: 30);

  /// Starts the background retry that flushes queued deletions and records.
  void startPendingSyncRetry() {
    _pendingRetryTimer?.cancel();
    _pendingRetryTimer = Timer.periodic(_retryInterval, (_) async {
      // Nothing queued means there is no reason to keep talking to Firestore.
      if (await _dbHelper.countPendingSyncs() == 0) return;
      if (_isSyncing || _isImporting) return;
      debugPrint('Retrying pending sync...');
      await syncLocalRecordsToCloud();
    });
  }

  void stopPendingSyncRetry() {
    _pendingRetryTimer?.cancel();
    _pendingRetryTimer = null;
  }

  /// Called when the app returns to the foreground.  Anything queued while the
  /// app was suspended is flushed immediately instead of waiting a full tick.
  Future<void> flushPendingSync() async {
    if (await _dbHelper.countPendingSyncs() == 0) return;
    if (_isSyncing || _isImporting) return;
    await syncLocalRecordsToCloud();
  }

  /// An order must have the same ID on every device, including when created
  /// offline.  Local SQLite ids are only unique on one phone.
  String createRecordId() {
    final randomPart = Random.secure().nextInt(0x7fffffff).toRadixString(36);
    return 'record_${DateTime.now().microsecondsSinceEpoch}_$randomPart';
  }

  bool _isDeleted(Map<String, dynamic> data) => data['isDeleted'] == true;

  /// Reads the `updatedAt` edit marker out of a Firestore document.  The field
  /// may be a server Timestamp, an ISO string, or missing entirely on records
  /// written by older builds, so all three cases are tolerated.
  DateTime? _cloudUpdatedAt(Map<String, dynamic> data) {
    final raw = data['updatedAt'];
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    try {
      return DateTime.parse(raw.toString());
    } catch (_) {
      return null;
    }
  }

  Future<void> _applyCloudDeletion(String firestoreId) async {
    await _dbHelper.markRecordDeleted(firestoreId, isSynced: true);
    await _dbHelper.deleteRecordByFirestoreId(firestoreId);
  }

  /// Applies one cloud document to local SQLite, inserting it when unknown and
  /// updating it only when the cloud copy is genuinely newer.  Returns true if
  /// the local database actually changed.
  ///
  /// The guard matters when this device has unsaved edits: a cloud snapshot
  /// arriving mid-edit must not overwrite them, and the pending edit is what
  /// will win on the next push.
  Future<bool> _applyCloudRecord(
      String firestoreId, Map<String, dynamic> data) async {
    if (_isDeleted(data)) {
      await _applyCloudDeletion(firestoreId);
      return true;
    }
    if (await _dbHelper.isRecordDeleted(firestoreId)) return false;

    final rawTimestamp = data['timestamp'];
    if (rawTimestamp == null) return false;

    try {
      final recordTime = DateTime.parse(rawTimestamp.toString());
      final cloudUpdatedAt =
          _cloudUpdatedAt(data) ?? recordTime;

      final existing =
          await _dbHelper.getRecordByFirestoreId(firestoreId);

      if (existing != null) {
        // Local has pending edits that are newer than the cloud copy; keep them.
        if (!existing.isSynced && existing.updatedAt.isAfter(cloudUpdatedAt)) {
          debugPrint('Keeping newer local edits for $firestoreId');
          return false;
        }
        if (!cloudUpdatedAt.isAfter(existing.updatedAt)) return false;

        await _dbHelper.updateRecord(
          PrintingRecord(
            id: existing.id,
            firestoreId: firestoreId,
            customerName: data['customerName'] ?? existing.customerName,
            jobDescription: data['jobDescription'] ?? existing.jobDescription,
            quantity: (data['quantity'] as num?)?.toInt() ?? existing.quantity,
            copies: (data['copies'] as num?)?.toInt() ?? existing.copies,
            pages: (data['pages'] as num?)?.toInt() ?? existing.pages,
            pricePerUnit:
                (data['pricePerUnit'] as num?)?.toDouble() ?? existing.pricePerUnit,
            totalAmount:
                (data['totalAmount'] as num?)?.toDouble() ?? existing.totalAmount,
            paidAmount:
                (data['paidAmount'] as num?)?.toDouble() ?? existing.paidAmount,
            balance: (data['balance'] as num?)?.toDouble() ?? existing.balance,
            paymentMode: data['paymentMode']?.toString() ?? existing.paymentMode,
            timestamp: recordTime,
            isSynced: true,
            createdBy: data['createdBy']?.toString() ?? existing.createdBy,
            updatedAt: cloudUpdatedAt,
          ),
        );
        debugPrint('Applied cloud update for $firestoreId');
        return true;
      }

      final insertedId = await _dbHelper.insertRecord(
        PrintingRecord(
          firestoreId: firestoreId,
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
          updatedAt: cloudUpdatedAt,
        ),
      );
      if (insertedId > 0) {
        debugPrint('Imported $firestoreId from cloud');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error applying cloud record $firestoreId: $e');
      return false;
    }
  }

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
          // Skip if a bulk import is already running to avoid concurrent inserts
          if (_isImporting) return;

          bool anyNewOrUpdated = false;

          for (final docChange in snapshot.docChanges) {
            final data = docChange.doc.data();
            final docId = docChange.doc.id;

            // New versions use a soft-delete marker.  This marker is retained
            // in Firestore so a phone that was offline cannot upload its old
            // copy and recreate the order later.
            if (docChange.type == DocumentChangeType.removed ||
                data == null ||
                _isDeleted(data)) {
              await _applyCloudDeletion(docId);
              anyNewOrUpdated = true;
              continue;
            }
            if (await _dbHelper.isRecordDeleted(docId)) continue;

            // The shared applier handles insert-vs-update, tombstone checks and
            // the updatedAt comparison, so this listener cannot diverge from
            // the bulk pull path.
            if (await _applyCloudRecord(docId, data)) {
              anyNewOrUpdated = true;
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

      // Started here rather than on init so the loop only exists alongside the
      // real-time listener, and is torn down again by stopRealtimeSync.
      startPendingSyncRetry();
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
    stopPendingSyncRetry();
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
      // Deletions go first. This closes the window where an old offline copy
      // could otherwise be uploaded before the deletion marker reaches cloud.
      final pendingDeletions = await _dbHelper.getUnsyncedDeletedRecordIds();
      for (final pending in pendingDeletions) {
        if (await syncDeletedRecord(pending.firestoreId,
            onlyIfExists: pending.needsVerify)) {
          syncedCount++;
        }
      }

      final records = await _dbHelper.getRecords();
      final unsyncedRecords = records.where((r) => !r.isSynced).toList();
      if (unsyncedRecords.isEmpty) {
        debugPrint('All records and deletion markers are already synced.');
        return syncedCount;
      }

      // A transaction checks the delete marker before every upload. Batches
      // cannot make that conditional check and could resurrect an order.
      for (final record in unsyncedRecords) {
        if (await syncSingleRecord(record)) {
          syncedCount++;
        }
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

  /// Syncs an individual newly created record to Firestore and stores
  /// the Firestore doc ID back into the local SQLite record.
  Future<bool> syncSingleRecord(PrintingRecord record) async {
    final firestore = _getFirestoreInstance();
    if (firestore == null) return false;

    try {
      final docId = record.firestoreId ?? createRecordId();
      if (await _dbHelper.isRecordDeleted(docId)) return false;
      final docRef = firestore.collection('printing_records').doc(docId);

      // 0 = uploaded, 1 = remote tombstone wins, 2 = remote copy is newer.
      final outcome = await firestore.runTransaction<int>((transaction) async {
        final current = await transaction.get(docRef);
        if (current.exists && _isDeleted(current.data()!)) return 1;

        // An offline phone can hold a copy that another device has since
        // edited.  Uploading it blind would silently revert that edit, so the
        // newer cloud version is pulled instead.
        final cloudUpdatedAt = _cloudUpdatedAt(current.data() ?? const {});
        if (current.exists &&
            cloudUpdatedAt != null &&
            cloudUpdatedAt.isAfter(record.updatedAt)) {
          return 2;
        }

        transaction.set(
          docRef,
          {
            ...record.toMap(),
            'firestoreId': docId,
            'isDeleted': false,
            'isSynced': 1,
            'syncedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        return 0;
      });

      if (outcome == 1) {
        await _applyCloudDeletion(docId);
        debugPrint('Skipped stale upload for deleted record: $docId');
        return false;
      }
      if (outcome == 2) {
        debugPrint('Skipped upload: cloud copy of $docId is newer than local.');
        // Pull the winner down so this device stops disagreeing with the cloud.
        final fresh = await docRef.get();
        if (fresh.exists && !_isDeleted(fresh.data()!)) {
          await _applyCloudRecord(docId, fresh.data()!);
        }
        return false;
      }

      if (record.id != null) {
        // Write the firestoreId back to local SQLite so dedup works from now on
        await _dbHelper.updateRecord(
            record.copyWith(isSynced: true, firestoreId: docId));
      }
      debugPrint('Single record synced to Firestore: $docId');
      return true;
    } catch (e) {
      debugPrint('Error syncing single record to Firestore: $e');
      return false;
    }
  }

  /// Publishes a deletion marker. It is deliberately not a Firestore hard
  /// delete: the marker is what makes deletion win over delayed offline writes.
  ///
  /// [onlyIfExists] is set when the document name had to be reconstructed rather
  /// than read from the record, so no junk tombstone is created for a document
  /// that was never there.
  Future<bool> syncDeletedRecord(String firestoreId,
      {bool onlyIfExists = false}) async {
    final firestore = _getFirestoreInstance();
    if (firestore == null) return false;
    try {
      final docRef = firestore.collection('printing_records').doc(firestoreId);

      if (onlyIfExists) {
        final existing = await docRef.get();
        if (!existing.exists) {
          // The guessed name was wrong, so there is no cloud copy to remove.
          await _dbHelper.markDeletedRecordSynced(firestoreId);
          debugPrint('No cloud record at $firestoreId; nothing to delete.');
          return true;
        }
      }

      await firestore.runTransaction<void>((transaction) async {
        await transaction.get(docRef);
        transaction.set(docRef, {
          'firestoreId': firestoreId,
          'isDeleted': true,
          'deletedAt': FieldValue.serverTimestamp(),
          'isSynced': 1,
        }, SetOptions(merge: true));
      });
      await _dbHelper.markDeletedRecordSynced(firestoreId);
      debugPrint('Deletion synced to Firestore: $firestoreId');
      return true;
    } catch (e) {
      debugPrint('Error syncing record deletion: $e');
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

    if (_isSyncing || _isImporting) return 0;
    _isSyncing = true;
    _isImporting = true;
    notifyListeners();

    int importedCount = 0;
    try {
      // 1. Fetch all records from Firestore
      final snapshot = await firestore.collection('printing_records').get();
      debugPrint('syncFromCloud: found ${snapshot.docs.length} records on Firestore.');

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final docId = doc.id;
        try {
          // Same applier as the realtime listener, so a bulk pull and a live
          // update can never resolve a conflict differently.
          if (await _applyCloudRecord(docId, data)) importedCount++;
        } catch (e) {
          debugPrint('syncFromCloud: error importing doc $docId: $e');
        }
      }

      // Old tombstones that are already safely on the cloud are only needed to
      // outlive the longest offline window, so they can be pruned here.
      final purged = await _dbHelper.purgeSyncedTombstones();
      if (purged > 0) debugPrint('Purged $purged old tombstone(s).');

      debugPrint('syncFromCloud: imported $importedCount new records from Firestore.');
    } catch (e) {
      debugPrint('syncFromCloud error: $e');
    } finally {
      _isSyncing = false;
      _isImporting = false;
      notifyListeners();
    }
    return importedCount;
  }
}
