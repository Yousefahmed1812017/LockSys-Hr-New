import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/auth_api.dart';

/// Picks the Arabic or English text of a `{nameAr, nameEn}` object, falling back
/// to the other one (the ERP often fills only one) and trimming stray CR/LF.
String? pickName(
  Map<String, dynamic>? m,
  String languageCode, {
  String ar = 'nameAr',
  String en = 'nameEn',
}) {
  if (m == null) return null;
  String? clean(Object? v) {
    final s = v is String ? v.trim() : null;
    return (s == null || s.isEmpty) ? null : s;
  }

  final a = clean(m[ar]);
  final e = clean(m[en]);
  return languageCode == 'ar' ? (a ?? e) : (e ?? a);
}

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;
num? _num(Object? v) => v is num ? v : null;
Map<String, dynamic>? _map(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : null;

/// Status groups the server filters by (`state=`).
enum LeaveState { all, open, approved, rejected, cancelled }

/// One leave request as the list returns it.
class LeaveItem {
  const LeaveItem(this.json);
  final Map<String, dynamic> json;

  int get id => (json['id'] as num).toInt();
  Map<String, dynamic>? get _type => _map(json['type']);
  Map<String, dynamic>? get _status => _map(json['status']);
  Map<String, dynamic>? get _days => _map(json['days']);

  String typeName(String lang) => pickName(_type, lang) ?? '';
  String statusName(String lang) => pickName(_status, lang) ?? '';
  int get statusId => (_status?['id'] as num?)?.toInt() ?? 0;

  /// 1 new, 2 pending, 3 in progress, 4 approved, 5 rejected, 6 cancelled.
  bool get isApproved => statusId == 4;
  bool get isRejected => statusId == 5;
  bool get isCancelled => statusId == 6;
  bool get isOpen => statusId == 1 || statusId == 2 || statusId == 3;

  DateTime? get start => _date(json['startDate']);
  DateTime? get end => _date(json['endDate']);
  DateTime? get requestDate => _date(json['requestDate']);
  DateTime? get returnDate => _date(json['returnDate']);
  String? get requestNo => json['requestNo'] as String?;
  num? get totalDays => _num(_days?['total']);
  num? get weekendDays => _num(_days?['weekend']);
  num? get holidayDays => _num(_days?['holidays']);
  num? get workingDays => _num(_days?['working']);
  bool get isHalfDay => json['isHalfDay'] == true;
  String? get reason {
    final r = (json['reason'] as String?)?.trim();
    return (r == null || r.isEmpty) ? null : r;
  }

  String? stage(String lang) => pickName(_map(json['currentStage']), lang);
  String? statusReason(String lang) {
    final r = _map(json['statusReason']);
    return pickName(r, lang) ?? (r?['text'] as String?)?.trim();
  }

  String? substitute(String lang) => pickName(_map(json['substitute']), lang);
}

class LeaveList {
  const LeaveList({
    required this.items,
    required this.total,
    required this.hasMore,
    required this.summary,
  });
  final List<LeaveItem> items;
  final int total;
  final bool hasMore;

  /// total / open / approved / rejected / cancelled, over all states.
  final Map<String, int> summary;
}

/// One step of the approval chain of a request.
class ApprovalStep {
  const ApprovalStep(this.json);
  final Map<String, dynamic> json;
  String name(String lang) => pickName(json, lang) ?? '';
  String get status => (json['status'] as String?) ?? '';
  DateTime? get date => _date(json['date']);
  String? approver(String lang) => pickName(_map(json['approver']), lang);
}

class LeaveDetail {
  const LeaveDetail({required this.request, required this.stages});
  final LeaveItem request;
  final List<ApprovalStep> stages;
}

/// The balances of one year.
class LeaveBalances {
  const LeaveBalances({required this.year, required this.years, this.data});
  final int year;
  final List<int> years;

  /// Null when the employee has no balance row for [year].
  final Map<String, dynamic>? data;

  num? _v(String g, String k) => _num(_map(data?[g])?[k]);

  num? get annualRemaining => _v('annual', 'remaining');
  num? get annualTotalAvailable => _v('annual', 'totalAvailable');
  num? get annualEntitlement => _v('annual', 'entitlement');
  num? get annualCarried => _v('annual', 'carriedForward');
  num? get annualUsed => _v('annual', 'used');
  num? get casualRemaining => _v('casual', 'remaining');
  num? get casualEntitlement => _v('casual', 'entitlement');
  num? get casualUsed => _v('casual', 'used');
}

/// A leave type the employee can request from the app (`GET types`), with the
/// rules the form needs.
class LeaveTypeInfo {
  const LeaveTypeInfo(this.json);
  final Map<String, dynamic> json;

  int get id => (json['id'] as num).toInt();
  String name(String lang) => pickName(json, lang) ?? '';
  bool get allowHalfDay => json['allowHalfDay'] == true;
  bool get requiresReason =>
      json['requiresReason'] == true || json['requiresDocument'] == true;
  bool get deductsBalance => json['deductsBalance'] == true;
  int get advanceNoticeDays => (_num(json['advanceNoticeDays']) ?? 0).toInt();
  num? get maxDaysPerRequest => _num(json['maxDaysPerRequest']);

  /// Days left this year for the types that are counted (annual, casual).
  num? get remaining => _num(json['remaining']);
}

/// What the employee filled in. Dates are calendar days (no time).
class LeaveDraft {
  const LeaveDraft({
    required this.typeId,
    required this.start,
    required this.end,
    this.halfDayType,
    this.reason,
  });
  final int typeId;
  final DateTime start;
  final DateTime end;

  /// 1 first half, 2 second half; null for a full day.
  final int? halfDayType;
  final String? reason;

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
    'typeId': typeId,
    'startDate': _ymd(start),
    'endDate': _ymd(end),
    'halfDayType': ?halfDayType,
    if (reason != null && reason!.trim().isNotEmpty) 'reason': reason!.trim(),
  };
}

