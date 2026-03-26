import 'dart:convert';

/// 骑行记录数据模型
class RidingRecord {
  final int? id;
  final int startTime;
  final int? endTime;
  final double? startLatitude;
  final double? startLongitude;
  final String? startPlaceName;
  final double? endLatitude;
  final double? endLongitude;
  final String? endPlaceName;
  final double distance;
  final double avgSpeed;
  final int duration;
  final double maxSpeed;
  final double maxLeftLean;
  final double maxRightLean;
  final int createdAt;

  RidingRecord({
    this.id,
    required this.startTime,
    this.endTime,
    this.startLatitude,
    this.startLongitude,
    this.startPlaceName,
    this.endLatitude,
    this.endLongitude,
    this.endPlaceName,
    this.distance = 0,
    this.avgSpeed = 0,
    this.duration = 0,
    this.maxSpeed = 0,
    this.maxLeftLean = 0,
    this.maxRightLean = 0,
    required this.createdAt,
  });

  factory RidingRecord.fromMap(Map<String, dynamic> map) {
    return RidingRecord(
      id: map['id'] as int?,
      startTime: map['start_time'] as int,
      endTime: map['end_time'] as int?,
      startLatitude: (map['start_latitude'] as num?)?.toDouble(),
      startLongitude: (map['start_longitude'] as num?)?.toDouble(),
      startPlaceName: map['start_place_name'] as String?,
      endLatitude: (map['end_latitude'] as num?)?.toDouble(),
      endLongitude: (map['end_longitude'] as num?)?.toDouble(),
      endPlaceName: map['end_place_name'] as String?,
      distance: (map['distance'] as num?)?.toDouble() ?? 0,
      avgSpeed: (map['avg_speed'] as num?)?.toDouble() ?? 0,
      duration: (map['duration'] as int?) ?? 0,
      maxSpeed: (map['max_speed'] as num?)?.toDouble() ?? 0,
      maxLeftLean: (map['max_left_lean'] as num?)?.toDouble() ?? 0,
      maxRightLean: (map['max_right_lean'] as num?)?.toDouble() ?? 0,
      createdAt: map['created_at'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'start_time': startTime,
      'end_time': endTime,
      'start_latitude': startLatitude,
      'start_longitude': startLongitude,
      'start_place_name': startPlaceName,
      'end_latitude': endLatitude,
      'end_longitude': endLongitude,
      'end_place_name': endPlaceName,
      'distance': distance,
      'avg_speed': avgSpeed,
      'duration': duration,
      'max_speed': maxSpeed,
      'max_left_lean': maxLeftLean,
      'max_right_lean': maxRightLean,
      'created_at': createdAt,
    };
  }

  String get formattedStartTime {
    final dt = DateTime.fromMillisecondsSinceEpoch(startTime);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String get formattedEndTime {
    if (endTime == null) return '--:--';
    final dt = DateTime.fromMillisecondsSinceEpoch(endTime!);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String get formattedDuration {
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    if (hours > 0) {
      return '$hours.${minutes.toString().padLeft(2, '0')}h';
    }
    return '${minutes}min';
  }

  RidingRecord copyWith({
    int? id,
    int? startTime,
    int? endTime,
    double? startLatitude,
    double? startLongitude,
    String? startPlaceName,
    double? endLatitude,
    double? endLongitude,
    String? endPlaceName,
    double? distance,
    double? avgSpeed,
    int? duration,
    double? maxSpeed,
    double? maxLeftLean,
    double? maxRightLean,
    int? createdAt,
  }) {
    return RidingRecord(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      startLatitude: startLatitude ?? this.startLatitude,
      startLongitude: startLongitude ?? this.startLongitude,
      startPlaceName: startPlaceName ?? this.startPlaceName,
      endLatitude: endLatitude ?? this.endLatitude,
      endLongitude: endLongitude ?? this.endLongitude,
      endPlaceName: endPlaceName ?? this.endPlaceName,
      distance: distance ?? this.distance,
      avgSpeed: avgSpeed ?? this.avgSpeed,
      duration: duration ?? this.duration,
      maxSpeed: maxSpeed ?? this.maxSpeed,
      maxLeftLean: maxLeftLean ?? this.maxLeftLean,
      maxRightLean: maxRightLean ?? this.maxRightLean,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 骑行事件数据模型（用于存储到数据库）
class RidingRecordEvent {
  final int? id;
  final int? recordId;
  final String type;
  final String title;
  final String? description;
  final double triggerValue;
  final double threshold;
  final int timestamp;
  final Map<String, dynamic>? additionalData;

  RidingRecordEvent({
    this.id,
    this.recordId,
    required this.type,
    required this.title,
    this.description,
    required this.triggerValue,
    required this.threshold,
    required this.timestamp,
    this.additionalData,
  });

  factory RidingRecordEvent.fromMap(Map<String, dynamic> map) {
    return RidingRecordEvent(
      id: map['id'] as int?,
      recordId: map['record_id'] as int?,
      type: map['type'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      triggerValue: (map['trigger_value'] as num?)?.toDouble() ?? 0,
      threshold: (map['threshold'] as num?)?.toDouble() ?? 0,
      timestamp: map['timestamp'] as int,
      additionalData: map['additional_data'] != null
          ? json.decode(map['additional_data'] as String) as Map<String, dynamic>
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (recordId != null) 'record_id': recordId,
      'type': type,
      'title': title,
      'description': description,
      'trigger_value': triggerValue,
      'threshold': threshold,
      'timestamp': timestamp,
      'additional_data': additionalData != null ? json.encode(additionalData) : null,
    };
  }

  String get formattedTime {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}

/// 每日统计模型
class DailyStats {
  final String date;
  final double totalDistance;
  final int totalDuration;
  final double avgSpeed;
  final double maxSpeed;
  final double maxLeftLean;
  final double maxRightLean;
  final int rideCount;

  DailyStats({
    required this.date,
    this.totalDistance = 0,
    this.totalDuration = 0,
    this.avgSpeed = 0,
    this.maxSpeed = 0,
    this.maxLeftLean = 0,
    this.maxRightLean = 0,
    this.rideCount = 0,
  });

  factory DailyStats.fromMap(Map<String, dynamic> map) {
    return DailyStats(
      date: map['date'] as String,
      totalDistance: (map['total_distance'] as num?)?.toDouble() ?? 0,
      totalDuration: (map['total_duration'] as int?) ?? 0,
      avgSpeed: (map['avg_speed'] as num?)?.toDouble() ?? 0,
      maxSpeed: (map['max_speed'] as num?)?.toDouble() ?? 0,
      maxLeftLean: (map['max_left_lean'] as num?)?.toDouble() ?? 0,
      maxRightLean: (map['max_right_lean'] as num?)?.toDouble() ?? 0,
      rideCount: (map['ride_count'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'total_distance': totalDistance,
      'total_duration': totalDuration,
      'avg_speed': avgSpeed,
      'max_speed': maxSpeed,
      'max_left_lean': maxLeftLean,
      'max_right_lean': maxRightLean,
      'ride_count': rideCount,
    };
  }
}

/// 聚合统计数据模型
class AggregationStats {
  final double distance;
  final int duration;
  final double avgSpeed;
  final double maxSpeed;
  final double maxLeftLean;
  final double maxRightLean;
  final int rideCount;

  AggregationStats({
    this.distance = 0,
    this.duration = 0,
    this.avgSpeed = 0,
    this.maxSpeed = 0,
    this.maxLeftLean = 0,
    this.maxRightLean = 0,
    this.rideCount = 0,
  });

  factory AggregationStats.fromMap(Map<String, dynamic> map) {
    return AggregationStats(
      distance: (map['distance'] as num?)?.toDouble() ?? 0,
      duration: (map['duration'] as int?) ?? 0,
      avgSpeed: (map['avgSpeed'] as num?)?.toDouble() ?? 0,
      maxSpeed: (map['maxSpeed'] as num?)?.toDouble() ?? 0,
      maxLeftLean: (map['maxLeftLean'] as num?)?.toDouble() ?? 0,
      maxRightLean: (map['maxRightLean'] as num?)?.toDouble() ?? 0,
      rideCount: (map['rideCount'] as int?) ?? 0,
    );
  }

  String get formattedDuration {
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    return '$hours.${minutes.toString().padLeft(2, '0')}h';
  }
}
