import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/auth_api.dart';
import '../leave/leave_api.dart';

Map<String, dynamic>? _map(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : null;

/// Which part of "my approvals" to show.
enum ApprovalTab { waiting, later, done }

/// A leave request that is (or was) waiting for MY decision: my stage of the
/// approval chain, the request itself and who asked.
class ApprovalItem {
  const ApprovalItem(this.json);
  final Map<String, dynamic> json;

  int get requestId => (json['requestId'] as num).toInt();
  Map<String, dynamic>? get _stage => _map(json['stage']);

  LeaveItem get request => LeaveItem(_map(json['request']) ?? const {});

  String stageName(String lang) => pickName(_stage, lang) ?? '';

  /// PENDING, APPROVED or REJECTED: my stage.
  String get stageStatus => (_stage?['status'] as String?) ?? '';
  String? get stageNotes {
    final n = (_stage?['notes'] as String?)?.trim();
    return (n == null || n.isEmpty) ? null : n;
  }

  /// My turn: pending, nobody before me still to decide, request still open.
  bool get canDecide => json['canDecide'] == true;

  String requesterName(String lang) =>
      pickName(_map(json['requester']), lang) ?? '';

  /// Who has to decide before me (the "later" tab), as "stage - person".
  String? waitingFor(String lang) {
    final w = _map(json['waitingFor']);
    if (w == null) return null;
    final person = pickName(w, lang);
    final stage = pickName(w, lang, ar: 'stageAr', en: 'stageEn');
    return [person, stage].whereType<String>().join(' · ');
  }
}

class ApprovalList {
  const ApprovalList({
    required this.items,
    required this.total,
    required this.hasMore,
    required this.summary,
  });
  final List<ApprovalItem> items;
  final int total;
  final bool hasMore;

  /// waiting / later / done, over every tab (for the numbers on the chips).
  final Map<String, int> summary;
}

/// One approval with the whole chain of the request.
class ApprovalDetail {
  const ApprovalDetail({required this.item, required this.stages});
  final ApprovalItem item;
  final List<ApprovalStep> stages;
}

/// The approvals calls of the company server (module `MobileApprovals`).
abstract interface class ApprovalsApi {
  Future<ApprovalList> items({
    ApprovalTab tab = ApprovalTab.waiting,
    int limit = 20,
    int offset = 0,
  });
  Future<ApprovalDetail> detail(int requestId);

  /// Approves or rejects my stage. [notes] is required to reject. Throws
  /// [AuthException] with the server's message (`WAIT_PREVIOUS`, ...).
  Future<ApprovalItem> decide(
    int requestId, {
    required bool approve,
    String? notes,
  });
}

class HttpApprovalsApi implements ApprovalsApi {
  HttpApprovalsApi({
    required String baseUrl,
    required this.token,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : _base =
           '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/mobile/approvals/v1',
       _client = client;

  final String _base;
  final String token;
  final Duration timeout;
  final http.Client? _client;

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
  Future<ApprovalList> items({
    ApprovalTab tab = ApprovalTab.waiting,
    int limit = 20,
    int offset = 0,
  }) async {
    final d = await _send(
      'GET',
      'items',
      query: {'tab': tab.name, 'limit': '$limit', 'offset': '$offset'},
    );
    final paging = _map(d['paging']) ?? const {};
    final summary = _map(d['summary']) ?? const {};
    return ApprovalList(
      items: [
        for (final i in (d['items'] as List? ?? const []))
          ApprovalItem((i as Map).cast<String, dynamic>()),
      ],
      total: (paging['total'] as num?)?.toInt() ?? 0,
      hasMore: paging['hasMore'] == true,
      summary: {
        for (final e in summary.entries) e.key: (e.value as num?)?.toInt() ?? 0,
      },
    );
  }

  @override
  Future<ApprovalDetail> detail(int requestId) async {
    final d = await _send('GET', 'items/$requestId');
    return ApprovalDetail(
      item: ApprovalItem(_map(d['item'])!),
      stages: [
        for (final s in (d['approvalStages'] as List? ?? const []))
          ApprovalStep((s as Map).cast<String, dynamic>()),
      ],
    );
  }

  @override
  Future<ApprovalItem> decide(
    int requestId, {
    required bool approve,
    String? notes,
  }) async {
    final d = await _send(
      'POST',
      'items/$requestId/${approve ? 'approve' : 'reject'}',
      body: {
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    return ApprovalItem(_map(d['item'])!);
  }
}

/// Development stand-in (tests, running without a server).
class MockApprovalsApi implements ApprovalsApi {
  const MockApprovalsApi();

  static ApprovalItem _item(
    int id,
    String status, {
    bool canDecide = true,
    Map<String, dynamic>? waitingFor,
  }) => ApprovalItem({
    'requestId': id,
    'stage': {
      'code': 'DIRECT_MANAGER',
      'nameAr': 'المدير المباشر',
      'nameEn': 'Direct Manager',
      'order': 2,
      'status': status,
    },
    'canDecide': canDecide,
    'requester': {'nameAr': 'سارة أحمد', 'nameEn': 'Sara Ahmed'},
    'waitingFor': waitingFor,
    'request': {
      'id': id,
      'type': {'id': 3, 'nameAr': 'سنوية', 'nameEn': 'Annual'},
      'status': {'id': 2, 'nameAr': 'قيد الانتظار', 'nameEn': 'Pending'},
      'startDate': '2026-11-02',
      'endDate': '2026-11-04',
      'requestDate': '2026-10-01',
      'days': {'total': 3, 'working': 3},
      'reason': 'سفر',
    },
  });

  @override
  Future<ApprovalList> items({
    ApprovalTab tab = ApprovalTab.waiting,
    int limit = 20,
    int offset = 0,
  }) async {
    final list = switch (tab) {
      ApprovalTab.waiting => [_item(1, 'PENDING')],
      ApprovalTab.later => [
        _item(
          2,
          'PENDING',
          canDecide: false,
          waitingFor: const {
            'nameAr': 'مينا',
            'nameEn': 'Mina',
            'stageAr': 'المدير المباشر',
            'stageEn': 'Direct Manager',
          },
        ),
      ],
      ApprovalTab.done => [_item(3, 'APPROVED', canDecide: false)],
    };
    return ApprovalList(
      items: list,
      total: list.length,
      hasMore: false,
      summary: const {'waiting': 1, 'later': 1, 'done': 1},
    );
  }

  @override
  Future<ApprovalDetail> detail(int requestId) async => ApprovalDetail(
    item: _item(requestId, 'PENDING'),
    stages: const [
      ApprovalStep({
        'nameAr': 'المدير المباشر',
        'nameEn': 'Direct Manager',
        'status': 'PENDING',
        'approver': {'nameAr': 'أنا', 'nameEn': 'Me'},
      }),
    ],
  );

  @override
  Future<ApprovalItem> decide(
    int requestId, {
    required bool approve,
    String? notes,
  }) async =>
      _item(requestId, approve ? 'APPROVED' : 'REJECTED', canDecide: false);
}
