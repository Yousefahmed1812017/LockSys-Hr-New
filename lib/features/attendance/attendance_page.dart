import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/icons/app_icons.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_alert.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_list.dart';
import '../../core/widgets/app_overlays.dart';
import '../../core/widgets/app_screen.dart';
import '../../core/widgets/app_skeleton.dart';
import '../../core/widgets/app_square_tile.dart';
import 'attendance_api.dart';
import 'attendance_state.dart';
import 'check_in_flow_page.dart';
import 'month_summary_page.dart';

/// Attendance hub, opened from the home grid: three squares like the home screen.
///   Check-in      -> the employee's sites; a site opens its own screen
///   Month summary -> (screen to come)
///   Absence       -> (screen to come)
class AttendancePage extends StatelessWidget {
  const AttendancePage({super.key});

  void _openCheckIn(BuildContext context) {
    final controller = AttendanceScope.of(context);
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AttendanceScope(
          controller: controller,
          child: const AttendanceCheckInPage(),
        ),
      ),
    );
  }

  void _openMonth(BuildContext context) {
    final api = AttendanceScope.of(context).api;
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => MonthSummaryPage(api: api)));
  }

  void _soon(BuildContext context) =>
      AppSnackbar.show(context, context.l10n.comingSoon, tone: AppTone.info);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppTopBar(showBack: true, title: l.attendanceTitle),
      body: ListView(
        children: [
          AppScreenIntro(l.attendanceHubSubtitle),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppSquareTile(
                    icon: AppIcons.fingerprint,
                    label: l.attTileCheckIn,
                    onTap: () => _openCheckIn(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppSquareTile(
                    icon: AppIcons.calendar,
                    label: l.attTileMonth,
                    onTap: () => _openMonth(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppSquareTile(
                    icon: AppIcons.warning,
                    label: l.attTileAbsence,
                    onTap: () => _soon(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The check-in screen: [AttendanceTab] under a top bar with its own title.
class AttendanceCheckInPage extends StatelessWidget {
  const AttendanceCheckInPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppTopBar(showBack: true, title: context.l10n.attTileCheckIn),
    body: const AttendanceTab(),
  );
}

/// The employee's sites, as big cards. A card shows where the day stands at that
/// site; tapping it opens the site ([AttendanceSitePage]). Everything comes from
/// the server through [AttendanceController].
class AttendanceTab extends StatefulWidget {
  const AttendanceTab({super.key});

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final c = AttendanceScope.of(context);
    // After this frame: load() tells the listeners, which cannot happen mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) => c.load());
  }

  void _open(AttendanceController c, AttendanceSite site) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AttendanceScope(
          controller: c,
          child: AttendanceSitePage(siteId: site.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = AttendanceScope.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final locale = Localizations.localeOf(context).toString();
    final date = toWesternDigits(
      DateFormat.yMMMMEEEEd(locale).format(DateTime.now()),
    );
    final today = c.today;
    final Widget body;
    if (today == null && c.loading) {
      body = const Padding(
        padding: EdgeInsets.all(AppSpacing.gutter),
        child: _Skeleton(),
      );
    } else if (today == null) {
      body = SizedBox(
        height: 360,
        child: AppEmptyState.offline(onAction: c.load),
      );
    } else if (!today.allowed) {
      body = SizedBox(
        height: 320,
        child: AppEmptyState(
          icon: AppIcons.lock,
          tone: AppTone.warning,
          title: l.attNotEnabledTitle,
          message: l.attNotEnabledMsg,
        ),
      );
    } else {
      body = Padding(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (kDebugMode && c.simulated) ...[
              _DesignPreview(controller: c),
              const SizedBox(height: AppSpacing.s4),
            ],
            if (today.sites.isEmpty)
              AppAlert(
                title: l.attNoSitesTitle,
                message: l.attNoSitesMsg,
                tone: AppTone.warning,
              )
            else
              for (var i = 0; i < today.sites.length; i++) ...[
                AppReveal(
                  index: i,
                  child: _SiteCard(
                    site: today.sites[i],
                    today: today,
                    lang: lang,
                    onTap: () => _open(c, today.sites[i]),
                  ),
                ),
                const SizedBox(height: AppSpacing.s3),
              ],
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: c.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [AppScreenIntro(date), body],
      ),
    );
  }
}

/// A site as a big card: its name in full, its work areas, where the day stands
/// there (not checked in / checked in at / checked out at) and what a tap does.
class _SiteCard extends StatelessWidget {
  const _SiteCard({
    required this.site,
    required this.today,
    required this.lang,
    required this.onTap,
  });
  final AttendanceSite site;
  final AttendanceToday today;
  final String lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (label, tone, status) = switch (site.action) {
      'OUT' => (
        l.checkOut,
        AppTone.warning,
        l.checkedInAtTime(today.checkInAt ?? '--:--'),
      ),
      'DONE' => (
        l.attLeftBadge,
        AppTone.muted,
        l.checkedOutAtTime(today.checkOutAt ?? '--:--'),
      ),
      _ => (l.checkIn, AppTone.success, l.notCheckedIn),
    };
    final areas = site.areas
        .map((a) => a.name(lang))
        .where((n) => n.isNotEmpty)
        .join(' · ');
    return AppCard(
      showMark: false,
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIconTile(AppIcons.location, tone: tone, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(site.name(lang), style: AppText.h3),
                    if (areas.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(areas, style: AppText.small),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text(status, style: AppText.small)),
              const SizedBox(width: 8),
              // Flexible: with large text the badge shortens instead of overflowing.
              Flexible(child: AppBadge(label, tone: tone)),
            ],
          ),
        ],
      ),
    );
  }
}

/// One site: where the day stands (the navy card: checked in at, checked out at,
/// time worked), its work areas, and the one button (check in, check out, or the
/// message that the employee already left).
class AttendanceSitePage extends StatelessWidget {
  const AttendanceSitePage({super.key, required this.siteId});
  final int siteId;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = AttendanceScope.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final today = c.today;
    final site = today?.sites.where((s) => s.id == siteId).firstOrNull;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppTopBar(
        showBack: true,
        title: site?.name(lang) ?? l.attTileCheckIn,
      ),
      body: site == null || today == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              children: [
                AppReveal(index: 0, child: _Hero(controller: c)),
                if (site.areas.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.s5),
                  AppReveal(
                    index: 1,
                    child: Text(l.attAreasTitle, style: AppText.h3),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  AppReveal(
                    index: 1,
                    child: AppListGroup(
                      children: [
                        for (final a in site.areas)
                          AppListTile(
                            leading: const AppIconTile(AppIcons.location),
                            title: a.name(lang),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.s5),
                AppReveal(
                  index: 2,
                  child: site.action == 'DONE'
                      ? AppAlert(
                          title: today.message(lang) ?? l.attLeftBadge,
                          tone: AppTone.info,
                        )
                      : AppButton(
                          label: site.action == 'OUT' ? l.checkOut : l.checkIn,
                          size: AppButtonSize.lg,
                          leadingIcon: c.mode.usesFace
                              ? AppIcons.user
                              : AppIcons.location,
                          onPressed: () => Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => CheckInFlowPage(
                                controller: c,
                                site: site,
                                checkingOut: site.action == 'OUT',
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AppSkeletonCard(height: 150),
      SizedBox(height: AppSpacing.s3),
      AppSkeletonCard(height: 150),
    ],
  );
}

/// The single navy card: where today stands (status, time worked, in and out).
class _Hero extends StatelessWidget {
  const _Hero({required this.controller});
  final AttendanceController controller;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = controller;
    final muted = AppText.small.copyWith(color: AppColors.onNavyMuted);
    final status = c.isDone
        ? l.checkedOutAtTime(formatClock(c.checkOutAt!))
        : c.isCheckedIn
        ? l.checkedInAtTime(formatClock(c.checkInAt!))
        : l.notCheckedIn;
    Widget figure(String label, String value) => Expanded(
      child: Column(
        children: [
          Text(
            value,
            textDirection: TextDirection.ltr,
            style: AppText.h2.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: muted),
        ],
      ),
    );
    return AppCard(
      navy: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(status, style: muted),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatDuration(c.worked ?? Duration.zero),
                textDirection: TextDirection.ltr,
                style: AppText.stat.copyWith(color: Colors.white, fontSize: 36),
              ),
              const SizedBox(width: 10),
              Flexible(child: Text(l.workedLabel, style: muted)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              figure(
                l.attInTime,
                c.checkInAt == null ? '--:--' : formatClock(c.checkInAt!),
              ),
              figure(
                l.attOutTime,
                c.checkOutAt == null ? '--:--' : formatClock(c.checkOutAt!),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Design preview (debug builds with the stand-in server only): try every mode
/// and every blocking screen without changing the phone. Not part of the product.
class _DesignPreview extends StatelessWidget {
  const _DesignPreview({required this.controller});
  final AttendanceController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    Widget row(String label, Widget chips) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.xs),
        const SizedBox(height: 4),
        chips,
        const SizedBox(height: 8),
      ],
    );
    Widget chips<T>(List<(String, T)> items, T selected, void Function(T) on) =>
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (label, value) in items)
              ChoiceChip(
                label: Text(label, style: AppText.xs),
                selected: value == selected,
                onSelected: (_) => on(value),
              ),
          ],
        );
    return AppCard(
      showMark: false,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Design preview (debug only)', style: AppText.small),
          const SizedBox(height: 8),
          row(
            'Employee mode',
            chips<AttendanceMode>(
              const [
                ('Face + location', AttendanceMode.faceAndLocation),
                ('Face', AttendanceMode.face),
                ('Location', AttendanceMode.location),
              ],
              c.mode,
              c.selectMode,
            ),
          ),
          row(
            'Phone problem',
            chips<DeviceProblem>(
              const [
                ('None', DeviceProblem.none),
                ('Location off', DeviceProblem.locationOff),
                ('No permission', DeviceProblem.permissionDenied),
                ('Fake location', DeviceProblem.mockLocation),
                ('VPN', DeviceProblem.vpn),
                ('Developer options', DeviceProblem.developerOptions),
              ],
              c.device,
              c.selectDevice,
            ),
          ),
          row(
            'Company policy for a fake location',
            chips<String>(
              const [('Block it', 'BLOCK'), ('Record it', 'RECORD')],
              c.mockPolicy,
              c.selectMockPolicy,
            ),
          ),
          row(
            'Position',
            chips<bool>(
              const [('Inside the area', false), ('Outside the area', true)],
              c.outside,
              c.setOutside,
            ),
          ),
        ],
      ),
    );
  }
}
