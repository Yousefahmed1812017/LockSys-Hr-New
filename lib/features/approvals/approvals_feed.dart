import 'package:flutter/material.dart';

import '../../core/icons/app_icons.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_request_card.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/app_overlays.dart';
import '../../core/widgets/pressable.dart';
import '../auth/auth_api.dart';
import '../leave/my_leaves_page.dart'
    show leaveDaysText, leaveErrorText, shortDate;
import 'approvals_api.dart';
import 'approvals_page.dart';

/// What is waiting for the signed-in employee to decide, kept for the home
/// screen: the first requests of the "waiting" tab and how many there are in all.
/// A decision made here (or on the approvals screen, then [reload]) updates it.
class ApprovalsFeed extends ChangeNotifier {
  ApprovalsFeed(this.api);
  final ApprovalsApi api;

  final List<ApprovalItem> items = [];

  /// How many requests wait for me (can be more than [items]).
  int waiting = 0;
  bool loaded = false;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Quietly: no spinner, an employee who approves nothing sees nothing.
  Future<void> reload() async {
    try {
      final page = await api.items(limit: 5);
      items
        ..clear()
        ..addAll(page.items);
      waiting = page.summary['waiting'] ?? page.total;
      loaded = true;
    } on AuthException {
      // keep what is shown
    }
    _notify();
  }

  /// A request that was decided leaves the list; one more may take its place.
  Future<void> removed(int requestId) async {
    items.removeWhere((i) => i.requestId == requestId);
    if (waiting > 0) waiting--;
    _notify();
    if (items.length < 3 && waiting > items.length) await reload();
  }
}

/// Approve or reject [item] without opening it. A rejection asks for the reason
/// first (required). Returns true when the server took the decision; shows the
/// server's message otherwise.
Future<bool> decideInline(
  BuildContext context,
  ApprovalsApi api,
  ApprovalItem item, {
  required bool approve,
}) async {
  final l = context.l10n;
  String? notes;
  if (approve) {
    final sure = await showAppBottomSheet<bool>(
      context,
      title: l.apprApproveTitle,
      builder: (ctx) => ApprovalConfirmSheet(
        requester: item.requesterName(Localizations.localeOf(ctx).languageCode),
      ),
    );
    if (sure != true || !context.mounted) return false;
  } else {
    notes = await showAppBottomSheet<String>(
      context,
      title: l.apprRejectTitle,
      builder: (ctx) => const ApprovalNotesSheet(approve: false),
    );
    if (notes == null || !context.mounted) return false;
  }
  try {
    await api.decide(item.requestId, approve: approve, notes: notes);
    return true;
  } on AuthException catch (e) {
    if (context.mounted) {
      AppSnackbar.show(
        context,
        leaveErrorText(context, e),
        tone: AppTone.danger,
      );
    }
    return false;
  }
}

