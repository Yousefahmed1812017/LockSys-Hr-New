import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/icons/app_icons.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/app_list.dart';
import '../../core/widgets/app_logo_mark.dart';
import '../../core/widgets/app_overlays.dart';
import '../../core/widgets/app_screen.dart';
import '../../core/widgets/app_skeleton.dart';
import '../../core/widgets/app_square_tile.dart';
import '../../core/widgets/l_pattern.dart';
import '../../core/widgets/pressable.dart';
import '../auth/auth_api.dart';
import '../attendance/attendance_page.dart';
import '../attendance/attendance_api.dart';
import '../attendance/attendance_state.dart';
import '../attendance/location_service.dart';
import '../approvals/approvals_api.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../approvals/approvals_feed.dart';
import 'promo_card.dart';
import '../approvals/approvals_page.dart';
import '../leave/leave_api.dart';
import '../leave/leave_page.dart';
import '../leave/leave_state.dart';
import 'user_profile.dart';

/// Signed-in home. One screen, no tab bar: today's attendance on top, then the
/// services as small squares in three rows. A service opens as its own screen
/// (with a back button); the account opens from the small square at the top end.
/// Today's attendance and the leave requests are shared with those screens
/// through [AttendanceScope] and [LeaveScope] (simulated data for now). The
/// name and the profile come from the sign-in [session]; without one (tests) a
/// sample name is shown.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.onLogout,
    this.session,
    this.leaveApi = const MockLeaveApi(),
    this.attendanceApi,
    this.approvalsApi,
    this.locationService,
  });
  final VoidCallback onLogout;
  final AuthSession? session;

  /// The leave calls of the signed-in employee.
  final LeaveApi leaveApi;

  /// The approvals calls (null: the stand-in).
  final ApprovalsApi? approvalsApi;

  /// The attendance calls and the phone's position (null: the stand-ins).
  final AttendanceApi? attendanceApi;
  final LocationService? locationService;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final _attendance = AttendanceController(
    api: widget.attendanceApi,
    location: widget.locationService,
  );
  final _leave = LeaveController();
  int _tab = 0; // 0 home, 1 approvals, 2 account
  int _approvalsKey =
      0; // a new key reloads the approvals tab when it is opened
  late final _approvals = ApprovalsFeed(
    widget.approvalsApi ?? const MockApprovalsApi(),
  )..reload();

  @override
  void dispose() {
    _approvals.dispose();
    _attendance.dispose();
    _leave.dispose();
    super.dispose();
  }

  /// Opens [page] on top of home. The scopes are re-created around it because a
  /// pushed screen sits above the home in the widget tree.
  void _open(Widget Function(BuildContext context) page) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (ctx) => AttendanceScope(
          controller: _attendance,
          child: LeaveScope(controller: _leave, child: page(ctx)),
        ),
      ),
    );
  }

  /// The approvals screen (or one request of it); the home block is refreshed
  /// when it closes because decisions made there change what is waiting.
  Future<void> _openApprovals([ApprovalItem? item]) async {
    final api = widget.approvalsApi ?? const MockApprovalsApi();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => item == null
            ? ApprovalsPage(api: api)
            : ApprovalDetailPage(api: api, requestId: item.requestId),
      ),
    );
    if (mounted) _approvals.reload();
  }

  void _selectTab(int i) {
    if (i == _tab) return;
    setState(() {
      _tab = i;
      if (i == 1) _approvalsKey++; // fresh list every time it is opened
    });
    if (i == 0) _approvals.reload(); // decisions made on the tab change home
  }

  void _soon() =>
      AppSnackbar.show(context, context.l10n.comingSoon, tone: AppTone.info);

  UserProfile? get _profile => UserProfile.of(
    widget.session,
    Localizations.localeOf(context).languageCode,
  );

  void _openAccount() => _open(
    (ctx) => _AccountPage(
      profile: _profile,
      onLogout: () {
        // Close the account screen first, then leave the signed-in area.
        Navigator.of(ctx).popUntil((route) => route.isFirst);
        widget.onLogout();
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final name = _profile?.name ?? l.sampleName;
    final subtitle = [?_profile?.job, ?_profile?.department].join(' · ');
    // One soft background from the top bar down, no line between them.
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFF1F7FF)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // Only home has the logo bar; the other tabs bring their own title.
        appBar: _tab != 0
            ? null
            : AppTopBar(
                flat: true,
                forceLtr: true,
                leading: Row(
                  children: [
                    const AppLogoMark(height: 34),
                    const SizedBox(width: 10),
                    // Flexible: with the bell and the account beside it, the name
                    // shortens on a narrow phone instead of overflowing.
                    Flexible(
                      child: Text(
                        'LockSys HR',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.ltr,
                        style: AppText.h3.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .3,
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  // The bell carries a dot while something waits for my decision.
                  ListenableBuilder(
                    listenable: _approvals,
                    builder: (_, _) => Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AppIconButton(
                          icon: AppIcons.bell,
                          semanticLabel: l.noticeTitle,
                          onPressed: _approvals.waiting > 0
                              ? _openApprovals
                              : _soon,
                        ),
                        if (_approvals.waiting > 0)
                          const PositionedDirectional(
                            top: 6,
                            end: 6,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.danger,
                                shape: BoxShape.circle,
                                border: Border.fromBorderSide(
                                  BorderSide(color: Colors.white, width: 2),
                                ),
                              ),
                              child: SizedBox(width: 11, height: 11),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Pressable(
                    key: const Key('home-account'),
                    scale: .94,
                    semanticLabel: l.navAccount,
                    onTap: _openAccount,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: 4,
                        end: 4,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.blue, width: 1.5),
                        ),
                        child: AppAvatar(_initials(name), size: 32),
                      ),
                    ),
                  ),
                ],
              ),
        body: IndexedStack(
          index: _tab,
          children: [
            AttendanceScope(
              controller: _attendance,
              child: LeaveScope(
                controller: _leave,
                child: _HomeBody(
                  name: name,
                  subtitle: subtitle.isEmpty ? null : subtitle,
                  onOpenAttendance: () => _open((_) => const AttendancePage()),
                  onOpenLeave: () =>
                      _open((_) => LeavePage(api: widget.leaveApi)),
                  approvals: _approvals,
                  onOpenApprovals: () => _openApprovals(),
                  onOpenApproval: (item) => _openApprovals(item),
                  onSoon: _soon,
                ),
              ),
            ),
            ApprovalsPage(
              key: ValueKey('approvals-tab-$_approvalsKey'),
              api: widget.approvalsApi ?? const MockApprovalsApi(),
              embedded: true,
            ),
            Scaffold(
              backgroundColor: Colors.white,
              appBar: AppTopBar(title: l.navAccount),
              body: _AccountTab(profile: _profile, onLogout: widget.onLogout),
            ),
          ],
        ),
        bottomNavigationBar: ListenableBuilder(
          listenable: _approvals,
          builder: (_, _) => AppBottomNav(
            currentIndex: _tab,
            onTap: _selectTab,
            items: [
              AppNavItem(icon: AppIcons.home, label: l.navHome),
              AppNavItem(
                icon: AppIcons.check,
                label: l.approvalsTitle,
                badge: _approvals.waiting,
              ),
              AppNavItem(icon: AppIcons.user, label: l.navAccount),
            ],
          ),
        ),
      ),
    );
  }
}

