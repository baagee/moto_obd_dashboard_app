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
    await db.execute(
        'CREATE INDEX idx_riding_records_start_time ON riding_records(start_time)');
    await db.execute(
        'CREATE INDEX idx_riding_events_record_id ON riding_events(record_id)');
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

  /// 删除所有骑行记录（级联删除事件和每日统计）
  static Future<void> deleteAllRidingRecords() async {
    final db = await database;
    await db.delete('riding_records');
    await db.delete('daily_stats');
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
  static Future<int> insertRidingEvent(
      int recordId, Map<String, dynamic> event) async {
    final db = await database;
    final data = Map<String, dynamic>.from(event);
    data['record_id'] = recordId;
    return await db.insert('riding_events', data);
  }

  /// 批量插入骑行事件
  static Future<void> insertRidingEvents(
      int recordId, List<Map<String, dynamic>> events) async {
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
  static Future<List<Map<String, dynamic>>> getEventsByRecordId(
      int recordId) async {
    final db = await database;
    return await db.query(
      'riding_events',
      where: 'record_id = ?',
      whereArgs: [recordId],
      orderBy: 'timestamp ASC',
    );
  }

  /// 删除骑行事件
  static Future<int> deleteRidingEvent(int id) async {
    final db = await database;
    return await db.delete(
      'riding_events',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ========== 每日聚合 ==========

  /// 更新或插入每日统计（UPSERT）
  static Future<void> upsertDailyStats(
      String date, Map<String, dynamic> stats) async {
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

  /// 计算今日统计（从 daily_stats 读取，与周/月统计方式一致）
  /// 使用 end_time 日期匹配，避免跨天骑行（如23:50开始、次日00:10结束）被遗漏
  static Future<Map<String, dynamic>> calculateTodayStats() async {
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final todayStat = await getDailyStats(todayStr);
    if (todayStat == null) {
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

    // daily_stats 已经是聚合好的数据，直接转换格式返回
    return {
      'distance': (todayStat['total_distance'] as num?)?.toDouble() ?? 0.0,
      'duration': (todayStat['total_duration'] as int?) ?? 0,
      'avgSpeed': (todayStat['avg_speed'] as num?)?.toDouble() ?? 0.0,
      'maxSpeed': (todayStat['max_speed'] as num?)?.toDouble() ?? 0.0,
      'maxLeftLean': (todayStat['max_left_lean'] as num?)?.toDouble() ?? 0.0,
      'maxRightLean': (todayStat['max_right_lean'] as num?)?.toDouble() ?? 0.0,
      'rideCount': (todayStat['ride_count'] as int?) ?? 0,
    };
  }

  /// 从 daily_stats 聚合计算近7天/30天统计
  static Future<Map<String, dynamic>> calculatePeriodStats(int days) async {
    final now = DateTime.now();
    final endDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final startDate =
        '${now.subtract(Duration(days: days)).year}-${(now.subtract(Duration(days: days))).month.toString().padLeft(2, '0')}-${(now.subtract(Duration(days: days))).day.toString().padLeft(2, '0')}';

    final dailyStats = await getDailyStatsByDateRange(startDate, endDate);

    double totalDistance = 0;
    int totalDuration = 0;
    double maxSpeed = 0;
    double maxLeftLean = 0;
    double maxRightLean = 0;
    int rideCount = 0;
    // 使用时长加权计算平均速度：sum(avgSpeed_i * duration_i) / sum(duration_i)
    // 避免"次数加权"导致短途骑行与长途骑行权重相同的问题
    double weightedSpeedSum = 0;

    for (final stat in dailyStats) {
      final distance = (stat['total_distance'] as num?)?.toDouble() ?? 0;
      final duration = (stat['total_duration'] as int?) ?? 0;
      final avgSpeed = (stat['avg_speed'] as num?)?.toDouble() ?? 0;
      final rides = (stat['ride_count'] as int?) ?? 0;

      totalDistance += distance;
      totalDuration += duration;
      rideCount += rides;
      maxSpeed = maxSpeed > ((stat['max_speed'] as num?)?.toDouble() ?? 0)
          ? maxSpeed
          : ((stat['max_speed'] as num?)?.toDouble() ?? 0);
      maxLeftLean =
          maxLeftLean > ((stat['max_left_lean'] as num?)?.toDouble() ?? 0)
              ? maxLeftLean
              : ((stat['max_left_lean'] as num?)?.toDouble() ?? 0);
      maxRightLean =
          maxRightLean > ((stat['max_right_lean'] as num?)?.toDouble() ?? 0)
              ? maxRightLean
              : ((stat['max_right_lean'] as num?)?.toDouble() ?? 0);

      // 以时长为权重累加
      if (duration > 0) {
        weightedSpeedSum += avgSpeed * duration;
      }
    }

    return {
      'distance': totalDistance,
      'duration': totalDuration,
      'avgSpeed': totalDuration > 0 ? weightedSpeedSum / totalDuration : 0.0,
      'maxSpeed': maxSpeed,
      'maxLeftLean': maxLeftLean,
      'maxRightLean': maxRightLean,
      'rideCount': rideCount,
    };
  }

  /// 聚合骑行记录列表
  static Map<String, dynamic> _aggregateRecords(
      List<Map<String, dynamic>> records) {
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
    // 以时长为权重计算平均速度，避免短途/长途次数平权导致结果偏差
    double weightedSpeedSum = 0;

    for (final record in records) {
      final distance = (record['distance'] as num?)?.toDouble() ?? 0;
      final duration = (record['duration'] as int?) ?? 0;
      final avgSpeed = (record['avg_speed'] as num?)?.toDouble() ?? 0;

      totalDistance += distance;
      totalDuration += duration;
      maxSpeed = maxSpeed > ((record['max_speed'] as num?)?.toDouble() ?? 0)
          ? maxSpeed
          : ((record['max_speed'] as num?)?.toDouble() ?? 0);
      maxLeftLean =
          maxLeftLean > ((record['max_left_lean'] as num?)?.toDouble() ?? 0)
              ? maxLeftLean
              : ((record['max_left_lean'] as num?)?.toDouble() ?? 0);
      maxRightLean =
          maxRightLean > ((record['max_right_lean'] as num?)?.toDouble() ?? 0)
              ? maxRightLean
              : ((record['max_right_lean'] as num?)?.toDouble() ?? 0);
      if (duration > 0) {
        weightedSpeedSum += avgSpeed * duration;
      }
    }

    return {
      'distance': totalDistance,
      'duration': totalDuration,
      'avgSpeed': totalDuration > 0 ? weightedSpeedSum / totalDuration : 0.0,
      'maxSpeed': maxSpeed,
      'maxLeftLean': maxLeftLean,
      'maxRightLean': maxRightLean,
      'rideCount': records.length,
    };
  }

  // ========== 开发调试工具 ==========

  /// 插入 Mock 骑行数据（仅用于开发测试）
  static Future<void> insertMockRidingRecords() async {
    final db = await database;
    final now = DateTime.now();

    // 北京坐标范围（海淀区、朝阳区常见地点）
    final mockLocations = [
      {'lat': 40.0546, 'lng': 116.2920, 'name': '万家灯火大厦'},
      {'lat': 39.9827, 'lng': 116.3129, 'name': '中关村'},
      {'lat': 39.9075, 'lng': 116.3972, 'name': '天安门'},
      {'lat': 40.0081, 'lng': 116.3279, 'name': '鸟巢'},
      {'lat': 39.9849, 'lng': 116.4786, 'name': 'CBD'},
      {'lat': 39.9289, 'lng': 116.3883, 'name': '什刹海'},
    ];

    final random = DateTime.now().millisecondsSinceEpoch % 100;

    // 生成 5 条 mock 记录（最近 7 天内）
    for (int i = 0; i < 5; i++) {
      final daysAgo = i;
      final startLoc = mockLocations[(random + i) % mockLocations.length];
      final endLoc = mockLocations[(random + i + 1) % mockLocations.length];

      final startTime =
          now.subtract(Duration(days: daysAgo, hours: 2, minutes: 10 + i * 5));
      final endTime = startTime.add(Duration(minutes: 15 + i * 3));
      final duration = endTime.difference(startTime).inSeconds;

      final distance = 5.0 + i * 2.5; // 5km ~ 15km
      final avgSpeed = (distance / duration * 3600); // km/h
      final maxSpeed = avgSpeed * 1.5;
      final maxLeftLean = 20.0 + (random + i * 3) % 25;
      final maxRightLean = 18.0 + (random + i * 2) % 23;

      final recordId = await db.insert('riding_records', {
        'start_time': startTime.millisecondsSinceEpoch,
        'end_time': endTime.millisecondsSinceEpoch,
        'start_latitude': startLoc['lat'],
        'start_longitude': startLoc['lng'],
        'start_place_name': startLoc['name'],
        'end_latitude': endLoc['lat'],
        'end_longitude': endLoc['lng'],
        'end_place_name': endLoc['name'],
        'distance': distance,
        'avg_speed': avgSpeed,
        'duration': duration,
        'max_speed': maxSpeed,
        'max_left_lean': maxLeftLean,
        'max_right_lean': maxRightLean,
        'created_at': startTime.millisecondsSinceEpoch,
      });

      // 插入 1-3 个骑行事件
      final eventCount = 1 + (i % 3);
      for (int j = 0; j < eventCount; j++) {
        final eventTime =
            startTime.add(Duration(minutes: 3 + j * 4)).millisecondsSinceEpoch;
        final eventTypes = ['speed', 'lean', 'rpm'];
        final type = eventTypes[j % eventTypes.length];

        String title = '';
        String description = '';
        double triggerValue = 0;
        double threshold = 0;

        switch (type) {
          case 'speed':
            triggerValue = 90 + j * 10;
            threshold = 80;
            title = '速度过快';
            description = '当前速度 ${triggerValue.toInt()} km/h';
            break;
          case 'lean':
            triggerValue = 35 + j * 5;
            threshold = 30;
            title = '倾角过大';
            description = '左倾 ${triggerValue.toInt()}°';
            break;
          case 'rpm':
            triggerValue = 8500 + j * 200;
            threshold = 8000;
            title = '转速过高';
            description = '当前转速 ${triggerValue.toInt()} RPM';
            break;
        }

        await db.insert('riding_events', {
          'record_id': recordId,
          'type': type,
          'title': title,
          'description': description,
          'trigger_value': triggerValue,
          'threshold': threshold,
          'timestamp': eventTime,
        });
      }

      // 更新 daily_stats
      final dateStr =
          '${startTime.year}-${startTime.month.toString().padLeft(2, '0')}-${startTime.day.toString().padLeft(2, '0')}';
      final existing = await db
          .query('daily_stats', where: 'date = ?', whereArgs: [dateStr]);

      if (existing.isEmpty) {
        await db.insert('daily_stats', {
          'date': dateStr,
          'total_distance': distance,
          'total_duration': duration,
          'avg_speed': avgSpeed,
          'max_speed': maxSpeed,
          'max_left_lean': maxLeftLean,
          'max_right_lean': maxRightLean,
          'ride_count': 1,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });
      } else {
        final old = existing.first;
        await db.update(
          'daily_stats',
          {
            'total_distance': (old['total_distance'] as num) + distance,
            'total_duration': (old['total_duration'] as int) + duration,
            'avg_speed':
                ((old['avg_speed'] as num) * (old['ride_count'] as int) +
                        avgSpeed) /
                    ((old['ride_count'] as int) + 1),
            'max_speed': ((old['max_speed'] as num) > maxSpeed)
                ? old['max_speed']
                : maxSpeed,
            'max_left_lean': ((old['max_left_lean'] as num) > maxLeftLean)
                ? old['max_left_lean']
                : maxLeftLean,
            'max_right_lean': ((old['max_right_lean'] as num) > maxRightLean)
                ? old['max_right_lean']
                : maxRightLean,
            'ride_count': (old['ride_count'] as int) + 1,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'date = ?',
          whereArgs: [dateStr],
        );
      }
    }

    print('[Mock] 已插入 5 条骑行记录到数据库');
  }
}
