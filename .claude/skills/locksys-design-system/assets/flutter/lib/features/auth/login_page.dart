import 'package:flutter/material.dart';

import '../../core/icons/app_icons.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_brand_hero.dart';
import '../../core/widgets/app_overlays.dart';
import '../../core/widgets/app_screen.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/l_pattern.dart';

/// Sign-in screen. White hero with the faded L pattern, the LockSys mark and
/// name, then the form. [onSuccess] is called after a successful sign-in
/// (replace the fake delay in [_submit] with the real API call).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onSuccess});
  final VoidCallback onSuccess;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;
  bool _remember = true;
  bool _loading = false;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    // TODO: call the real sign-in API here.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() => _loading = false);
    widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            children: [
              AppBrandHero(subtitle: l.loginSubtitle),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppReveal(
                        index: 0,
                        child: Row(
                          children: [
                            const LTick(opacity: 1, height: 15),
                            const SizedBox(width: 8),
                            Text(
                              l.loginWelcome,
                              style: AppText.small.copyWith(
                                color: AppColors.blue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppReveal(
                        index: 0,
                        child: Text(l.loginTitle, style: AppText.h1),
                      ),
                      const SizedBox(height: 20),
                      AppReveal(
                        index: 1,
                        child: AppTextField(
                          label: l.username,
                          controller: _user,
                          hint: l.usernameHint,
                          mono: true,
                          prefixIcon: AppIcons.user,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.next,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? l.errUsernameRequired
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppReveal(
                        index: 2,
                        child: AppTextField(
                          label: l.password,
                          controller: _pass,
                          hint: l.passwordHint,
                          obscureText: _obscure,
                          prefixIcon: AppIcons.lock,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return l.errPasswordRequired;
                            }
                            if (v.length < 6) return l.errPasswordShort;
                            return null;
                          },
                          suffix: AppIconButton(
                            icon: _obscure ? AppIcons.eye : AppIcons.eyeOff,
                            color: AppColors.muted,
                            semanticLabel:
                                _obscure ? l.showPassword : l.hidePassword,
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      AppReveal(
                        index: 3,
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                borderRadius: AppRadius.smAll,
                                onTap: () =>
                                    setState(() => _remember = !_remember),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 44,
                                      height: 44,
                                      child: Checkbox(
                                        value: _remember,
                                        onChanged: (v) => setState(
                                            () => _remember = v ?? false),
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(l.rememberMe,
                                          style: AppText.body),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            AppTextLink(
                              l.forgotPassword,
                              onTap: () => AppSnackbar.show(
                                context,
                                l.contactHr,
                                tone: AppTone.info,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppReveal(
                        index: 4,
                        child: AppButton(
                          label: l.loginButton,
                          size: AppButtonSize.lg,
                          icon: AppIcons.forward,
                          loading: _loading,
                          onPressed: _submit,
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppReveal(
                        index: 5,
                        child: AppButton(
                          label: l.biometricLogin,
                          variant: AppButtonVariant.ghost,
                          leadingIcon: AppIcons.fingerprint,
                          onPressed: _loading
                              ? null
                              : () => AppSnackbar.show(
                                    context,
                                    l.comingSoon,
                                    tone: AppTone.info,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
