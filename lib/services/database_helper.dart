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
      version: 9,
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
}
