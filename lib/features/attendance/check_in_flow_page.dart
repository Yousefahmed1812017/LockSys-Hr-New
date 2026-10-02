import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/icons/app_icons.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_list.dart';
import '../../core/widgets/app_screen.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_api.dart' show AuthException;
import 'attendance_api.dart';
import 'attendance_state.dart';
import 'device_checks.dart';
import 'face_check_view.dart';
import 'live_face_check_view.dart';
import 'location_map_view.dart';
import 'location_service.dart';

enum _Stage { permissions, map, face, blocked, outside, error, done }

/// Check-in / check-out at one site, in steps that depend on the employee's mode:
///   location         the map (is the phone inside the work area?) then the check-in
///   face + location  the map first; inside the area it goes on to the live face
///                    check, outside it stops at the map
///   face             the live face check only
/// Before any of it the app asks for the camera / location permissions in plain
/// words, and the phone's safety checks (location off, no permission, fake
/// location...) run in the background. A problem opens a screen that says what
/// to turn off and where. The position is read from the phone and sent to the
/// server, which decides (area, IN or OUT, time) and answers with a clear reason
/// when it refuses.
///
/// Simulated: the face check ([FaceCheckView]) and, with the stand-in server,
/// the position and the phone checks.
class CheckInFlowPage extends StatefulWidget {
  const CheckInFlowPage({
    super.key,
    required this.controller,
    required this.site,
    required this.checkingOut,
    this.checks,
  });

  final AttendanceController controller;
  final AttendanceSite site;
  final bool checkingOut;
  final DeviceChecks? checks;

  @override
  State<CheckInFlowPage> createState() => _CheckInFlowPageState();
}

class _CheckInFlowPageState extends State<CheckInFlowPage> {
  late final DeviceChecks _checks =
      widget.checks ??
      (widget.controller.simulated
          ? SimulatedDeviceChecks(widget.controller)
          : PhoneDeviceChecks(widget.controller.location));
  late _Stage _stage = widget.controller.permissionsGranted
      ? _firstStep
      : _Stage.permissions;
  Future<DeviceProblem>? _check;
  DeviceProblem _problem = DeviceProblem.none;
  CheckResult? _result;
  AuthException? _failure;
  int? _distance;
  bool _sending = false;
  int _attempt = 0;

  AttendanceMode get _mode => widget.controller.mode;