/// The server's count of a draft (`POST requests/preview`): nothing is saved.
class LeavePreview {
  const LeavePreview(this.json);
  final Map<String, dynamic> json;

  Map<String, dynamic>? get _days => _map(json['days']);
  Map<String, dynamic>? get _balance => _map(json['balance']);

  num get totalDays => _num(_days?['total']) ?? 0;
  num get weekendDays => _num(_days?['weekend']) ?? 0;
  num get holidayDays => _num(_days?['holidays']) ?? 0;
  num get workingDays => _num(_days?['working']) ?? 0;
  num get deductedDays => _num(_days?['deducted']) ?? 0;
  DateTime? get returnDate => _date(json['returnDate']);
  num? get balanceBefore => _num(_balance?['before']);
  num? get balanceAfter => _num(_balance?['after']);
}

/// The leave calls of the company server (module `MobileLeave`).
abstract interface class LeaveApi {
  Future<LeaveList> requests({
    LeaveState state = LeaveState.all,
    int? year,
    int limit = 20,
    int offset = 0,
  });
  Future<LeaveDetail> request(int id);
  Future<LeaveBalances> balances({int? year});

  /// The types allowed from the app.
  Future<List<LeaveTypeInfo>> types();

  /// Counts the days and checks the rules; throws [AuthException] with the
  /// server's message (ar/en) when a rule fails. Saves nothing.
  Future<LeavePreview> preview(LeaveDraft draft);

  /// Sends the request; returns it as the server stored it.
  Future<LeaveItem> create(LeaveDraft draft);
}

