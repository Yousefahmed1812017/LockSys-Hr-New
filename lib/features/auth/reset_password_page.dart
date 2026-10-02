import 'package:flutter/material.dart';

import '../../core/icons/app_icons.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_overlays.dart';
import '../../core/widgets/app_screen.dart';
import '../../core/widgets/app_text_field.dart';
import 'auth_api.dart';

/// Password recovery, last step: a new password and its confirmation. Done
/// returns to the sign-in screen with a confirmation message.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    super.key,
    required this.api,
    required this.resetToken,
  });
  final AuthApi api;

  /// Proof that the code was verified (from the server).
  final String resetToken;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await widget.api.resetPassword(
        resetToken: widget.resetToken,
        newPassword: _password.text,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppSnackbar.show(
        context,
        e.network
            ? context.l10n.companyErrNetwork
            : e.message(Localizations.localeOf(context).languageCode),
        tone: AppTone.danger,
      );
      return;
    }
    if (!mounted) return;
    final navigator = Navigator.of(context);
    final message = context.l10n.resetDone;
    navigator.popUntil((route) => route.isFirst);
    AppSnackbar.show(navigator.context, message);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final eye = AppIconButton(
      icon: _obscure ? AppIcons.eye : AppIcons.eyeOff,
      color: AppColors.muted,
      semanticLabel: _obscure ? l.showPassword : l.hidePassword,
      onPressed: () => setState(() => _obscure = !_obscure),
    );
    return AppScreen(
      showBack: true,
      kicker: l.resetKicker,
      heading: l.resetTitle,
      subtitle: l.resetSubtitle,
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: l.newPassword,
                controller: _password,
                hint: l.passwordHint,
                obscureText: _obscure,
                prefixIcon: AppIcons.lock,
                textInputAction: TextInputAction.next,
                suffix: eye,
                validator: (v) {
                  if (v == null || v.isEmpty) return l.errPasswordRequired;
                  if (v.length < 6) return l.errPasswordShort;
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: l.confirmPassword,
                controller: _confirm,
                hint: l.passwordHint,
                obscureText: _obscure,
                prefixIcon: AppIcons.lock,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                validator: (v) {
                  if (v == null || v.isEmpty) return l.errPasswordRequired;
                  if (v != _password.text) return l.errPasswordMismatch;
                  return null;
                },
              ),
            ],
          ),
        ),
        AppButton(
          label: l.resetSave,
          size: AppButtonSize.lg,
          icon: AppIcons.forward,
          loading: _loading,
          onPressed: _save,
        ),
      ],
    );
  }
}