  /// The map comes first whenever the location counts; else straight to the face.
  _Stage get _firstStep => _mode.usesLocation ? _Stage.map : _Stage.face;
  String _lang = 'ar';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lang = Localizations.localeOf(context).languageCode;
  }

  @override
  void initState() {
    super.initState();
    if (_stage == _Stage.map || _stage == _Stage.face) _startChecks();
  }

  void _block(DeviceProblem problem) {
    if (!mounted) return;
    setState(() {
      _problem = problem;
      _stage = _Stage.blocked;
    });
  }

  /// Runs the phone checks without showing anything; a problem opens its screen.
  void _startChecks() {
    final run = _checks.run();
    _check = run;
    run.then((problem) {
      if (!mounted || _check != run) return;
      if (problem != DeviceProblem.none) _block(problem);
    });
  }

  Future<void> _allow() async {
    widget.controller.grantPermissions();
    try {
      await widget.controller.location.requestPermission();
    } on DeviceProblemException catch (e) {
      _block(e.problem);
      return;
    }
    if (!mounted) return;
    setState(() => _stage = _firstStep);
    _startChecks();
  }

  /// "Open settings": the employee fixes it and comes back.
  void _openSettings() {
    widget.controller.selectDevice(DeviceProblem.none);
    _retry();
  }

  void _retry() {
    setState(() {
      _attempt++;
      _stage = _firstStep;
    });
    _startChecks();
  }

  Future<LocationFix> _locate() async {
    try {
      final fix = await widget.controller.location.current();
      // The company decides: BLOCK stops it here, before the face check; RECORD lets
      // it through and the server flags the record for HR.
      if (fix.isMock && widget.controller.mockPolicy != 'RECORD') {
        _block(DeviceProblem.mockLocation);
        throw const DeviceProblemException(DeviceProblem.mockLocation);
      }
      return fix;
    } on DeviceProblemException catch (e) {
      _block(e.problem);
      rethrow;
    }
  }

  /// The face check passed: read the position and send the check-in.
  Future<void> _faceVerified() async {
    final problem = await (_check ?? Future.value(DeviceProblem.none));
    if (!mounted || _stage != _Stage.face || problem != DeviceProblem.none) {
      return;
    }
    try {
      await _submit(await _locate());
    } on DeviceProblemException {
      // _locate opened the screen.
    }
  }

  Future<void> _submit(LocationFix fix) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final result = await widget.controller.api.check(
        siteId: widget.site.id,
        fix: fix,
        faceVerified: _mode.usesFace,
        languageCode: _lang,
      );
      if (!mounted) return;
      widget.controller.applyResult(result);
      setState(() {
        _result = result;
        _stage = _Stage.done;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'MOCK_LOCATION') {
        _block(DeviceProblem.mockLocation);
      } else if (e.code == 'OUTSIDE_AREA') {
        setState(() {
          _distance = e is AttendanceRefusal ? e.distanceMeters : null;
          _stage = _Stage.outside;
        });
      } else {
        setState(() {
          _failure = e;
          _stage = _Stage.error;
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppTopBar(
        showBack: true,
        title: widget.checkingOut ? l.verifyTitleOut : l.verifyTitleIn,
      ),
      body: KeyedSubtree(
        key: ValueKey('$_stage-$_attempt'),
        child: switch (_stage) {
          _Stage.permissions => _PermissionsView(mode: _mode, onAllow: _allow),
          _Stage.map => LocationMapView(
            site: widget.site,
            locate: _locate,
            // Inside the area: on to the face when there is one, else check in.
            actionLabel: _mode.usesFace
                ? l.mapContinue
                : (widget.checkingOut ? l.checkOut : l.checkIn),
            busy: _sending,
            liveMap: !widget.controller.simulated,
            onCheck: (fix) {
              if (_mode.usesFace) {
                setState(() => _stage = _Stage.face);
              } else {
                _submit(fix);
              }
            },
          ),
          _Stage.face =>
            widget.controller.simulated
                ? FaceCheckView(
                    confirmingLocation: _mode.usesLocation,
                    onVerified: _faceVerified,
                  )
                : LiveFaceCheckView(
                    confirmingLocation: _mode.usesLocation,
                    onVerified: _faceVerified,
                    onRetry: _retry,
                  ),
          _Stage.blocked => _BlockedView(
            problem: _problem,
            onAction: _openSettings,
          ),
          _Stage.outside => AppEmptyState(
            icon: AppIcons.location,
            tone: AppTone.danger,
            title: l.mapOutside,
            message: _distance == null ? null : l.mapDistance(_distance!),
            actionLabel: l.blkRetry,
            onAction: _retry,
          ),
          _Stage.error => AppEmptyState(
            icon: AppIcons.warning,
            tone: AppTone.danger,
            title: _failure!.network
                ? l.offlineTitle
                : _failure!.message(_lang),
            message: _failure!.network ? l.offlineMessage : null,
            actionLabel: l.blkRetry,
            onAction: _retry,
          ),
          _Stage.done => _DoneView(
            result: _result!,
            siteName: widget.site.name(_lang),
            mode: _mode,
            checkingOut: widget.checkingOut,
          ),
        },
      ),
    );
  }
}

/// Asks, in plain words, for what the check-in needs before the system dialogs.
class _PermissionsView extends StatelessWidget {
  const _PermissionsView({required this.mode, required this.onAllow});
  final AttendanceMode mode;
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    const Center(child: AppIconTile(AppIcons.shield, size: 72)),
                    const SizedBox(height: 16),
                    Text(
                      l.permTitle,
                      textAlign: TextAlign.center,
                      style: AppText.h1,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.permMessage,
                      textAlign: TextAlign.center,
                      style: AppText.small,
                    ),
                    const SizedBox(height: 20),
                    AppListGroup(
                      children: [
                        if (mode.usesFace)
                          AppListTile(
                            leading: const AppIconTile(AppIcons.camera),
                            title: l.permCameraTitle,
                            subtitle: l.permCameraMsg,
                          ),
                        // The location is asked for in every mode: the
                        // coordinates always go with the check-in.
                        AppListTile(
                          leading: const AppIconTile(AppIcons.location),
                          title: l.permLocationTitle,
                          subtitle: l.permLocationMsg,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              8,
              AppSpacing.gutter,
              16,
            ),
            child: AppButton(
              label: l.permAllow,
              size: AppButtonSize.lg,
              onPressed: onAllow,
            ),
          ),
        ),
      ],
    );
  }
}

