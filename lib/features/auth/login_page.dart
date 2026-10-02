import 'package:flutter/material.dart';

import '../../core/icons/app_icons.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_alert.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_brand_hero.dart';
import '../../core/widgets/app_chips.dart';
import '../../core/widgets/app_overlays.dart';
import '../../core/widgets/app_screen.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/l_pattern.dart';
import '../company/company.dart';
import 'auth_api.dart';
import 'auth_options.dart';
import 'contact_fields.dart';
import '../../l10n/app_localizations.dart';
import 'forgot_password_page.dart';
import 'otp_flow.dart';

/// Sign-in screen. White hero with the faded L pattern, the LockSys mark and
/// name, then the ways to sign in and the form. Which ways appear comes from the
/// company's features (auth.password / auth.phone / auth.email, see
/// [AuthOptions]): one way shows no switch, none shows an explanation.
/// [onSuccess] is called with the session after a successful sign-in; every
/// step talks to the company server through [api].
class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.company,
    required this.api,
    required this.onSuccess,
  });
  final Company company;
  final AuthApi api;
  final void Function(AuthSession session, bool remember) onSuccess;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  LoginMethod? _chosen;
  bool _obscure = true;
  bool _remember = true;
  bool _loading = false;
  String? _error;

  AuthOptions get _options => AuthOptions(widget.company);

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await widget.api.loginPassword(
        username: _user.text.trim(),
        password: _pass.text,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      widget.onSuccess(session, _remember);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.network
            ? context.l10n.companyErrNetwork
            : e.message(Localizations.localeOf(context).languageCode);
      });
    }
  }

  /// Mobile / e-mail methods: pick how to receive the code, then enter it.
  Future<void> _sendCode(LoginMethod method) async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    final byPhone = method == LoginMethod.phone;
    await startOtp(
      context,
      channels: _options.channelsFor(method),
      destinations: OtpDestinations.from(
        phone: byPhone ? normalizePhone(_phone.text) : null,
        email: byPhone ? null : _email.text.trim(),
      ),
      kicker: context.l10n.otpKicker,
      request: (channel) => widget.api.requestOtp(
        purpose: OtpPurpose.login,
        byPhone: byPhone,
        identifier: byPhone ? normalizePhone(_phone.text) : _email.text.trim(),
        channel: channel.name,
      ),
      verify: (ticket, code) =>
          widget.api.verifyLoginOtp(otpId: ticket.otpId, code: code),
      onVerified: (otpContext, session) {
        Navigator.of(otpContext).popUntil((route) => route.isFirst);
        widget.onSuccess(session! as AuthSession, _remember);
      },
    );
  }

  void _openForgotPassword() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) =>
          ForgotPasswordPage(company: widget.company, api: widget.api),
    ),
  );

  List<Widget> _usernameFields(
    AppLocalizations l, {
    required bool canRecover,
  }) => [
    if (_error != null) ...[
      AppAlert(
        title: l.signInFailedTitle,
        message: _error,
        tone: AppTone.danger,
      ),
      const SizedBox(height: 16),
    ],
    AppReveal(
      index: 2,
      child: AppTextField(
        label: l.username,
        controller: _user,
        hint: l.usernameHint,
        mono: true,
        prefixIcon: AppIcons.user,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.next,
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? l.errUsernameRequired : null,
      ),
    ),
    const SizedBox(height: 16),
    AppReveal(
      index: 3,
      child: AppTextField(
        label: l.password,
        controller: _pass,
        hint: l.passwordHint,
        obscureText: _obscure,
        prefixIcon: AppIcons.lock,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        validator: (v) {
          if (v == null || v.isEmpty) return l.errPasswordRequired;
          if (v.length < 6) return l.errPasswordShort;
          return null;
        },
        suffix: AppIconButton(
          icon: _obscure ? AppIcons.eye : AppIcons.eyeOff,
          color: AppColors.muted,
          semanticLabel: _obscure ? l.showPassword : l.hidePassword,
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    ),
    const SizedBox(height: 8),
    AppReveal(
      index: 4,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: AppRadius.smAll,
              onTap: () => setState(() => _remember = !_remember),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Checkbox(
                      value: _remember,
                      onChanged: (v) => setState(() => _remember = v ?? false),
                    ),
                  ),
                  Flexible(child: Text(l.rememberMe, style: AppText.body)),
                ],
              ),
            ),
          ),
          // Flexible: at 320 px with large text the link wraps instead of
          // pushing the row past the screen edge.
          if (canRecover)
            Flexible(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: AppTextLink(
                  l.forgotPassword,
                  onTap: _openForgotPassword,
                ),
              ),
            ),
        ],
      ),
    ),
    const SizedBox(height: 12),
    AppReveal(
      index: 5,
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
      index: 6,
      child: AppButton(
        label: l.biometricLogin,
        variant: AppButtonVariant.ghost,
        leadingIcon: AppIcons.fingerprint,
        onPressed: _loading
            ? null
            : () => AppSnackbar.show(context, l.comingSoon, tone: AppTone.info),
      ),
    ),
  ];

  List<Widget> _codeFields(AppLocalizations l, LoginMethod method) => [
    AppReveal(
      index: 2,
      child: method == LoginMethod.phone
          ? phoneField(
              context,
              controller: _phone,
              action: TextInputAction.done,
              onSubmitted: (_) => _sendCode(method),
            )
          : emailField(
              context,
              controller: _email,
              action: TextInputAction.done,
              onSubmitted: (_) => _sendCode(method),
            ),
    ),
    const SizedBox(height: 20),
    AppReveal(
      index: 3,
      child: AppButton(
        label: l.sendCode,
        size: AppButtonSize.lg,
        icon: AppIcons.forward,
        onPressed: () => _sendCode(method),
      ),
    ),
  ];

  String _label(AppLocalizations l, LoginMethod m) => switch (m) {
    LoginMethod.username => l.loginMethodUsername,
    LoginMethod.phone => l.loginMethodPhone,
    LoginMethod.email => l.loginMethodEmail,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final options = _options;
    final methods = options.loginMethods;
    final method = methods.isEmpty
        ? null
        : (methods.contains(_chosen) ? _chosen! : methods.first);
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
                      if (method == null)
                        AppReveal(
                          index: 1,
                          child: AppAlert(
                            title: l.signInUnavailableTitle,
                            message: l.signInUnavailableMessage,
                            tone: AppTone.warning,
                          ),
                        )
                      else ...[
                        if (methods.length > 1) ...[
                          AppReveal(
                            index: 1,
                            child: AppSegmented(
                              labels: [for (final m in methods) _label(l, m)],
                              selectedIndex: methods.indexOf(method),
                              onChanged: (i) => setState(() {
                                _chosen = methods[i];
                                _form.currentState?.reset();
                              }),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        if (method == LoginMethod.username)
                          ..._usernameFields(l, canRecover: options.canRecover)
                        else
                          ..._codeFields(l, method),
                      ],
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