/// Initials of a name, skipping the Arabic definite article so "الزرقاني"
/// gives "ز", not "ا".
String _initials(String name) {
  String core(String p) =>
      p.startsWith('ال') && p.length > 2 ? p.substring(2) : p;
  final parts = name.trim().split(RegExp(r'\s+'));
  final a = core(parts.first).characters.first;
  final b = parts.length > 1 ? core(parts[1]).characters.first : '';
  return '$a$b';
}

/// Bottom sheet with the two languages. Shared by the home grid and the account
/// screen; a single-language company never reaches it (the callers hide it).
Future<void> pickLanguage(BuildContext context) async {
  final l = context.l10n;
  final ctrl = LocaleScope.of(context);
  await showAppBottomSheet<void>(
    context,
    title: l.chooseLanguage,
    builder: (ctx) => AppListGroup(
      children: [
        for (final (code, name) in [('ar', l.arabic), ('en', l.english)])
          AppListTile(
            title: name,
            showChevron: false,
            trailing: ctrl.locale.languageCode == code
                ? const AppIcon(AppIcons.check, color: AppColors.blue)
                : null,
            onTap: () {
              ctrl.setLocale(Locale(code));
              Navigator.of(ctx).pop();
            },
          ),
      ],
    ),
  );
}

class _HomeBody extends StatefulWidget {
  const _HomeBody({
    required this.name,
    this.subtitle,
    required this.onOpenAttendance,
    required this.onOpenLeave,
    required this.onOpenApprovals,
    required this.onOpenApproval,
    required this.approvals,
    required this.onSoon,
  });

