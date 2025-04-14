import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/download_model.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'downloads.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    // Active downloads table
    await db.execute('''
      CREATE TABLE downloads(
        id TEXT PRIMARY KEY,
        fileName TEXT,
        fileType TEXT,
        fileSize REAL,
        url TEXT,
        status INTEGER,
        progress REAL,
        speed REAL,
        remainingTime TEXT,
        localPath TEXT,
        startTime INTEGER,
        endTime INTEGER,
        retryCount INTEGER,
        isScheduled INTEGER,
        scheduledTime INTEGER,
        metadata TEXT
      )
    ''');

    // History table
    await db.execute('''
      CREATE TABLE history(
        id TEXT PRIMARY KEY,
        fileName TEXT,
        fileType TEXT,
        fileSize REAL,
        url TEXT,
        status INTEGER,
        progress REAL,
        speed REAL,
        remainingTime TEXT,
        localPath TEXT,
        startTime INTEGER,
        endTime INTEGER,
        retryCount INTEGER,
        isScheduled INTEGER,
        scheduledTime INTEGER,
        metadata TEXT
      )
    ''');

    // Scheduled downloads table
    await db.execute('''
      CREATE TABLE scheduled(
        id TEXT PRIMARY KEY,
        fileName TEXT,
        fileType TEXT,
        fileSize REAL,
        url TEXT,
        status INTEGER,
        progress REAL,
        speed REAL,
        remainingTime TEXT,
        localPath TEXT,
        startTime INTEGER,
        endTime INTEGER,
        retryCount INTEGER,
        isScheduled INTEGER,
        scheduledTime INTEGER,
        metadata TEXT
      )
    ''');

    // Settings table
    await db.execute('''
      CREATE TABLE settings(
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  // Downloads CRUD operations
  Future<void> saveDownload(DownloadItem item) async {
    final db = await database;
    await db.insert(
      'downloads',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateDownload(DownloadItem item) async {
    final db = await database;
    await db.update(
      'downloads',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> deleteDownload(String id) async {
    final db = await database;
    await db.delete(
      'downloads',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<DownloadItem>> getDownloads() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('downloads');
    return List.generate(maps.length, (i) {
      return DownloadItem.fromMap(maps[i]);
    });
  }

  // History CRUD operations
  Future<void> saveHistory(DownloadItem item) async {
    final db = await database;
    await db.insert(
      'history',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteHistory(String id) async {
    final db = await database;
    await db.delete(
      'history',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearHistory() async {
    final db = await database;
    await db.delete('history');
  }

  Future<List<DownloadItem>> getHistory() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('history');
    return List.generate(maps.length, (i) {
      return DownloadItem.fromMap(maps[i]);
    });
  }

  // Scheduled downloads CRUD operations
  Future<void> saveScheduledDownload(DownloadItem item) async {
    final db = await database;
    await db.insert(
      'scheduled',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteScheduledDownload(String id) async {
    final db = await database;
    await db.delete(
      'scheduled',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<DownloadItem>> getScheduledDownloads() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('scheduled');
    return List.generate(maps.length, (i) {
      return DownloadItem.fromMap(maps[i]);
    });
  }

  // Settings operations
  Future<void> saveSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );

    if (maps.isNotEmpty) {
      return maps.first['value'] as String;
    }
    return null;
  }

  Future<Map<String, String>> getAllSettings() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('settings');
    
    final Map<String, String> settings = {};
    for (var map in maps) {
      settings[map['key']] = map['value'];
    }
    return settings;
  }
}
