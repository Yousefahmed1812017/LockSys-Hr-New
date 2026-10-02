import 'package:flutter/material.dart';

import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_chips.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_screen.dart';
import '../../core/widgets/app_skeleton.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_api.dart';
import 'leave_api.dart';

/// What is left of each leave type for a year: annual (navy card with the share
/// left) and casual. A year chip row appears when the
/// employee has balances for more than one year.
class MyBalancesPage extends StatefulWidget {
  const MyBalancesPage({super.key, required this.api});
  final LeaveApi api;

  @override
  State<MyBalancesPage> createState() => _MyBalancesPageState();
}

class _MyBalancesPageState extends State<MyBalancesPage> {
  LeaveBalances? _data;
  bool _loading = true;
  AuthException? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int? year}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.balances(year: year);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final data = _data;
    final Widget body;
    if (_loading) {
      body = const Padding(
        padding: EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          children: [
            AppSkeletonCard(height: 150),
            SizedBox(height: AppSpacing.s3),
            AppSkeletonCard(height: 90),
            SizedBox(height: AppSpacing.s3),
            AppSkeletonCard(height: 120),
          ],
        ),
      );
    } else if (_error != null || data == null) {
      body = SizedBox(
        height: 360,
        child: AppEmptyState.offline(onAction: () => _load(year: data?.year)),
      );
    } else if (data.data == null) {
      body = SizedBox(
        height: 320,
        child: AppEmptyState.empty(
          title: l.balNoneTitle,
          message: l.balNoneMessage,
        ),
      );
    } else {
      body = Padding(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: _Balances(data: data, l: l),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppTopBar(showBack: true, title: l.balTitle),
      body: ListView(
        children: [
          AppScreenIntro(l.balSubtitle),
          const SizedBox(height: 4),
          if (data != null && data.years.length > 1)
            AppChipRow(
              labels: [for (final y in data.years) '$y'],
              selectedIndex: data.years.indexOf(data.year).clamp(0, 99),
              onSelected: (i) => _load(year: data.years[i]),
            ),
          body,
        ],
      ),
    );
  }
}

class _Balances extends StatelessWidget {
  const _Balances({required this.data, required this.l});
  final LeaveBalances data;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppReveal(
          index: 0,
          child: _BalanceCard(
            title: l.artAnnualLeave,
            remaining: d.annualRemaining,
            total: d.annualTotalAvailable,
            figures: [
              (l.balCarried, d.annualCarried),
              (l.balEntitlement, d.annualEntitlement),
              (l.balUsed, d.annualUsed),
            ],
            l: l,
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        AppReveal(
          index: 1,
          child: _BalanceCard(
            title: l.leaveEmergency,
            remaining: d.casualRemaining,
            total: d.casualEntitlement,
            figures: [
              (l.balEntitlement, d.casualEntitlement),
              (l.balUsed, d.casualUsed),
            ],
            l: l,
          ),
        ),
      ],
    );
  }
}

/// Thin bar: the share of the days that is left.
class _Bar extends StatelessWidget {
  const _Bar({required this.share, this.onNavy = false});
  final double share;
  final bool onNavy;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(3),
    child: Container(
      height: 6,
      color: onNavy ? Colors.white.withValues(alpha: .16) : AppColors.blue50,
      alignment: AlignmentDirectional.centerStart,
      child: FractionallySizedBox(
        widthFactor: share.clamp(0, 1).toDouble(),
        child: Container(color: AppColors.blueBright),
      ),
    ),
  );
}

double _share(num? left, num? total) =>
    (total == null || total <= 0 || left == null)
    ? 0
    : (left / total).toDouble();

/// A leave type as a navy card: the type's name, the days left, a bar, and the
/// figures centered below. Annual and casual share this look.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.title,
    required this.remaining,
    required this.total,
    required this.figures,
    required this.l,
  });
  final String title;
  final num? remaining;

  /// What the bar is measured against (the days available).
  final num? total;
  final List<(String, num?)> figures;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final left = remaining ?? 0;
    final muted = AppText.xs.copyWith(color: AppColors.onNavyMuted);
    final line = AppText.small.copyWith(
      color: Colors.white,
      fontSize: 15,
      fontWeight: FontWeight.w600,
    );
    Widget figure(String label, num? v) => Expanded(
      child: Column(
        children: [
          Text(
            v == null ? '-' : _plain(v),
            textDirection: TextDirection.ltr,
            style: AppText.h3.copyWith(color: Colors.white),
          ),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: muted,
          ),
        ],
      ),
    );
    return AppCard(
      navy: true,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name and remaining days share one size and color; only the
          // number sits on a small background.
          Text(title, style: line),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.blue,
                  borderRadius: BorderRadius.circular(AppRadius.xs + 2),
                ),
                child: Text(
                  _plain(left),
                  textDirection: TextDirection.ltr,
                  style: line.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(child: Text(l.balDaysLeft, style: line)),
            ],
          ),
          const SizedBox(height: 8),
          _Bar(share: _share(left, total), onNavy: true),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final (label, v) in figures) figure(label, v)],
          ),
        ],
      ),
    );
  }
}

String _plain(num v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';
