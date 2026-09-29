import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/icons/app_icons.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_alert.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/app_list.dart';
import '../../core/widgets/app_logo_mark.dart';
import '../../core/widgets/app_overlays.dart';
import '../../core/widgets/app_screen.dart';
import '../../core/widgets/app_skeleton.dart';

/// Signed-in shell: top bar + 4 tabs (Home, Attendance, Leave, Account).
/// Home and Account are real; Attendance and Leave are placeholders until
/// their screens are built with the locksys-design-system skill.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onLogout});
  final VoidCallback onLogout;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppTopBar(
        leading: Row(
          children: [
            const AppLogoMark(height: 30),
            const SizedBox(width: 10),
            Text('LockSys HR',
                textDirection: TextDirection.ltr,
                style: AppText.h3.copyWith(fontSize: 16)),
          ],
        ),
        actions: [
          AppIconButton(
            icon: AppIcons.bell,
            semanticLabel: l.noticeTitle,
            onPressed: () {},
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          const _HomeTab(),
          _Soon(title: l.navAttendance),
          _Soon(title: l.navLeave),
          _AccountTab(onLogout: widget.onLogout),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: [
          AppNavItem(icon: AppIcons.home, label: l.navHome),
          AppNavItem(icon: AppIcons.clock, label: l.navAttendance),
          AppNavItem(icon: AppIcons.calendar, label: l.navLeave, badge: 2),
          AppNavItem(icon: AppIcons.user, label: l.navAccount),
        ],
      ),
    );
  }
}

class _Soon extends StatelessWidget {
  const _Soon({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ListView(
      children: [
        AppPageHeader(title: title, kicker: l.comingSoon),
        const SizedBox(height: 40),
        AppEmptyState.empty(
          title: l.comingSoon,
          message: l.comingSoonMessage,
        ),
      ],
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  bool _loading = true;
  bool _checkedIn = false;

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
    final date =
        toWesternDigits(DateFormat.yMMMMEEEEd(locale).format(DateTime.now()));
    return ListView(
      children: [
        AppPageHeader(
          kicker: l.greeting,
          title: l.sampleName,
          subtitle: date,
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppReveal(
                index: 0,
                child: AppLoadable(
                  loading: _loading,
                  skeleton: const AppSkeletonCard(height: 150),
                  child: AppCard(
                    navy: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _checkedIn ? l.checkedIn : l.notCheckedIn,
                          style: AppText.small
                              .copyWith(color: AppColors.onNavyMuted),
                        ),
                        const SizedBox(height: 8),
                        Text('08:30',
                            textDirection: TextDirection.ltr,
                            style: AppText.stat.copyWith(color: Colors.white)),
                        const SizedBox(height: 14),
                        AppButton(
                          label: _checkedIn ? l.checkedIn : l.checkIn,
                          leadingIcon: AppIcons.fingerprint,
                          onPressed: _checkedIn
                              ? null
                              : () {
                                  setState(() => _checkedIn = true);
                                  AppSnackbar.show(context, l.checkedIn);
                                },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              AppReveal(
                index: 1,
                child: Text(l.quickServices, style: AppText.h3),
              ),
              const SizedBox(height: AppSpacing.s3),
              AppReveal(
                index: 2,
                child: AppLoadable(
                  loading: _loading,
                  skeleton: const AppSkeletonList(count: 2),
                  child: AppListGroup(
                    children: [
                      AppListTile(
                        leading: const AppIconTile(AppIcons.calendar),
                        title: l.leaveRequest,
                        subtitle: l.leaveRequestSub,
                        onTap: () {},
                      ),
                      AppListTile(
                        leading: const AppIconTile(AppIcons.money),
                        title: l.payslip,
                        subtitle: l.payslipSub,
                        trailing: AppBadge(l.newBadge),
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              AppReveal(
                index: 3,
                child: AppAlert(
                  title: l.noticeTitle,
                  message: l.contractNotice,
                  tone: AppTone.warning,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountTab extends StatelessWidget {
  const _AccountTab({required this.onLogout});
  final VoidCallback onLogout;

  String _initials(String name) {
    // Skip the Arabic definite article so "الزرقاني" gives "ز", not "ا".
    String core(String p) =>
        p.startsWith('ال') && p.length > 2 ? p.substring(2) : p;
    final parts = name.trim().split(RegExp(r'\s+'));
    final a = core(parts.first).characters.first;
    final b = parts.length > 1 ? core(parts[1]).characters.first : '';
    return '$a$b';
  }

  Future<void> _pickLanguage(BuildContext context) async {
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

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
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
                  _initials(l.sampleName),
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
                    Text(l.sampleName,
                        style: AppText.h3.copyWith(color: Colors.white)),
                    Text('EMP-0012',
                        textDirection: TextDirection.ltr,
                        style: AppText.mono
                            .copyWith(color: AppColors.onNavyMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s5),
        AppGroupTitle(l.accountGroupPrefs),
        const SizedBox(height: AppSpacing.s2),
        AppListGroup(
          children: [
            AppListTile(
              leading: const AppIconTile(AppIcons.globe),
              title: l.language,
              trailing: Text(l.languageName, style: AppText.small),
              showChevron: true,
              onTap: () => _pickLanguage(context),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s5),
        AppGroupTitle(l.accountGroupSupport),
        const SizedBox(height: AppSpacing.s2),
        AppListGroup(
          children: [
            AppListTile(
              leading: const AppIconTile(AppIcons.help),
              title: l.helpSupport,
              subtitle: l.helpSupportSub,
              onTap: () => AppSnackbar.show(context, l.contactHr,
                  tone: AppTone.info),
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
