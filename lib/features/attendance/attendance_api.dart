import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../auth/auth_api.dart';
import '../leave/leave_api.dart' show pickName;

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;
Map<String, dynamic>? _map(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : null;
double? _d(Object? v) => v is num ? v.toDouble() : null;

/// The rectangle of a work area.
class ZoneBounds {
  const ZoneBounds(this.north, this.south, this.east, this.west);
  final double north;
  final double south;
  final double east;
  final double west;
}

/// A work area inside a site: a circle (center + radius) and / or a rectangle.
class WorkArea {
  const WorkArea(this.json);
  final Map<String, dynamic> json;

  int get id => (json['id'] as num).toInt();
  String name(String lang) => pickName(json, lang) ?? '';
  double? get latitude => _d(json['latitude']);
  double? get longitude => _d(json['longitude']);
  String get zoneType => (json['zoneType'] as String?) ?? '';
  double? get radiusMeters => _d(json['radiusMeters']);
  bool get isMine => json['isMine'] == true;
  Map<String, dynamic>? get _bounds => _map(json['bounds']);

  /// The rectangle, when the server sent all four sides.
  ZoneBounds? get bounds {
    final n = _d(_bounds?['north']), s = _d(_bounds?['south']);
    final e = _d(_bounds?['east']), w = _d(_bounds?['west']);
    return n == null || s == null || e == null || w == null
        ? null
        : ZoneBounds(n, s, e, w);
  }

  /// Meters from [lat],[lng] to the center of the area, or null without a center.
  double? distanceTo(double lat, double lng) {
    final a = latitude, b = longitude;
    if (a == null || b == null) return null;
    return distanceMeters(a, b, lat, lng);
  }

  /// Same rule as the server (the server decides; this is for the map).
  bool contains(double lat, double lng) {
    final circle = zoneType == 'CIRCLE' || zoneType == 'BOTH';
    final rect = zoneType == 'RECT' || zoneType == 'BOTH';
    if (circle && radiusMeters != null) {
      final d = distanceTo(lat, lng);
      if (d != null && d <= radiusMeters!) return true;
    }
    final n = _d(_bounds?['north']), s = _d(_bounds?['south']);
    final e = _d(_bounds?['east']), w = _d(_bounds?['west']);
    if (rect && n != null && s != null && e != null && w != null) {
      return lat >= s && lat <= n && lng >= w && lng <= e;
    }
    return false;
  }
}

/// Meters between two points on the earth.
double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const k = math.pi / 180;
  final x =
      math.sin(lat1 * k) * math.sin(lat2 * k) +
      math.cos(lat1 * k) * math.cos(lat2 * k) * math.cos((lng2 - lng1) * k);
  return 6371000 * math.acos(x.clamp(-1.0, 1.0));
}

/// A site the employee works at, with what they can do there today.
class AttendanceSite {
  const AttendanceSite(this.json);
  final Map<String, dynamic> json;

  int get id => (json['id'] as num).toInt();
  String name(String lang) => pickName(json, lang) ?? '';
  bool get isHome => json['isHome'] == true;

  /// `IN` (check in), `OUT` (check out) or `DONE` (already left today).
  String get action => (json['action'] as String?) ?? 'IN';
  List<WorkArea> get areas => [
    for (final a in (json['locations'] as List? ?? const []))
      WorkArea((a as Map).cast<String, dynamic>()),
  ];

  /// The area the phone is in, else null.
  WorkArea? areaAt(double lat, double lng) {
    for (final a in areas) {
      if (a.contains(lat, lng)) return a;
    }
    return null;
  }

  /// Meters to the closest area center.
  double? nearestMeters(double lat, double lng) {
    double? best;
    for (final a in areas) {
      final d = a.distanceTo(lat, lng);
      if (d != null && (best == null || d < best)) best = d;
    }
    return best;
  }
}

/// Today of the signed-in employee, as the server sees it.
class AttendanceToday {
  const AttendanceToday({
    required this.date,
    required this.allowed,
    required this.byLocation,
    required this.byFace,
    required this.state,
    required this.sites,
    this.checkInAt,
    this.checkOutAt,
    this.messageAr,
    this.messageEn,
    this.mockPolicy = 'BLOCK',
  });

  final DateTime? date;

  /// What the company does with a fake location: `BLOCK` (refuse) or `RECORD`
  /// (accept it and flag it for HR).
  final String mockPolicy;
  final bool allowed;
  final bool byLocation;
  final bool byFace;

  /// `NONE`, `IN` or `DONE`.
  final String state;
  final String? checkInAt;
  final String? checkOutAt;
  final String? messageAr;
  final String? messageEn;
  final List<AttendanceSite> sites;

