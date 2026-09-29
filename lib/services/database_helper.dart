import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/record_model.dart';
import '../models/app_config_model.dart';
import '../models/payout_record_model.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'printing_records.db');
    return await openDatabase(
      path,
      version: 12,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firestoreId TEXT UNIQUE,
        customerName TEXT,
        jobDescription TEXT,
        quantity INTEGER,
        copies INTEGER DEFAULT 1,
        pages INTEGER DEFAULT 1,
        pricePerUnit REAL,
        totalAmount REAL,
        paidAmount REAL,
        balance REAL,
        paymentMode TEXT DEFAULT 'Cash',
        timestamp TEXT,
        updatedAt TEXT,
        isSynced INTEGER DEFAULT 0,
        createdBy TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE app_config (
        id INTEGER PRIMARY KEY DEFAULT 1,
        papersStock INTEGER,
        pricePerPaper REAL,
        buyingPricePerPaper REAL,
        inkPricePerPaper REAL,
        serviceFeePerPaper REAL,
        paidOutToUser REAL DEFAULT 0,
        updatedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE payout_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        note TEXT,
        timestamp TEXT NOT NULL,
        recordedBy TEXT,
        totalProfitAtTime REAL DEFAULT 0,
        cumulativePaidAtTime REAL DEFAULT 0,
        balanceAfterPayout REAL DEFAULT 0,
        isSynced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS security_settings (
        id INTEGER PRIMARY KEY DEFAULT 1,
        pinHash TEXT,
        isAppLockEnabled INTEGER DEFAULT 0,
        isBiometricEnabled INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE deleted_record_ids (
        firestoreId TEXT PRIMARY KEY,
        deletedAt TEXT NOT NULL,
        isSynced INTEGER DEFAULT 0,
        needsVerify INTEGER DEFAULT 0
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute("ALTER TABLE records ADD COLUMN copies INTEGER DEFAULT 1;");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE records ADD COLUMN pages INTEGER DEFAULT 1;");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE records ADD COLUMN paymentMode TEXT DEFAULT 'Cash';");
      } catch (_) {}
    }
    if (oldVersion < 3) {
      try {
        await db.execute("ALTER TABLE records ADD COLUMN isSynced INTEGER DEFAULT 0;");
      } catch (_) {}
    }
    if (oldVersion < 4) {
      try {
        await db.execute("ALTER TABLE records ADD COLUMN createdBy TEXT;");
      } catch (_) {}
    }
    if (oldVersion < 5) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS app_config (
            id INTEGER PRIMARY KEY DEFAULT 1,
            papersStock INTEGER,
            pricePerPaper REAL,
            buyingPricePerPaper REAL,
            inkPricePerPaper REAL,
            serviceFeePerPaper REAL,
            paidOutToUser REAL DEFAULT 0,
            updatedAt TEXT
          )
        ''');
      } catch (_) {}
    }
    if (oldVersion < 6) {
      try {
        await db.execute("ALTER TABLE app_config ADD COLUMN paidOutToUser REAL DEFAULT 0;");
      } catch (_) {}
    }
    if (oldVersion < 7) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS payout_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount REAL NOT NULL,
            note TEXT,
            timestamp TEXT NOT NULL,
            recordedBy TEXT,
            totalProfitAtTime REAL DEFAULT 0,
            cumulativePaidAtTime REAL DEFAULT 0,
            balanceAfterPayout REAL DEFAULT 0,
            isSynced INTEGER DEFAULT 0
          )
        ''');
      } catch (_) {}
    }
    if (oldVersion < 8) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS security_settings (
            id INTEGER PRIMARY KEY DEFAULT 1,
            pinHash TEXT,
            isAppLockEnabled INTEGER DEFAULT 0,
            isBiometricEnabled INTEGER DEFAULT 0
          )
        ''');
      } catch (_) {}
    }
    if (oldVersion < 9) {
      try {
        await db.execute(
            "ALTER TABLE records ADD COLUMN firestoreId TEXT;");
        // Create a unique index to prevent duplicates going forward
        await db.execute(
            "CREATE UNIQUE INDEX IF NOT EXISTS idx_records_firestoreId ON records (firestoreId) WHERE firestoreId IS NOT NULL;");
      } catch (_) {}
    }
    if (oldVersion < 10) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS deleted_record_ids (
          firestoreId TEXT PRIMARY KEY,
          deletedAt TEXT NOT NULL,
          isSynced INTEGER DEFAULT 0,
          needsVerify INTEGER DEFAULT 0
        )
      ''');
    }
    if (oldVersion < 11) {
      try {
        await db.execute("ALTER TABLE records ADD COLUMN updatedAt TEXT;");
        // Seed existing rows from their creation timestamp so a legacy record
        // does not look infinitely stale and get overwritten by any device.
        await db.execute(
          "UPDATE records SET updatedAt = timestamp WHERE updatedAt IS NULL;");
      } catch (_) {}
    }
    if (oldVersion < 12) {
      try {
        await db.execute(
            "ALTER TABLE deleted_record_ids ADD COLUMN needsVerify INTEGER DEFAULT 0;");
      } catch (_) {}
    }
  }

  Future<Map<String, dynamic>?> getSecuritySettings() async {
      Database db = await database;
      await db.execute('''
        CREATE TABLE IF NOT EXISTS security_settings (
          id INTEGER PRIMARY KEY DEFAULT 1,
          pinHash TEXT,
          isAppLockEnabled INTEGER DEFAULT 0,
          isBiometricEnabled INTEGER DEFAULT 0
        )
      ''');
      final maps = await db.query('security_settings', where: 'id = ?', whereArgs: [1], limit: 1);
      if (maps.isNotEmpty) return maps.first;
      return null;
    }

    Future<void> saveSecuritySettings({
      String? pinHash,
      bool? isAppLockEnabled,
      bool? isBiometricEnabled,
    }) async {
      Database db = await database;
      final existing = await getSecuritySettings();
      final values = <String, dynamic>{
        'id': 1,
        'pinHash': pinHash ?? existing?['pinHash'],
        'isAppLockEnabled': isAppLockEnabled != null
            ? (isAppLockEnabled ? 1 : 0)
            : (existing?['isAppLockEnabled'] ?? 0),
        'isBiometricEnabled': isBiometricEnabled != null
            ? (isBiometricEnabled ? 1 : 0)
            : (existing?['isBiometricEnabled'] ?? 0),
      };
      await db.insert('security_settings', values, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    Future<void> clearSecuritySettings() async {
      Database db = await database;
      await db.delete('security_settings', where: 'id = ?', whereArgs: [1]);
    }

  Future<void> saveAppConfig(AppConfig config) async {
    Database db = await database;
    await db.insert(
      'app_config',
      {
        'id': 1,
        ...config.toMap(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<AppConfig?> getAppConfig() async {
    Database db = await database;
    final maps = await db.query(
      'app_config',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return AppConfig.fromMap(maps.first);
    }
    return null;
  }

  Future<int> insertPayoutRecord(PayoutRecord record) async {
    Database db = await database;
    final map = {...record.toMap()};
    map.remove('id'); // let autoincrement assign id
    return await db.insert('payout_records', map);
  }

  Future<List<PayoutRecord>> getPayoutRecords() async {
    Database db = await database;
    final maps = await db.query('payout_records', orderBy: 'timestamp DESC');
    return maps.map((m) => PayoutRecord.fromMap(m)).toList();
  }

  Future<void> markPayoutSynced(int id) async {
    Database db = await database;
    await db.update(
      'payout_records',
      {'isSynced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Inserts a record only if no row with the same firestoreId exists.
  /// Falls back to a normal insert (no-op on conflict) for cloud-sourced records.
  /// Returns the new row id, or -1 if a duplicate was skipped.
  Future<int> insertRecord(PrintingRecord record) async {
    Database db = await database;
    if (record.firestoreId != null) {
      // Cloud-sourced: use IGNORE conflict strategy to prevent duplicates
      return await db.insert(
        'records',
        record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    // Locally created record: normal insert (no firestoreId yet)
    return await db.insert('records', record.toMap());
  }

  Future<List<PrintingRecord>> getRecords() async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query('records', orderBy: 'timestamp DESC');
    return List.generate(maps.length, (i) {
      return PrintingRecord.fromMap(maps[i]);
    });
  }

  Future<int> updateRecord(PrintingRecord record) async {
    Database db = await database;
    return await db.update(
      'records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<int> deleteRecord(int id) async {
    Database db = await database;
    return await db.delete(
      'records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<PrintingRecord?> getRecord(int id) async {
    final db = await database;
    final maps = await db.query('records', where: 'id = ?', whereArgs: [id], limit: 1);
    return maps.isEmpty ? null : PrintingRecord.fromMap(maps.first);
  }

  Future<int> deleteRecordByFirestoreId(String firestoreId) async {
    final db = await database;
    return db.delete('records', where: 'firestoreId = ?', whereArgs: [firestoreId]);
  }

  Future<PrintingRecord?> getRecordByFirestoreId(String firestoreId) async {
    final db = await database;
    final maps = await db.query('records',
        where: 'firestoreId = ?', whereArgs: [firestoreId], limit: 1);
    return maps.isEmpty ? null : PrintingRecord.fromMap(maps.first);
  }

  /// Keeps a local deletion marker until it has reached the cloud.  The marker
  /// also prevents a stale cloud snapshot from bringing the record back.
  ///
  /// [needsVerify] marks a document name that was reconstructed from a legacy
  /// local id rather than read off the record, so the sync layer confirms it
  /// exists before writing a tombstone for it.
  Future<void> markRecordDeleted(String firestoreId,
      {bool isSynced = false, bool needsVerify = false}) async {
    final db = await database;
    await db.insert(
      'deleted_record_ids',
      {
        'firestoreId': firestoreId,
        'deletedAt': DateTime.now().toUtc().toIso8601String(),
        'isSynced': isSynced ? 1 : 0,
        'needsVerify': needsVerify ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    // A deletion received from Firestore confirms any locally queued marker.
    if (isSynced) {
      await markDeletedRecordSynced(firestoreId);
    }
  }

  Future<bool> isRecordDeleted(String firestoreId) async {
    final db = await database;
    final maps = await db.query(
      'deleted_record_ids',
      columns: ['firestoreId'],
      where: 'firestoreId = ?',
      whereArgs: [firestoreId],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  /// Queued deletions waiting to reach the cloud, each with the flag saying
  /// whether its document name still needs confirming.
  Future<List<({String firestoreId, bool needsVerify})>>
      getUnsyncedDeletedRecordIds() async {
    final db = await database;
    final maps = await db.query(
      'deleted_record_ids',
      columns: ['firestoreId', 'needsVerify'],
      where: 'isSynced = ?',
      whereArgs: [0],
    );
    return maps
        .map((row) => (
              firestoreId: row['firestoreId'] as String,
              needsVerify: (row['needsVerify'] as int? ?? 0) == 1,
            ))
        .toList();
  }

  Future<void> markDeletedRecordSynced(String firestoreId) async {
    final db = await database;
    await db.update(
      'deleted_record_ids',
      {'isSynced': 1},
      where: 'firestoreId = ?',
      whereArgs: [firestoreId],
    );
  }

  /// Deletes tombstones that have reached the cloud and have been sitting
  /// around longer than [retentionDays].  The window has to outlive the longest
  /// plausible offline period, otherwise a phone that was offline for a month
  /// would lose the marker and later resurrect the record from its stale copy.
  /// Tombstones still waiting to upload are never purged.
  Future<int> purgeSyncedTombstones({int retentionDays = 90}) async {
    final db = await database;
    final cutoff =
        DateTime.now().toUtc().subtract(Duration(days: retentionDays)).toIso8601String();
    return db.delete(
      'deleted_record_ids',
      where: 'isSynced = ? AND deletedAt < ?',
      whereArgs: [1, cutoff],
    );
  }

  /// Number of local changes still waiting to reach the cloud.  Counts queued
  /// deletions as well as unsynced records so the UI cannot report "0 pending"
  /// while a deletion is still sitting in SQLite.
  Future<int> countPendingSyncs() async {
    final db = await database;
    final unsyncedRecords =
        Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM records WHERE isSynced = 0')) ??
        0;
    final pendingDeletes =
        Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM deleted_record_ids WHERE isSynced = 0')) ??
        0;
    return unsyncedRecords + pendingDeletes;
  }
}
