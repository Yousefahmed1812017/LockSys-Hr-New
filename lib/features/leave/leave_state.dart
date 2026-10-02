import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';

enum LeaveType { annual, sick, emergency, unpaid }

extension LeaveTypeX on LeaveType {
  String label(AppLocalizations l) => switch (this) {
    LeaveType.annual => l.artAnnualLeave,
    LeaveType.sick => l.leaveSick,
    LeaveType.emergency => l.leaveEmergency,
    LeaveType.unpaid => l.leaveUnpaid,
  };

  /// Days a year; null = no limit.
  int? get yearly => switch (this) {
    LeaveType.annual => 30,
    LeaveType.sick => 15,
    LeaveType.emergency => 6,
    LeaveType.unpaid => null,
  };
}

enum LeaveStatus { pending, approved, rejected }

extension LeaveStatusX on LeaveStatus {
  String label(AppLocalizations l) => switch (this) {
    LeaveStatus.pending => l.statusPending,
    LeaveStatus.approved => l.statusApproved,
    LeaveStatus.rejected => l.statusRejected,
  };

  AppTone get tone => switch (this) {
    LeaveStatus.pending => AppTone.warning,
    LeaveStatus.approved => AppTone.success,
    LeaveStatus.rejected => AppTone.danger,
  };
}

class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.type,
    required this.from,
    required this.to,
    required this.status,
    required this.submittedAt,
    this.reason,
  });

  final int id;
  final LeaveType type;
  final DateTime from;
  final DateTime to;
  final LeaveStatus status;
  final DateTime submittedAt;
  final String? reason;

  /// Calendar days from [from] to [to], both included.
  int get days => daysBetween(from, to);
}

int daysBetween(DateTime from, DateTime to) =>
    DateTime(
      to.year,
      to.month,
      to.day,
    ).difference(DateTime(from.year, from.month, from.day)).inDays +
    1;

/// Leave balances and requests, shared by the home tile, the leave tab and the
/// request form.
///
/// Simulated: a few fixed requests and balances. The real version loads them
/// from the API and posts new requests and cancellations.
class LeaveController extends ChangeNotifier {
  LeaveController({DateTime? today})
    : _requests = _sample(today ?? DateTime.now());

  /// Days already taken this year (approved), by type.
  static const _used = {
    LeaveType.annual: 12,
    LeaveType.sick: 3,
    LeaveType.emergency: 3,
    LeaveType.unpaid: 0,
  };

  final List<LeaveRequest> _requests;

  List<LeaveRequest> get requests => List.unmodifiable(_requests);
  int get pending =>
      _requests.where((r) => r.status == LeaveStatus.pending).length;

  /// Days left of [type] this year, or null when it has no limit.
  int? left(LeaveType type) {
    final yearly = type.yearly;
    return yearly == null ? null : yearly - (_used[type] ?? 0);
  }

  void add(LeaveRequest request) {
    _requests.insert(0, request);
    notifyListeners();
  }

  void cancel(int id) {
    _requests.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  static List<LeaveRequest> _sample(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    LeaveRequest r(
      int id,
      LeaveType type,
      int fromDays,
      int toDays,
      LeaveStatus status,
    ) => LeaveRequest(
      id: id,
      type: type,
      from: today.add(Duration(days: fromDays)),
      to: today.add(Duration(days: toDays)),
      status: status,
      submittedAt: today.subtract(Duration(days: id)),
    );
    return [
      r(1, LeaveType.annual, 10, 12, LeaveStatus.pending),
      r(2, LeaveType.annual, 40, 41, LeaveStatus.pending),
      r(3, LeaveType.sick, -20, -19, LeaveStatus.approved),
      r(4, LeaveType.annual, -60, -56, LeaveStatus.approved),
      r(5, LeaveType.emergency, -90, -90, LeaveStatus.rejected),
    ];
  }
}

class LeaveScope extends InheritedNotifier<LeaveController> {
  const LeaveScope({
    super.key,
    required LeaveController controller,
    required super.child,
  }) : super(notifier: controller);

  static LeaveController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LeaveScope>();
    assert(scope != null, 'LeaveScope not found above this context');
    return scope!.notifier!;
  }
}