  String? message(String lang) => lang == 'ar' ? messageAr : messageEn;

  factory AttendanceToday.fromJson(Map<String, dynamic> j) {
    final methods = _map(j['methods']) ?? const {};
    final msg = _map(j['message']);
    return AttendanceToday(
      date: _date(j['date']),
      allowed: j['allowed'] == true,
      byLocation: methods['location'] == true,
      byFace: methods['face'] == true,
      state: (j['state'] as String?) ?? 'NONE',
      checkInAt: j['checkInAt'] as String?,
      checkOutAt: j['checkOutAt'] as String?,
      messageAr: msg?['ar'] as String?,
      messageEn: msg?['en'] as String?,
      mockPolicy: _map(j['policy'])?['mockLocation'] == 'RECORD'
          ? 'RECORD'
          : 'BLOCK',
      sites: [
        for (final s in (j['sites'] as List? ?? const []))
          AttendanceSite((s as Map).cast<String, dynamic>()),
      ],
    );
  }
}

/// What the server answers to a check-in / check-out.
class CheckResult {
  const CheckResult({required this.type, required this.time, this.areaName});
  final String type; // IN / OUT
  final String time; // HH:MM, the server's clock
  final String? areaName;

  factory CheckResult.fromJson(Map<String, dynamic> j, String lang) =>
      CheckResult(
        type: (j['checkType'] as String?) ?? 'IN',
        time: (j['time'] as String?) ?? '',
        areaName: pickName(_map(j['location']), lang),
      );
}

/// What the phone measured, sent with every check-in.
class LocationFix {
  const LocationFix({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.isMock = false,
  });
  final double latitude;
  final double longitude;
  final double? accuracyMeters;

  /// Android reports a fake / mock provider.
  final bool isMock;
}

/// One day of the month summary.
class MonthDay {
  const MonthDay(this.json);
  final Map<String, dynamic> json;

  DateTime get date => DateTime.parse(json['date'] as String);

  /// PRESENT, ABSENT, OFF, LEAVE, MISSION, TODAY or FUTURE.
  String get status => (json['status'] as String?) ?? 'FUTURE';

  /// Why a day was off / not worked: LEAVE, MISSION, ABSENCE, HOLIDAY, COMP,
  /// PART_TIME_OFF or WEEKLY_OFF.
  String? get reason => json['reason'] as String?;

  /// The employee checked in on a rest day or a holiday (a star on the calendar).
  bool get workedOnOff => json['workedOnOff'] == true;
  String? name(String lang) => pickName(json, lang);
  String? get checkIn => json['checkIn'] as String?;
  String? get checkOut => json['checkOut'] as String?;
  double? get hours => _d(json['hours']);
}

/// A month of the employee, day by day.
class MonthSummary {
  const MonthSummary({
    required this.month,
    required this.supported,
    required this.days,
    required this.summary,
    this.prev,
    this.next,
    this.messageAr,
    this.messageEn,
  });

  /// `YYYY-MM`.
  final String month;
  final bool supported;
  final String? prev;
  final String? next;
  final List<MonthDay> days;

  /// present / absent / off / leave / mission / workedOnOff / hours.
  final Map<String, num> summary;
  final String? messageAr;
  final String? messageEn;

  String? message(String lang) => lang == 'ar' ? messageAr : messageEn;
  num count(String k) => summary[k] ?? 0;

  DateTime get firstDay {
    final p = month.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]));
  }

  factory MonthSummary.fromJson(Map<String, dynamic> j) {
    final msg = _map(j['message']);
    final sum = _map(j['summary']) ?? const {};
    return MonthSummary(
      month: j['month'] as String,
      supported: j['supported'] != false,
      prev: j['prev'] as String?,
      next: j['next'] as String?,
      messageAr: msg?['ar'] as String?,
      messageEn: msg?['en'] as String?,
      summary: {
        for (final e in sum.entries)
          if (e.value is num) e.key: e.value as num,
      },
      days: [
        for (final d in (j['days'] as List? ?? const []))
          MonthDay((d as Map).cast<String, dynamic>()),
      ],
    );
  }
}

/// The attendance calls of the company server (module `MobileAttendance`).
abstract interface class AttendanceApi {
  Future<AttendanceToday> today();

  /// One month (`YYYY-MM`, null = this month), day by day.
  Future<MonthSummary> month(String? month);

  /// The server decides IN or OUT and the time. Throws [AuthException] with the
  /// server's code (`OUTSIDE_AREA`, `ALREADY_LEFT`, `MOCK_LOCATION`...).
  Future<CheckResult> check({
    required int siteId,
    required LocationFix fix,
    required bool faceVerified,
    required String languageCode,
  });
}

