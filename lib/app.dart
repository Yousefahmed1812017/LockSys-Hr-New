import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/l10n/locale_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_tokens.dart';
import 'features/approvals/approvals_api.dart';
import 'features/attendance/attendance_api.dart';
import 'features/attendance/location_service.dart';
import 'features/auth/auth_api.dart';
import 'features/auth/login_page.dart';
import 'features/auth/session_store.dart';
import 'features/company/company.dart';
import 'features/company/company_code_page.dart';
import 'features/company/company_registry.dart';
import 'features/company/company_store.dart';
import 'features/home/home_page.dart';
import 'features/leave/leave_api.dart';
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
    this.authApiFor = _mockAuthApi,
    this.leaveApiFor = _mockLeaveApi,
    this.attendanceApiFor,
    this.approvalsApiFor,
    this.locationService,
    this.sessionStore,
  });

  static AuthApi _mockAuthApi(Company company) => const MockAuthApi();
  static LeaveApi _mockLeaveApi(Company company, AuthSession session) =>
      const MockLeaveApi();

  final SharedPreferences prefs;

  /// Resolves a company code to the company's server. Swap the mock for the
  /// real registry here (or in main.dart).
  final CompanyRegistry registry;

  /// The sign-in calls of a company's server. The mock accepts anything; main.dart
  /// passes the real one.
  final AuthApi Function(Company company) authApiFor;

  /// The leave calls for a signed-in session of a company.
  final LeaveApi Function(Company company, AuthSession session) leaveApiFor;

  /// The attendance calls for a signed-in session (default: the stand-in).
  final AttendanceApi Function(Company company, AuthSession session)?
  attendanceApiFor;

  /// The approvals calls for a signed-in session (default: the stand-in).
  final ApprovalsApi Function(Company company, AuthSession session)?
  approvalsApiFor;

  /// The phone's position (default: the stand-in).
  final LocationService? locationService;

  /// Keeps the signed-in session between launches. Defaults to nothing kept.
  final SessionStore? sessionStore;

  @override
  State<LockSysApp> createState() => _LockSysAppState();
}

class _LockSysAppState extends State<LockSysApp> {
  late final LocaleController _locale = LocaleController(widget.prefs);
  late final CompanyStore _company = CompanyStore(widget.prefs);

  @override
  void initState() {
    super.initState();
    // A saved single-language company locks the language from the first frame.
    _locale.forceLanguage(_company.current?.forcedLanguage);
  }

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
            authApiFor: widget.authApiFor,
            leaveApiFor: widget.leaveApiFor,
            attendanceApiFor: widget.attendanceApiFor,
            approvalsApiFor: widget.approvalsApiFor,
            locationService: widget.locationService,
            sessionStore: widget.sessionStore ?? MemorySessionStore(),
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
    required this.authApiFor,
    required this.leaveApiFor,
    required this.sessionStore,
    this.attendanceApiFor,
    this.approvalsApiFor,
    this.locationService,
  });

  final SharedPreferences prefs;
  final CompanyStore company;
  final CompanyRegistry registry;
  final AuthApi Function(Company company) authApiFor;
  final LeaveApi Function(Company company, AuthSession session) leaveApiFor;
  final SessionStore sessionStore;
  final AttendanceApi Function(Company company, AuthSession session)?
  attendanceApiFor;
  final ApprovalsApi Function(Company company, AuthSession session)?
  approvalsApiFor;
  final LocationService? locationService;

  @override
  State<_Flow> createState() => _FlowState();
}

class _FlowState extends State<_Flow> {
  static const _onboardedKey = 'onboarding_done';
  _Stage _stage = _Stage.splash;
  bool _refreshStarted = false;
  AuthApi? _api;
  AuthSession? _session;

  /// The saved session is read while the splash plays.
  late final Future<void> _restored = _restoreSession();

  AuthApi get _authApi => _api ??= widget.authApiFor(widget.company.current!);

  Future<void> _restoreSession() async {
    final saved = await widget.sessionStore.load();
    if (saved == null) return;
    if (saved.isExpired || !widget.company.hasCompany) {
      await widget.sessionStore.clear();
      return;
    }
    _session = saved;
    // Confirm with the server in the background: a token it no longer accepts
    // sends the employee back to the sign-in screen.
    unawaited(_validate(saved));
  }

