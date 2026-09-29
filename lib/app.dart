import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/l10n/locale_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_tokens.dart';
import 'features/auth/login_page.dart';
import 'features/company/company_code_page.dart';
import 'features/company/company_registry.dart';
import 'features/company/company_store.dart';
import 'features/home/home_page.dart';
import 'features/welcome/onboarding_page.dart';
import 'features/welcome/splash_page.dart';
import 'l10n/app_localizations.dart';

/// Root of LockSys HR: theme, Arabic/English localization, and the launch
/// flow  Splash -> Onboarding (first launch) -> Company code (until a company
/// is saved) -> Login -> Home.
class LockSysApp extends StatefulWidget {
  const LockSysApp({
    super.key,
    required this.prefs,
    this.registry = const MockCompanyRegistry(),
  });

  final SharedPreferences prefs;

  /// Resolves a company code to the company's server. Swap the mock for the
  /// real registry here (or in main.dart).
  final CompanyRegistry registry;

  @override
  State<LockSysApp> createState() => _LockSysAppState();
}

class _LockSysAppState extends State<LockSysApp> {
  late final LocaleController _locale = LocaleController(widget.prefs);
  late final CompanyStore _company = CompanyStore(widget.prefs);

  @override
  void dispose() {
    _locale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LocaleScope(
      controller: _locale,
      child: Builder(
        builder: (context) => MaterialApp(
          debugShowCheckedModeBanner: false,
          onGenerateTitle: (c) => AppLocalizations.of(c).appName,
          theme: AppTheme.light,
          locale: LocaleScope.of(context).locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: _Flow(
            prefs: widget.prefs,
            company: _company,
            registry: widget.registry,
          ),
        ),
      ),
    );
  }
}

enum _Stage { splash, onboarding, company, login, home }

class _Flow extends StatefulWidget {
  const _Flow({
    required this.prefs,
    required this.company,
    required this.registry,
  });

  final SharedPreferences prefs;
  final CompanyStore company;
  final CompanyRegistry registry;

  @override
  State<_Flow> createState() => _FlowState();
}

class _FlowState extends State<_Flow> {
  static const _onboardedKey = 'onboarding_done';
  _Stage _stage = _Stage.splash;

  void _go(_Stage s) => setState(() => _stage = s);

  /// After the welcome screens: ask for the company code once, then sign in.
  _Stage get _afterWelcome =>
      widget.company.hasCompany ? _Stage.login : _Stage.company;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.page,
      switchInCurve: AppMotion.easeOut,
      child: switch (_stage) {
        _Stage.splash => SplashPage(
            key: const ValueKey('splash'),
            onFinished: () => _go(
              widget.prefs.getBool(_onboardedKey) ?? false
                  ? _afterWelcome
                  : _Stage.onboarding,
            ),
          ),
        _Stage.onboarding => OnboardingPage(
            key: const ValueKey('onboarding'),
            onDone: () {
              widget.prefs.setBool(_onboardedKey, true);
              _go(_afterWelcome);
            },
          ),
        _Stage.company => CompanyCodePage(
            key: const ValueKey('company'),
            registry: widget.registry,
            onConfirmed: (company) async {
              await widget.company.save(company);
              if (mounted) _go(_Stage.login);
            },
          ),
        _Stage.login => LoginPage(
            key: const ValueKey('login'),
            onSuccess: () => _go(_Stage.home),
          ),
        _Stage.home => HomePage(
            key: const ValueKey('home'),
            onLogout: () => _go(_Stage.login),
          ),
      },
    );
  }
}