/// Extra details of a refusal the screen shows (the distance of `OUTSIDE_AREA`).
class AttendanceRefusal extends AuthException {
  const AttendanceRefusal({
    required super.code,
    required super.messageAr,
    required super.messageEn,
    this.distanceMeters,
  });
  final int? distanceMeters;
}

class HttpAttendanceApi implements AttendanceApi {
  HttpAttendanceApi({
    required String baseUrl,
    required this.token,
    http.Client? client,
    this.timeout = const Duration(seconds: 25),
  }) : _base =
           '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/mobile/attendance/v1',
       _client = client;

  final String _base;
  final String token;
  final Duration timeout;
  final http.Client? _client;

  Future<Map<String, dynamic>> _call(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final uri = Uri.parse('$_base/$path');
    if (uri.scheme != 'https') throw const AuthException.network();
    final client = _client ?? http.Client();
    try {
      final request = http.Request(method, uri)
        ..followRedirects = false
        ..headers.addAll({
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'User-Agent': 'LockSysHR/1.0',
          'Authorization': 'Bearer $token',
        });
      if (body != null) request.body = jsonEncode(body);
      final response = await (() async => http.Response.fromStream(
        await client.send(request),
      ))().timeout(timeout);
      final Object? json;
      try {
        json = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        throw const AuthException.network();
      }
      if (json is! Map<String, dynamic>) throw const AuthException.network();
      if (json['success'] == true && json['data'] is Map<String, dynamic>) {
        return json['data'] as Map<String, dynamic>;
      }
      final error = json['error'];
      if (error is Map<String, dynamic>) {
        throw AttendanceRefusal(
          code: error['code'] as String? ?? 'ERROR',
          messageAr: error['message_ar'] as String? ?? '',
          messageEn: error['message_en'] as String? ?? '',
          distanceMeters: (error['distanceMeters'] as num?)?.toInt(),
        );
      }
      throw const AuthException.network();
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException.network();
    } finally {
      if (_client == null) client.close();
    }
  }

  @override
  Future<AttendanceToday> today() async =>
      AttendanceToday.fromJson(await _call('GET', 'today'));

  @override
  Future<MonthSummary> month(String? month) async => MonthSummary.fromJson(
    await _call('GET', month == null ? 'month' : 'month?month=$month'),
  );

  @override
  Future<CheckResult> check({
    required int siteId,
    required LocationFix fix,
    required bool faceVerified,
    required String languageCode,
  }) async => CheckResult.fromJson(
    await _call(
      'POST',
      'check',
      body: {
        'siteId': siteId,
        'latitude': fix.latitude,
        'longitude': fix.longitude,
        'accuracyMeters': ?fix.accuracyMeters,
        'faceVerified': faceVerified,
        'isMockLocation': fix.isMock,
      },
    ),
    languageCode,
  );
}

/// Development stand-in (tests, running without a server): one site with a
/// circular work area, and the server's rules (IN, then OUT, then done).
class MockAttendanceApi implements AttendanceApi {
  MockAttendanceApi({this.byLocation = true, this.byFace = true});

  bool byLocation;
  bool byFace;

  /// The company's fake-location policy: BLOCK or RECORD.
  String mockPolicy = 'BLOCK';
  String _state = 'NONE';
  String? _in;
  String? _out;

  /// The sample work area (Talkha factory).
  static const center = (lat: 31.0675, lng: 31.3953);
  static const radius = 120.0;

