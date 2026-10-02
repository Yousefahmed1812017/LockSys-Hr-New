import 'package:flutter/material.dart';

import '../../core/icons/app_icons.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_overlays.dart';
import '../../core/widgets/app_screen.dart';
import '../../core/widgets/app_square_tile.dart';
import 'leave_api.dart';
import 'leave_request_page.dart';
import 'my_balances_page.dart';
import 'my_leaves_page.dart';

/// Leave hub, opened from the home grid: three squares like the home screen.
///   My leave    -> every request of the employee (from the server)
///   My balances -> what is left of each leave type (from the server)
///   Request leave -> the request form (types, live count and send, all from the server)
class LeavePage extends StatelessWidget {
  const LeavePage({super.key, required this.api});
  final LeaveApi api;

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => page));

  Future<void> _newRequest(BuildContext context) async {
    final created = await Navigator.of(context).push<LeaveItem>(
      MaterialPageRoute(builder: (_) => LeaveRequestPage(api: api)),
    );
    if (created == null || !context.mounted) return;
    AppSnackbar.show(context, context.l10n.leaveSubmitted);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppTopBar(showBack: true, title: l.leaveTitle),
      body: ListView(
        children: [
          AppScreenIntro(l.leaveHubSubtitle),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppSquareTile(
                    icon: AppIcons.calendar,
                    label: l.leaveMyLeaves,
                    onTap: () => _open(context, MyLeavesPage(api: api)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppSquareTile(
                    icon: AppIcons.clock,
                    label: l.leaveMyBalances,
                    onTap: () => _open(context, MyBalancesPage(api: api)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppSquareTile(
                    icon: AppIcons.plus,
                    label: l.leaveRequestTile,
                    onTap: () => _newRequest(context),
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