class HttpLeaveApi implements LeaveApi {
  HttpLeaveApi({
    required String baseUrl,
    required this.token,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : _base = '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/mobile/leave/v1',
       _client = client;

  final String _base;
  final String token;
  final Duration timeout;
  final http.Client? _client;

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, String>? query,
  ]) => _send('GET', path, query: query);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse(
      '$_base/$path',
    ).replace(queryParameters: query == null || query.isEmpty ? null : query);
    if (uri.scheme != 'https') throw const AuthException.network();
    final client = _client ?? http.Client();
    try {
      final request = http.Request(method, uri)
        ..followRedirects = false
        ..headers.addAll({
          'Accept': 'application/json',
          'User-Agent': 'LockSysHR/1.0',
          'Authorization': 'Bearer $token',
          if (body != null) 'Content-Type': 'application/json; charset=utf-8',
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
        throw AuthException(
          code: error['code'] as String? ?? 'ERROR',
          messageAr: error['message_ar'] as String? ?? '',
          messageEn: error['message_en'] as String? ?? '',
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
  Future<LeaveList> requests({
    LeaveState state = LeaveState.all,
    int? year,
    int limit = 20,
    int offset = 0,
  }) async {
    final d = await _get('requests', {
      'state': state.name,
      'year': ?year?.toString(),
      'limit': '$limit',
      'offset': '$offset',
    });
    final paging = _map(d['paging']) ?? const {};
    final summary = _map(d['summary']) ?? const {};
    return LeaveList(
      items: [
        for (final i in (d['items'] as List? ?? const []))
          LeaveItem((i as Map).cast<String, dynamic>()),
      ],
      total: (paging['total'] as num?)?.toInt() ?? 0,
      hasMore: paging['hasMore'] == true,
      summary: {
        for (final e in summary.entries) e.key: (e.value as num?)?.toInt() ?? 0,
      },
    );
  }

  @override
  Future<LeaveDetail> request(int id) async {
    final d = await _get('requests/$id');
    return LeaveDetail(
      request: LeaveItem(_map(d['request'])!),
      stages: [
        for (final s in (d['approvalStages'] as List? ?? const []))
          ApprovalStep((s as Map).cast<String, dynamic>()),
      ],
    );
  }

  @override
  Future<LeaveBalances> balances({int? year}) async {
    final d = await _get('balances', {'year': ?year?.toString()});
    return LeaveBalances(
      year: (d['year'] as num).toInt(),
      years: [
        for (final y in (d['years'] as List? ?? const [])) (y as num).toInt(),
      ],
      data: _map(d['balance']),
    );
  }

  @override
  Future<List<LeaveTypeInfo>> types() async {
    final d = await _get('types');
    return [
      for (final t in (d['items'] as List? ?? const []))
        LeaveTypeInfo((t as Map).cast<String, dynamic>()),
    ];
  }

  @override
  Future<LeavePreview> preview(LeaveDraft draft) async => LeavePreview(
    await _send('POST', 'requests/preview', body: draft.toJson()),
  );

  @override
  Future<LeaveItem> create(LeaveDraft draft) async {
    final d = await _send('POST', 'requests', body: draft.toJson());
    return LeaveItem(_map(d['request'])!);
  }
}

/// Development stand-in (tests, running without a server): a few fixed requests
/// and balances.
class MockLeaveApi implements LeaveApi {
  const MockLeaveApi();

  static LeaveItem _item(
    int id,
    int status,
    String nameAr,
    String nameEn,
    String start,
    String end,
    num days,
  ) => LeaveItem({
    'id': id,
    'type': {'id': 3, 'nameAr': nameAr, 'nameEn': nameEn},
    'status': {
      'id': status,
      'nameAr': status == 4 ? 'معتمد' : 'قيد الانتظار',
      'nameEn': status == 4 ? 'Approved' : 'Pending',
    },
    'startDate': start,
    'endDate': end,
    'requestDate': start,
    'days': {'total': days},
  });

  @override
  Future<LeaveList> requests({
    LeaveState state = LeaveState.all,
    int? year,
    int limit = 20,
    int offset = 0,
  }) async {
    final all = [
      _item(1, 2, 'سنوية', 'Annual', '2026-10-12', '2026-10-14', 3),
      _item(2, 4, 'عارضة', 'Casual', '2026-09-02', '2026-09-02', 1),
    ];
    final items = [
      for (final i in all)
        if (state == LeaveState.all ||
            (state == LeaveState.open && i.isOpen) ||
            (state == LeaveState.approved && i.isApproved))
          i,
    ];
    return LeaveList(
      items: items,
      total: items.length,
      hasMore: false,
      summary: const {'total': 2, 'open': 1, 'approved': 1},
    );
  }

  @override
  Future<LeaveDetail> request(int id) async => LeaveDetail(
    request: (await requests()).items.firstWhere((i) => i.id == id),
    stages: const [],
  );

  static const _types = [
    LeaveTypeInfo({
      'id': 3,
      'nameAr': 'سنوية',
      'nameEn': 'Annual',
      'allowHalfDay': true,
      'deductsBalance': true,
      'advanceNoticeDays': 7,
      'remaining': 18,
    }),
    LeaveTypeInfo({
      'id': 24,
      'nameAr': 'عارضة',
      'nameEn': 'Casual',
      'allowHalfDay': true,
      'deductsBalance': true,
      'remaining': 4,
    }),
    LeaveTypeInfo({
      'id': 142,
      'nameAr': 'بدل يعوض',
      'nameEn': 'Compensatory',
      'maxDaysPerRequest': 1,
    }),
  ];

  @override
  Future<List<LeaveTypeInfo>> types() async => _types;

  @override
  Future<LeavePreview> preview(LeaveDraft draft) async {
    final days = draft.halfDayType != null
        ? .5
        : draft.end.difference(draft.start).inDays + 1;
    final type = _types.firstWhere((t) => t.id == draft.typeId);
    final left = type.remaining;
    if (left != null && days > left) {
      throw const AuthException(
        code: 'INSUFFICIENT_BALANCE',
        messageAr: 'رصيدك لا يكفي',
        messageEn: 'Not enough balance',
      );
    }
    return LeavePreview({
      'days': {
        'total': days,
        'weekend': 0,
        'holidays': 0,
        'working': days,
        'deducted': days,
      },
      'returnDate': draft.end.add(const Duration(days: 1)).toIso8601String(),
      if (left != null) 'balance': {'before': left, 'after': left - days},
    });
  }

  @override
  Future<LeaveItem> create(LeaveDraft draft) async {
    await preview(draft);
    final type = _types.firstWhere((t) => t.id == draft.typeId);
    final days = draft.halfDayType != null
        ? .5
        : draft.end.difference(draft.start).inDays + 1;
    return LeaveItem({
      'id': 99,
      'type': {
        'id': type.id,
        'nameAr': type.json['nameAr'],
        'nameEn': type.json['nameEn'],
      },
      'status': {'id': 2, 'nameAr': 'قيد الانتظار', 'nameEn': 'Pending'},
      'startDate': draft.start.toIso8601String(),
      'endDate': draft.end.toIso8601String(),
      'days': {'total': days},
    });
  }

  @override
  Future<LeaveBalances> balances({int? year}) async => LeaveBalances(
    year: 2026,
    years: const [2026],
    data: const {
      'annual': {
        'carriedForward': 5,
        'entitlement': 21,
        'totalAvailable': 26,
        'used': 8,
        'remaining': 18,
      },
      'casual': {'entitlement': 6, 'used': 2, 'remaining': 4},
    },
  );
}
