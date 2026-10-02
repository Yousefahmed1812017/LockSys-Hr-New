import 'package:flutter/material.dart';

import '../../core/icons/app_icons.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_alert.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_chips.dart';
import '../../core/widgets/app_screen.dart';
import '../company/company.dart';
import 'auth_api.dart';
import 'auth_options.dart';
import 'contact_fields.dart';
import 'otp_flow.dart';
import 'reset_password_page.dart';

/// Password recovery, step 1. The employee says who they are by e-mail or by
/// mobile number, picks how to receive a code, enters it, and then sets a new
/// password (see [ResetPasswordPage]). Which of the two appear, and which code
/// channels, comes from the company's features ([AuthOptions]).
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({
    super.key,
    required this.company,
    required this.api,
  });
  final Company company;
  final AuthApi api;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  RecoveryMethod? _chosen;

  AuthOptions get _options => AuthOptions(widget.company);

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _send(RecoveryMethod method) async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    final byEmail = method == RecoveryMethod.email;
    await startOtp(
      context,
      channels: _options.recoveryChannelsFor(method),
      destinations: OtpDestinations.from(
        email: byEmail ? _email.text.trim() : null,
        phone: byEmail ? null : normalizePhone(_phone.text),
      ),
      kicker: context.l10n.forgotKicker,
      request: (channel) => widget.api.requestOtp(
        purpose: OtpPurpose.reset,
        byPhone: !byEmail,
        identifier: byEmail ? _email.text.trim() : normalizePhone(_phone.text),
        channel: channel.name,
      ),
      verify: (ticket, code) =>
          widget.api.verifyResetOtp(otpId: ticket.otpId, code: code),
      onVerified: (otpContext, resetToken) =>
          Navigator.of(otpContext).push<void>(
            MaterialPageRoute(
              builder: (_) => ResetPasswordPage(
                api: widget.api,
                resetToken: resetToken! as String,
              ),
            ),
          ),
    );
  }

  String _label(RecoveryMethod m) => switch (m) {
    RecoveryMethod.email => context.l10n.emailAddress,
    RecoveryMethod.phone => context.l10n.phoneNumber,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final methods = _options.recoveryMethods;
    final method = methods.isEmpty
        ? null
        : (methods.contains(_chosen) ? _chosen! : methods.first);
    return AppScreen(
      showBack: true,
      kicker: l.forgotKicker,
      heading: l.forgotTitle,
      subtitle: l.forgotSubtitle,
      children: [
        if (method == null)
          AppAlert(
            title: l.forgotTitle,
            message: l.contactHr,
            tone: AppTone.warning,
          )
        else ...[
          if (methods.length > 1)
            AppSegmented(
              labels: [for (final m in methods) _label(m)],
              selectedIndex: methods.indexOf(method),
              onChanged: (i) => setState(() {
                _chosen = methods[i];
                _form.currentState?.reset();
              }),
            ),
          Form(
            key: _form,
            child: method == RecoveryMethod.email
                ? emailField(
                    context,
                    controller: _email,
                    action: TextInputAction.done,
                    onSubmitted: (_) => _send(method),
                  )
                : phoneField(
                    context,
                    controller: _phone,
                    action: TextInputAction.done,
                    onSubmitted: (_) => _send(method),
                  ),
          ),
          AppButton(
            label: l.sendCode,
            size: AppButtonSize.lg,
            icon: AppIcons.forward,
            onPressed: () => _send(method),
          ),
        ],
      ],
    );
  }
}