  static String _clock() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }

  @override
  Future<AttendanceToday> today() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return AttendanceToday.fromJson({
      'date': DateTime.now().toIso8601String().substring(0, 10),
      'allowed': byLocation || byFace,
      'methods': {'location': byLocation, 'face': byFace},
      'policy': {'mockLocation': mockPolicy},
      'state': _state,
      'checkInAt': _in,
      'checkOutAt': _out,
      'message': _state == 'DONE'
          ? {
              'ar': 'تم تسجيل انصرافك اليوم، أنت منصرف',
              'en': 'You already checked out today',
            }
          : null,
      'sites': [
        {
          'id': 51,
          'nameAr': 'شركة الدلتا للأسمدة',
          'nameEn': 'Delta Fertilizers',
          'isHome': true,
          'action': _state == 'DONE' ? 'DONE' : (_state == 'IN' ? 'OUT' : 'IN'),
          'locations': [
            {
              'id': 4,
              'nameAr': 'المصنع',
              'nameEn': 'Factory',
              'latitude': center.lat,
              'longitude': center.lng,
              'zoneType': 'CIRCLE',
              'radiusMeters': radius,
              'isMine': true,
            },
          ],
        },
      ],
    });
  }

  /// A sample month: worked weekdays, weekend rest (Fri / Sat) with one worked
  /// rest day (star), one absence, a leave and a holiday.
  @override
  Future<MonthSummary> month(String? month) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final now = DateTime.now();
    final key = month ?? '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final p = key.split('-');
    final first = DateTime(int.parse(p[0]), int.parse(p[1]));
    final last = DateTime(first.year, first.month + 1, 0);
    final today = DateTime(now.year, now.month, now.day);
    final days = <Map<String, dynamic>>[];
    final counts = {
      'present': 0,
      'absent': 0,
      'off': 0,
      'leave': 0,
      'mission': 0,
      'workedOnOff': 0,
    };
    for (var d = first; !d.isAfter(last); d = d.add(const Duration(days: 1))) {
      final off =
          d.weekday == DateTime.friday || d.weekday == DateTime.saturday;
      var status = 'FUTURE';
      String? reason;
      var star = false;
      if (!d.isAfter(today)) {
        if (d == today) {
          status = 'TODAY';
        } else if (d.day == 9) {
          status = 'ABSENT';
        } else if (d.day == 12 || d.day == 13) {
          status = 'LEAVE';
          reason = 'LEAVE';
        } else if (d.day == 15) {
          status = 'OFF';
          reason = 'HOLIDAY';
        } else if (off) {
          status = d.day == 11 ? 'PRESENT' : 'OFF';
          star = status == 'PRESENT';
          reason = status == 'OFF' ? 'WEEKLY_OFF' : null;
        } else {
          status = 'PRESENT';
        }
      } else if (off) {
        status = 'OFF';
        reason = 'WEEKLY_OFF';
      }
      switch (status) {
        case 'PRESENT':
          counts['present'] = counts['present']! + 1;
        case 'ABSENT':
          counts['absent'] = counts['absent']! + 1;
        case 'OFF':
          counts['off'] = counts['off']! + 1;
        case 'LEAVE':
          counts['leave'] = counts['leave']! + 1;
      }
      if (star) counts['workedOnOff'] = counts['workedOnOff']! + 1;
      days.add({
        'date':
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
        'status': status,
        'reason': reason,
        'workedOnOff': star,
        if (reason == 'LEAVE') 'nameAr': 'سنوية',
        if (reason == 'LEAVE') 'nameEn': 'Annual',
        if (reason == 'HOLIDAY') 'nameAr': 'عيد',
        if (reason == 'HOLIDAY') 'nameEn': 'Holiday',
        if (status == 'PRESENT') 'checkIn': '08:05',
        if (status == 'PRESENT') 'checkOut': '16:10',
        if (status == 'PRESENT') 'hours': 8.08,
      });
    }
    String fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
    final isCurrent = first.year == now.year && first.month == now.month;
    return MonthSummary.fromJson({
      'month': key,
      'supported': true,
      'prev': fmt(DateTime(first.year, first.month - 1)),
      'next': isCurrent ? null : fmt(DateTime(first.year, first.month + 1)),
      'summary': {...counts, 'hours': counts['present']! * 8.08},
      'days': days,
    });
  }

  @override
  Future<CheckResult> check({
    required int siteId,
    required LocationFix fix,
    required bool faceVerified,
    required String languageCode,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (_state == 'DONE') {
      throw const AttendanceRefusal(
        code: 'ALREADY_LEFT',
        messageAr: 'تم تسجيل انصرافك اليوم، أنت منصرف',
        messageEn: 'You already checked out today',
      );
    }
    if (fix.isMock && mockPolicy != 'RECORD') {
      throw const AttendanceRefusal(
        code: 'MOCK_LOCATION',
        messageAr: 'تم اكتشاف موقع وهمي',
        messageEn: 'A fake location was detected',
      );
    }
    final d = distanceMeters(
      center.lat,
      center.lng,
      fix.latitude,
      fix.longitude,
    );
    // A recorded fake location is accepted without the area check.
    if (byLocation && d > radius && !fix.isMock) {
      throw AttendanceRefusal(
        code: 'OUTSIDE_AREA',
        messageAr: 'أنت خارج منطقة العمل',
        messageEn: 'You are outside your work area',
        distanceMeters: d.round(),
      );
    }
    final now = _clock();
    final type = _state == 'IN' ? 'OUT' : 'IN';
    if (type == 'IN') {
      _state = 'IN';
      _in = now;
    } else {
      _state = 'DONE';
      _out = now;
    }
    return CheckResult(type: type, time: now, areaName: 'Factory');
  }
}
