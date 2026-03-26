import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// SQLite数据库服务 - 单例模式
class DatabaseService {
  static Database? _database;
  static const String _dbName = 'obd_dashboard.db';
  static const int _dbVersion = 1;

  /// 获取数据库实例
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// 初始化数据库
  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  /// 创建表
  static Future<void> _onCreate(Database db, int version) async {
    // 骑行记录表
    await db.execute('''
      CREATE TABLE riding_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_time INTEGER NOT NULL,
        end_time INTEGER,
        start_latitude REAL,
        start_longitude REAL,
        start_place_name TEXT,
        end_latitude REAL,
        end_longitude REAL,
        end_place_name TEXT,
        distance REAL DEFAULT 0,
        avg_speed REAL DEFAULT 0,
        duration INTEGER DEFAULT 0,
        max_speed REAL DEFAULT 0,
        max_left_lean REAL DEFAULT 0,
        max_right_lean REAL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    // 骑行事件表
    await db.execute('''
      CREATE TABLE riding_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        record_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        trigger_value REAL,
        threshold REAL,
        timestamp INTEGER NOT NULL,
        additional_data TEXT,
        FOREIGN KEY (record_id) REFERENCES riding_records(id) ON DELETE CASCADE
      )
    ''');

    // 每日聚合表
    await db.execute('''
      CREATE TABLE daily_stats (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL UNIQUE,
        total_distance REAL DEFAULT 0,
        total_duration INTEGER DEFAULT 0,
        avg_speed REAL DEFAULT 0,
        max_speed REAL DEFAULT 0,
        max_left_lean REAL DEFAULT 0,
        max_right_lean REAL DEFAULT 0,
        ride_count INTEGER DEFAULT 0,
        updated_at INTEGER NOT NULL
      )
    ''');

    // 创建索引
    await db.execute('CREATE INDEX idx_riding_records_start_time ON riding_records(start_time)');
    await db.execute('CREATE INDEX idx_riding_events_record_id ON riding_events(record_id)');
    await db.execute('CREATE INDEX idx_daily_stats_date ON daily_stats(date)');
  }

  // ========== 骑行记录 CRUD ==========

  /// 插入骑行记录
  static Future<int> insertRidingRecord(Map<String, dynamic> record) async {
    final db = await database;
    return await db.insert('riding_records', record);
  }

  /// 查询所有骑行记录（按时间倒序）
  static Future<List<Map<String, dynamic>>> getAllRidingRecords() async {
    final db = await database;
    return await db.query(
      'riding_records',
      orderBy: 'start_time DESC',
    );
  }

  /// 查询指定时间范围内的骑行记录
  static Future<List<Map<String, dynamic>>> getRidingRecordsByTimeRange(
    int startTime,
    int endTime,
  ) async {
    final db = await database;
    return await db.query(
      'riding_records',
      where: 'start_time >= ? AND start_time <= ?',
      whereArgs: [startTime, endTime],
      orderBy: 'start_time DESC',
    );
  }

  /// 删除骑行记录（级联删除事件）
  static Future<int> deleteRidingRecord(int id) async {
    final db = await database;
    return await db.delete(
      'riding_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ========== 骑行事件 CRUD ==========

  /// 插入骑行事件
  static Future<int> insertRidingEvent(int recordId, Map<String, dynamic> event) async {
    final db = await database;
    final data = Map<String, dynamic>.from(event);
    data['record_id'] = recordId;
    return await db.insert('riding_events', data);
  }

  /// 批量插入骑行事件
  static Future<void> insertRidingEvents(int recordId, List<Map<String, dynamic>> events) async {
    final db = await database;
    final batch = db.batch();
    for (final event in events) {
      final data = Map<String, dynamic>.from(event);
      data['record_id'] = recordId;
      batch.insert('riding_events', data);
    }
    await batch.commit(noResult: true);
  }

  /// 查询指定骑行记录的所有事件
  static Future<List<Map<String, dynamic>>> getEventsByRecordId(int recordId) async {
    final db = await database;
    return await db.query(
      'riding_events',
      where: 'record_id = ?',
      whereArgs: [recordId],
      orderBy: 'timestamp ASC',
    );
  }

  // ========== 每日聚合 ==========

  /// 更新或插入每日统计（UPSERT）
  static Future<void> upsertDailyStats(String date, Map<String, dynamic> stats) async {
    final db = await database;
    final data = Map<String, dynamic>.from(stats);
    data['date'] = date;
    data['updated_at'] = DateTime.now().millisecondsSinceEpoch;

    await db.insert(
      'daily_stats',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 查询指定日期范围的每日统计
  static Future<List<Map<String, dynamic>>> getDailyStatsByDateRange(
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    return await db.query(
      'daily_stats',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'date DESC',
    );
  }

  /// 查询当日统计
  static Future<Map<String, dynamic>?> getDailyStats(String date) async {
    final db = await database;
    final results = await db.query(
      'daily_stats',
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  // ========== 聚合计算 ==========

  /// 计算今日统计（实时从 riding_records 聚合）
  static Future<Map<String, dynamic>> calculateTodayStats() async {
    final db = await database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startTime = startOfDay.millisecondsSinceEpoch;

    final records = await db.query(
      'riding_records',
      where: 'start_time >= ?',
      whereArgs: [startTime],
    );

    return _aggregateRecords(records);
  }

  /// 从 daily_stats 聚合计算近7天/30天统计
  static Future<Map<String, dynamic>> calculatePeriodStats(int days) async {
    final now = DateTime.now();
    final endDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final startDate = '${now.subtract(Duration(days: days)).year}-${(now.subtract(Duration(days: days))).month.toString().padLeft(2, '0')}-${(now.subtract(Duration(days: days))).day.toString().padLeft(2, '0')}';

    final dailyStats = await getDailyStatsByDateRange(startDate, endDate);

    double totalDistance = 0;
    int totalDuration = 0;
    double maxSpeed = 0;
    double maxLeftLean = 0;
    double maxRightLean = 0;
    int rideCount = 0;
    double totalSpeedSum = 0;

    for (final stat in dailyStats) {
      totalDistance += (stat['total_distance'] as num?)?.toDouble() ?? 0;
      totalDuration += (stat['total_duration'] as int?) ?? 0;
      maxSpeed = maxSpeed > ((stat['max_speed'] as num?)?.toDouble() ?? 0) ? maxSpeed : ((stat['max_speed'] as num?)?.toDouble() ?? 0);
      maxLeftLean = maxLeftLean > ((stat['max_left_lean'] as num?)?.toDouble() ?? 0) ? maxLeftLean : ((stat['max_left_lean'] as num?)?.toDouble() ?? 0);
      maxRightLean = maxRightLean > ((stat['max_right_lean'] as num?)?.toDouble() ?? 0) ? maxRightLean : ((stat['max_right_lean'] as num?)?.toDouble() ?? 0);
      rideCount += (stat['ride_count'] as int?) ?? 0;
      if ((stat['avg_speed'] as num?)?.toDouble() != null && (stat['ride_count'] as int?) != null) {
        totalSpeedSum += ((stat['avg_speed'] as num).toDouble() * (stat['ride_count'] as int));
      }
    }

    return {
      'distance': totalDistance,
      'duration': totalDuration,
      'avgSpeed': rideCount > 0 ? totalSpeedSum / rideCount : 0.0,
      'maxSpeed': maxSpeed,
      'maxLeftLean': maxLeftLean,
      'maxRightLean': maxRightLean,
      'rideCount': rideCount,
    };
  }

  /// 聚合骑行记录列表
  static Map<String, dynamic> _aggregateRecords(List<Map<String, dynamic>> records) {
    if (records.isEmpty) {
      return {
        'distance': 0.0,
        'duration': 0,
        'avgSpeed': 0.0,
        'maxSpeed': 0.0,
        'maxLeftLean': 0.0,
        'maxRightLean': 0.0,
        'rideCount': 0,
      };
    }

    double totalDistance = 0;
    int totalDuration = 0;
    double maxSpeed = 0;
    double maxLeftLean = 0;
    double maxRightLean = 0;
    double speedSum = 0;

    for (final record in records) {
      totalDistance += (record['distance'] as num?)?.toDouble() ?? 0;
      totalDuration += (record['duration'] as int?) ?? 0;
      maxSpeed = maxSpeed > ((record['max_speed'] as num?)?.toDouble() ?? 0) ? maxSpeed : ((record['max_speed'] as num?)?.toDouble() ?? 0);
      maxLeftLean = maxLeftLean > ((record['max_left_lean'] as num?)?.toDouble() ?? 0) ? maxLeftLean : ((record['max_left_lean'] as num?)?.toDouble() ?? 0);
      maxRightLean = maxRightLean > ((record['max_right_lean'] as num?)?.toDouble() ?? 0) ? maxRightLean : ((record['max_right_lean'] as num?)?.toDouble() ?? 0);
      speedSum += (record['avg_speed'] as num?)?.toDouble() ?? 0;
    }

    return {
      'distance': totalDistance,
      'duration': totalDuration,
      'avgSpeed': records.isNotEmpty ? speedSum / records.length : 0.0,
      'maxSpeed': maxSpeed,
      'maxLeftLean': maxLeftLean,
      'maxRightLean': maxRightLean,
      'rideCount': records.length,
    };
  }
}