/// One screen per problem the phone reports: what is wrong, how to fix it, and
/// the button that opens the right settings.
class _BlockedView extends StatelessWidget {
  const _BlockedView({required this.problem, required this.onAction});
  final DeviceProblem problem;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (icon, title, message, action) = switch (problem) {
      DeviceProblem.locationOff => (
        AppIcons.location,
        l.blkLocationOffTitle,
        l.blkLocationOffMsg,
        l.blkLocationOffAction,
      ),
      DeviceProblem.permissionDenied => (
        AppIcons.lock,
        l.blkPermissionTitle,
        l.blkPermissionMsg,
        l.blkPermissionAction,
      ),
      DeviceProblem.mockLocation => (
        AppIcons.warning,
        l.blkMockTitle,
        l.blkMockMsg,
        l.blkMockAction,
      ),
      DeviceProblem.vpn => (
        AppIcons.globe,
        l.blkVpnTitle,
        l.blkVpnMsg,
        l.blkVpnAction,
      ),
      DeviceProblem.developerOptions => (
        AppIcons.settings,
        l.blkDevTitle,
        l.blkDevMsg,
        l.blkDevAction,
      ),
      DeviceProblem.none => (AppIcons.check, '', '', l.blkRetry),
    };
    return AppEmptyState(
      icon: icon,
      tone: AppTone.danger,
      title: title,
      message: message,
      actionLabel: action,
      onAction: onAction,
    );
  }
}

class _DoneView extends StatelessWidget {
  const _DoneView({
    required this.result,
    required this.siteName,
    required this.mode,
    required this.checkingOut,
  });
  final CheckResult result;
  final String siteName;
  final AttendanceMode mode;
  final bool checkingOut;

  String _modeLabel(AppLocalizations l) => switch (mode) {
    AttendanceMode.faceAndLocation => l.doneModeFaceLocation,
    AttendanceMode.face => l.doneModeFace,
    AttendanceMode.location => l.doneModeLocation,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    const AppIconTile(
                      AppIcons.check,
                      size: 88,
                      tone: AppTone.success,
                      solid: true,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      checkingOut ? l.doneCheckedOut : l.doneCheckedIn,
                      textAlign: TextAlign.center,
                      style: AppText.h1,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      result.time,
                      textDirection: TextDirection.ltr,
                      style: AppText.stat.copyWith(fontSize: 36),
                    ),
                    const SizedBox(height: 24),
                    AppListGroup(
                      children: [
                        AppListTile(
                          leading: const AppIconTile(AppIcons.location),
                          title: l.doneBranch,
                          subtitle: siteName,
                        ),
                        AppListTile(
                          leading: const AppIconTile(AppIcons.shield),
                          title: l.doneMode,
                          subtitle: _modeLabel(l),
                        ),
                        AppListTile(
                          leading: const AppIconTile(AppIcons.clock),
                          title: l.doneTime,
                          trailing: Text(
                            result.time,
                            textDirection: TextDirection.ltr,
                            style: AppText.mono,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              8,
              AppSpacing.gutter,
              16,
            ),
            child: AppButton(
              label: l.doneButton,
              size: AppButtonSize.lg,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ],
    );
  }
}