  /// Errors that mean the employee must sign in again.
  static const _endsSession = {
    'TOKEN_INVALID',
    'TOKEN_REQUIRED',
    'ACCOUNT_LOCKED',
    'ACCOUNT_INACTIVE',
    'MOBILE_NOT_ENABLED',
    'EMPLOYEE_NOT_ACTIVE',
    'USER_TYPE_NOT_ALLOWED',
  };

  Future<void> _validate(AuthSession saved) async {
    try {
      final user = await _authApi.me(saved.token);
      if (!mounted || _session?.token != saved.token) return;
      // Fresh data (name, job...) for the home and the profile.
      final fresh = saved.withUser(user.isEmpty ? saved.user : user);
      await widget.sessionStore.save(fresh);
      if (mounted) setState(() => _session = fresh);
    } on AuthException catch (e) {
      if (!mounted || !_endsSession.contains(e.code)) return; // offline: keep
      await _signedOut();
    }
  }

  /// Forget the session; back to the sign-in screen if the employee was in.
  Future<void> _signedOut() async {
    _session = null;
    await widget.sessionStore.clear();
    if (mounted && _stage == _Stage.home) _go(_Stage.login);
  }

  void _go(_Stage s) => setState(() => _stage = s);

  /// After the welcome screens: ask for the company code once, then sign in.
  _Stage get _afterWelcome => !widget.company.hasCompany
      ? _Stage.company
      : (_session != null ? _Stage.home : _Stage.login);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_refreshStarted) return;
    _refreshStarted = true;
    _refreshCompany(LocaleScope.of(context)); // runs while the splash plays
  }

  /// Every launch re-reads the saved company so changes made on the server
  /// (names, language policy, features) reach the device. Offline, in
  /// maintenance or any other failure: keep what is saved. Only a code the
  /// server no longer knows sends the user back to the company screen.
  Future<void> _refreshCompany(LocaleController locale) async {
    final saved = widget.company.current;
    if (saved == null) return;
    try {
      final fresh = await widget.registry.resolve(saved.code);
      await widget.company.save(fresh);
      locale.forceLanguage(fresh.forcedLanguage);
      // Redraw so the screen on top (sign in) reads the fresh features.
      if (mounted) setState(() {});
    } on CompanyNotFoundException {
      await widget.company.clear();
      // Leave the screens that need a company BEFORE the language change
      // redraws the app.
      if (mounted && (_stage == _Stage.login || _stage == _Stage.home)) {
        _go(_Stage.company);
      }
      locale.forceLanguage(null);
    } catch (_) {
      // Keep the saved copy.
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.page,
      switchInCurve: AppMotion.easeOut,
      child: switch (_stage) {
        _Stage.splash => SplashPage(
          key: const ValueKey('splash'),
          onFinished: () async {
            await _restored;
            if (!mounted) return;
            _go(
              widget.prefs.getBool(_onboardedKey) ?? false
                  ? _afterWelcome
                  : _Stage.onboarding,
            );
          },
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
            final locale = LocaleScope.of(context);
            await widget.company.save(company);
            if (!mounted) return;
            // Arabic-only / English-only companies lock the app language.
            locale.forceLanguage(company.forcedLanguage);
            _go(_Stage.login);
          },
        ),
        _Stage.login => LoginPage(
          key: const ValueKey('login'),
          company: widget.company.current!,
          api: _authApi,
          onSuccess: (session, remember) {
            _session = session;
            // "Remember me" off: the session lives only until the app closes.
            remember
                ? widget.sessionStore.save(session)
                : widget.sessionStore.clear();
            _go(_Stage.home);
          },
        ),
        _Stage.home => HomePage(
          key: const ValueKey('home'),
          session: _session,
          leaveApi: widget.leaveApiFor(widget.company.current!, _session!),
          attendanceApi: widget.attendanceApiFor?.call(
            widget.company.current!,
            _session!,
          ),
          approvalsApi: widget.approvalsApiFor?.call(
            widget.company.current!,
            _session!,
          ),
          locationService: widget.locationService,
          onLogout: () {
            final session = _session;
            if (session != null) _authApi.logout(session.token);
            _session = null;
            widget.sessionStore.clear();
            _go(_Stage.login);
          },
        ),
      },
    );
  }
}