/// "Approve this request?" as a small sheet: the question and Cancel / Confirm.
/// Pops true when confirmed.
class ApprovalConfirmSheet extends StatelessWidget {
  const ApprovalConfirmSheet({super.key, required this.requester});
  final String requester;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.apprConfirmApproveMsg(requester), style: AppText.body),
        const SizedBox(height: AppSpacing.s4),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: l.cancel,
                variant: AppButtonVariant.ghost,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton(
                label: l.apprConfirm,
                icon: AppIcons.check,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The initials of a name on a soft blue circle (the card's leading).
class _Initials extends StatelessWidget {
  const _Initials(this.name);
  final String name;

  @override
  Widget build(BuildContext context) {
    String core(String p) =>
        p.startsWith('ال') && p.length > 2 ? p.substring(2) : p;
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final text = parts.isEmpty
        ? '?'
        : parts.take(2).map((p) => core(p).characters.first).join();
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.blue50,
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: AppText.small.copyWith(
          color: AppColors.blue,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The three facts of a request: duration, from, to.
List<(String, String)> approvalFacts(BuildContext context, ApprovalItem item) {
  final l = context.l10n;
  final r = item.request;
  return [
    (l.leaveDurationLabel, leaveDaysText(l, r.totalDays)),
    (l.detailFrom, shortDate(context, r.start)),
    (l.detailTo, shortDate(context, r.end)),
  ];
}

/// A request I cannot decide now, as the same card: under "Later" it says who
/// has to decide first, under "Done" what I decided.
class ApprovalInfoCard extends StatelessWidget {
  const ApprovalInfoCard({super.key, required this.item, required this.onTap});
  final ApprovalItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final waiting = item.waitingFor(lang);
    final status = item.stageStatus;
    String? label;
    var tone = AppTone.warning;
    var accent = AppColors.warning;
    if (status == 'APPROVED') {
      label = l.stepApproved;
      tone = AppTone.success;
      accent = AppColors.success;
    } else if (status == 'REJECTED') {
      label = l.stepRejected;
      tone = AppTone.danger;
      accent = AppColors.danger;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s3),
      child: AppRequestCard(
        leading: _Initials(item.requesterName(lang)),
        title: item.requesterName(lang),
        subtitle: item.request.typeName(lang),
        status: label,
        statusTone: tone,
        accent: accent,
        facts: approvalFacts(context, item),
        note: waiting == null ? null : l.apprWaitingFirst(waiting),
        onTap: onTap,
      ),
    );
  }
}

/// Approve (green, with a check) and Reject (red, with a cross) side by side.
/// Disabled while the call is in flight; Approve spins.
class ApprovalButtons extends StatelessWidget {
  const ApprovalButtons({
    super.key,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget button({
      required String label,
      required VoidCallback onTap,
      required Color color,
      required Widget icon,
      bool spin = false,
    }) => Expanded(
      child: Pressable(
        onTap: busy ? null : onTap,
        scale: .97,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: busy && !spin ? color.withValues(alpha: .45) : color,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: spin
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    icon,
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
    return Row(
      children: [
        button(
          label: l.apprReject,
          onTap: onReject,
          color: AppColors.danger,
          icon: Transform.rotate(
            angle: .785398,
            child: const AppIcon(AppIcons.plus, size: 20, color: Colors.white),
          ),
        ),
        const SizedBox(width: 10),
        button(
          label: l.apprApprove,
          onTap: onApprove,
          color: AppColors.success,
          spin: busy,
          icon: const AppIcon(AppIcons.check, size: 20, color: Colors.white),
        ),
      ],
    );
  }
}

/// What replaces the facts once the server took the decision: a round check
/// (approved) or cross (rejected) and the words.
class ApprovalResultPanel extends StatelessWidget {
  const ApprovalResultPanel({super.key, required this.approved});
  final bool approved;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final color = approved ? AppColors.success : AppColors.danger;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 96),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: .4, end: 1),
              duration: const Duration(milliseconds: 420),
              curve: Curves.elasticOut,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: approved ? AppColors.successBg : AppColors.dangerBg,
                  border: Border.all(color: color, width: 2),
                ),
                child: Center(
                  child: approved
                      ? AppIcon(AppIcons.check, size: 24, color: color)
                      : Transform.rotate(
                          angle: .785398,
                          child: AppIcon(AppIcons.plus, size: 24, color: color),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              approved ? l.apprApproved : l.apprRejected,
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A request that waits for my decision, as the same card with Approve /
/// Reject on it. After the decision the card shows the result, then fades and
/// folds away and [onDecided] runs.
class ApprovalActionCard extends StatefulWidget {
  const ApprovalActionCard({
    super.key,
    required this.api,
    required this.item,
    required this.onDecided,
    this.onOpen,
  });
  final ApprovalsApi api;
  final ApprovalItem item;
  final VoidCallback? onOpen;

  /// Called once the card has left the screen.
  final VoidCallback onDecided;

  @override
  State<ApprovalActionCard> createState() => _ApprovalActionCardState();
}

class _ApprovalActionCardState extends State<ApprovalActionCard> {
  bool _busy = false;
  bool? _approved; // set when the server took the decision
  bool _gone = false;

  Future<void> _decide(bool approve) async {
    setState(() => _busy = true);
    final ok = await decideInline(
      context,
      widget.api,
      widget.item,
      approve: approve,
    );
    if (!mounted) return;
    if (!ok) {
      setState(() => _busy = false);
      return;
    }
    setState(() => _approved = approve);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    setState(() => _gone = true);
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (mounted) widget.onDecided();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final item = widget.item;
    return AnimatedSize(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _gone ? 0 : 1,
        child: _gone
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                child: AppRequestCard(
                  leading: _Initials(item.requesterName(lang)),
                  title: item.requesterName(lang),
                  subtitle: item.request.typeName(lang),
                  facts: approvalFacts(context, item),
                  accent: _approved == null
                      ? AppColors.blue
                      : (_approved! ? AppColors.success : AppColors.danger),
                  onTap: (_busy || _approved != null) ? null : widget.onOpen,
                  actions: ApprovalButtons(
                    busy: _busy,
                    onApprove: () => _decide(true),
                    onReject: () => _decide(false),
                  ),
                  replacement: _approved == null
                      ? null
                      : ApprovalResultPanel(approved: _approved!),
                ),
              ),
      ),
    );
  }
}

/// The home screen's approvals block: the first requests waiting for me, each
/// with its own Approve / Reject. Hidden while nothing waits.
class ApprovalsHomeSection extends StatelessWidget {
  const ApprovalsHomeSection({
    super.key,
    required this.feed,
    required this.onOpenAll,
    required this.onOpenItem,
  });
  final ApprovalsFeed feed;
  final VoidCallback onOpenAll;
  final ValueChanged<ApprovalItem> onOpenItem;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ListenableBuilder(
      listenable: feed,
      builder: (context, _) {
        final shown = feed.items.take(3).toList();
        return AnimatedSize(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: shown.isEmpty
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(l.apprHomeTitle, style: AppText.h3),
                        ),
                        if (feed.waiting > shown.length)
                          AppTextLink(
                            l.apprShowAll('${feed.waiting}'),
                            onTap: onOpenAll,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s3),
                    for (final it in shown)
                      ApprovalActionCard(
                        key: ValueKey('appr-${it.requestId}'),
                        api: feed.api,
                        item: it,
                        onOpen: () => onOpenItem(it),
                        onDecided: () => feed.removed(it.requestId),
                      ),
                  ],
                ),
        );
      },
    );
  }
}