  final String name;
  final String? subtitle;
  final VoidCallback onOpenAttendance;
  final VoidCallback onOpenLeave;
  final VoidCallback onOpenApprovals;
  final ValueChanged<ApprovalItem> onOpenApproval;
  final ApprovalsFeed approvals;

  /// Services whose screen is not built yet.
  final VoidCallback onSoon;

  @override
  State<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<_HomeBody> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Replace with the real data load; skeleton shows until it completes.
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final date = toWesternDigits(
      DateFormat.MMMEd(locale).format(DateTime.now()),
    );

    // The services, in reading order. A single-language company has no language.
    final tiles = <Widget>[
      AppSquareTile(
        icon: AppIcons.clock,
        label: l.attendanceTitle,
        onTap: widget.onOpenAttendance,
      ),
      AppSquareTile(
        icon: AppIcons.calendar,
        label: l.leaveTitle,
        onTap: widget.onOpenLeave,
      ),
      ListenableBuilder(
        listenable: widget.approvals,
        builder: (_, _) => AppSquareTile(
          icon: AppIcons.check,
          label: l.approvalsTitle,
          dot: widget.approvals.waiting > 0,
          onTap: widget.onOpenApprovals,
        ),
      ),
      AppSquareTile(
        icon: AppIcons.money,
        label: l.payslip,
        onTap: widget.onSoon,
      ),
    ];

    // Pull down to reload what home shows (the approvals waiting for me).
    // A few squares sit side by side in one row; more wrap in rows of three.
    final columns = tiles.length <= 4 ? tiles.length : 3;
    return RefreshIndicator(
      color: AppColors.blue,
      onRefresh: widget.approvals.reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _Greeting(
            greeting: l.greeting,
            name: widget.name,
            date: date,
            subtitle: widget.subtitle,
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppReveal(
                  index: 0,
                  child: Text(l.servicesTitle, style: AppText.h3),
                ),
                const SizedBox(height: AppSpacing.s3),
                if (_loading)
                  const AppSkeletonCard(height: 360)
                else
                  for (
                    var start = 0;
                    start < tiles.length;
                    start += columns
                  ) ...[
                    if (start > 0) const SizedBox(height: 12),
                    AppReveal(
                      index: 1 + start ~/ columns,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < columns; i++) ...[
                            if (i > 0) const SizedBox(width: 12),
                            Expanded(
                              child: start + i < tiles.length
                                  ? tiles[start + i]
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                const SizedBox(height: AppSpacing.s5),
                AppReveal(index: 3, child: HomePromoCard(onTap: widget.onSoon)),
                const SizedBox(height: AppSpacing.s5),
                ApprovalsHomeSection(
                  feed: widget.approvals,
                  onOpenAll: widget.onOpenApprovals,
                  onOpenItem: widget.onOpenApproval,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A small greeting: "Good morning · Thu, Oct 1" and the name under it. Two
/// lines, instead of a large page header, so the services start high on the screen.
class _Greeting extends StatelessWidget {
  const _Greeting({
    required this.greeting,
    required this.name,
    required this.date,
    this.subtitle,
  });

  final String greeting;
  final String name;
  final String date;

  /// The job (and department) under the name, when the server sent one.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        12,
        AppSpacing.gutter,
        0,
      ),
      child: AppCard(
        navy: true,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const LTick(opacity: 1, height: 13),
                const SizedBox(width: 8),
                Text(
                  greeting,
                  style: AppText.small.copyWith(
                    color: AppColors.blueBright,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 10),
                // The date sits on the greeting's line, on a faint pill.
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(AppRadius.xs + 2),
                    ),
                    child: Text(
                      date,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.xs.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.h2.copyWith(color: Colors.white),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.small.copyWith(color: AppColors.onNavyMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The account as its own screen, opened from the home's top bar.
class _AccountPage extends StatelessWidget {
  const _AccountPage({required this.onLogout, this.profile});
  final VoidCallback onLogout;
  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppTopBar(showBack: true, title: context.l10n.navAccount),
      body: _AccountTab(onLogout: onLogout, profile: profile),
    );
  }
}

class _AccountTab extends StatelessWidget {
  const _AccountTab({required this.onLogout, this.profile});
  final VoidCallback onLogout;
  final UserProfile? profile;

  /// Keeps a number or an address in left-to-right order inside Arabic text.
  static String _ltr(String v) =>
      '${String.fromCharCode(0x2066)}$v${String.fromCharCode(0x2069)}';

  /// Rows of one group; values the server did not send are left out.
  List<Widget> _rows(List<(AppIconData, String, String?)> items) => [
    for (final (icon, label, value) in items)
      if (value != null)
        AppListTile(leading: AppIconTile(icon), title: value, subtitle: label),
  ];

  String _initials(String name) {
    // Skip the Arabic definite article so "الزرقاني" gives "ز", not "ا".
    String core(String p) =>
        p.startsWith('ال') && p.length > 2 ? p.substring(2) : p;
    final parts = name.trim().split(RegExp(r'\s+'));
    final a = core(parts.first).characters.first;
    final b = parts.length > 1 ? core(parts[1]).characters.first : '';
    return '$a$b';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = profile;
    final name = p?.name ?? l.sampleName;
    final locale = Localizations.localeOf(context).toString();
    final hired = p?.hireDate;
    final work = _rows([
      (AppIcons.idCard, l.profileJob, p?.job),
      (AppIcons.users, l.profileDepartment, p?.department),
      (AppIcons.location, l.profileSite, p?.site),
      (AppIcons.user, l.profileManager, p?.manager),
      (AppIcons.check, l.profileStatus, p?.status),
      (AppIcons.building, l.profileCompany, p?.company),
      (AppIcons.building, l.profileBranch, p?.branch),
      (
        AppIcons.calendar,
        l.profileHireDate,
        hired == null
            ? null
            : toWesternDigits(DateFormat.yMMMd(locale).format(hired)),
      ),
    ]);
    final contact = _rows([
      (
        AppIcons.phone,
        l.phoneNumber,
        p?.phone == null ? null : _ltr(p!.phone!),
      ),
      (
        AppIcons.mail,
        l.emailAddress,
        p?.email == null ? null : _ltr(p!.email!),
      ),
    ]);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      children: [
        AppCard(
          navy: true,
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .14),
                  borderRadius: AppRadius.mdAll,
                  border: Border.all(color: Colors.white.withValues(alpha: .2)),
                ),
                child: Text(
                  _initials(name),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppText.h3.copyWith(color: Colors.white)),
                    Text(
                      p?.employeeCode ?? 'EMP-0012',
                      textDirection: TextDirection.ltr,
                      style: AppText.mono.copyWith(
                        color: AppColors.onNavyMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s5),
        if (work.isNotEmpty) ...[
          AppGroupTitle(l.profileGroupWork),
          const SizedBox(height: AppSpacing.s2),
          AppListGroup(children: work),
          const SizedBox(height: AppSpacing.s5),
        ],
        if (contact.isNotEmpty) ...[
          AppGroupTitle(l.profileGroupContact),
          const SizedBox(height: AppSpacing.s2),
          AppListGroup(children: contact),
          const SizedBox(height: AppSpacing.s5),
        ],
        // A single-language company has no language to pick.
        if (LocaleScope.of(context).canSwitch) ...[
          AppGroupTitle(l.accountGroupPrefs),
          const SizedBox(height: AppSpacing.s2),
          AppListGroup(
            children: [
              AppListTile(
                leading: const AppIconTile(AppIcons.globe),
                title: l.language,
                trailing: Text(l.languageName, style: AppText.small),
                showChevron: true,
                onTap: () => pickLanguage(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s5),
        ],
        AppGroupTitle(l.accountGroupSupport),
        const SizedBox(height: AppSpacing.s2),
        AppListGroup(
          children: [
            AppListTile(
              leading: const AppIconTile(AppIcons.help),
              title: l.helpSupport,
              subtitle: l.helpSupportSub,
              onTap: () =>
                  AppSnackbar.show(context, l.contactHr, tone: AppTone.info),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s5),
        AppButton(
          label: l.logout,
          variant: AppButtonVariant.ghost,
          leadingIcon: AppIcons.logout,
          onPressed: () async {
            final ok = await showAppConfirmDialog(
              context,
              title: l.logoutTitle,
              message: l.logoutMessage,
              destructive: true,
              confirmLabel: l.logout,
            );
            if (ok) onLogout();
          },
        ),
      ],
    );
  }
}
