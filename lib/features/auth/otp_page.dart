import 'package:flutter/material.dart';

import '../../core/icons/app_icons.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_alert.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_otp_field.dart';
import '../../core/widgets/app_overlays.dart';
import '../../core/widgets/app_screen.dart';
import 'auth_api.dart';
import 'otp_flow.dart';

/// Wraps [text] in Unicode isolates (U+2066 .. U+2069) so a number or an address
/// keeps its left-to-right order inside an Arabic sentence.
String _ltrIsland(String text) =>
    '${String.fromCharCode(0x2066)}$text${String.fromCharCode(0x2069)}';

/// One-time code screen, shared by sign-in and password recovery. The code is
/// six digits; the screen says where it was sent, counts down before the code
/// can be sent again, and lets the employee pick another channel.
///
/// The code is requested from the server when the screen opens (and again on
/// resend / change of channel). While the server is in test mode it returns the
/// code and the screen shows it, since nothing is actually sent.
class OtpPage extends StatefulWidget {
  const OtpPage({
    super.key,
    required this.channel,
    required this.channels,
    required this.destinations,
    required this.kicker,
    required this.request,
    required this.verify,
    required this.onVerified,
  });

  final OtpChannel channel;

  /// Every channel the company allows; the link to change channel needs 2+.
  final List<OtpChannel> channels;
  final OtpDestinations destinations;
  final String kicker;

  final Future<OtpTicket> Function(OtpChannel channel) request;

  /// Throws [AuthException] when the code is not accepted.
  final Future<Object?> Function(OtpTicket ticket, String code) verify;

  /// Runs once the code is accepted, with what [verify] returned.
  final void Function(BuildContext context, Object? result) onVerified;

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> with SingleTickerProviderStateMixin {
  static const _length = 6;

  final _code = TextEditingController();
  // A controller instead of a Timer: nothing keeps running after the page closes.
  late final AnimationController _countdown = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 30),
  );
  late OtpChannel _channel = widget.channel;
  OtpTicket? _ticket;
  String? _error;
  String? _sendError;
  bool _loading = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _send();
  }

  @override
  void dispose() {
    _code.dispose();
    _countdown.dispose();
    super.dispose();
  }

  String _text(AuthException e) => e.network
      ? context.l10n.companyErrNetwork
      : e.message(Localizations.localeOf(context).languageCode);

  void _startCountdown(int seconds) {
    _countdown
      ..duration = Duration(seconds: seconds.clamp(1, 3600))
      ..forward(from: 0);
  }

  /// Asks the server for a code on [_channel]. Returns whether it worked.
  Future<bool> _send() async {
    setState(() {
      _sending = true;
      _sendError = null;
      _ticket = null;
    });
    try {
      final ticket = await widget.request(_channel);
      if (!mounted) return false;
      setState(() {
        _ticket = ticket;
        _sending = false;
      });
      _startCountdown(ticket.resendAfterSeconds);
      return true;
    } on AuthException catch (e) {
      if (!mounted) return false;
      setState(() {
        _sendError = _text(e);
        _sending = false;
      });
      // Asked too soon: the server says how long to wait.
      _startCountdown(e.retryAfterSeconds ?? 1);
      return false;
    }
  }

  Future<void> _verify() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    if (_code.text.length != _length) {
      setState(() => _error = context.l10n.errOtpIncomplete);
      return;
    }
    final ticket = _ticket;
    if (ticket == null) {
      setState(() => _error = _sendError ?? context.l10n.errOtpIncomplete);
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final result = await widget.verify(ticket, _code.text);
      if (!mounted) return;
      setState(() => _loading = false);
      widget.onVerified(context, result);
    } on AuthException catch (e) {
      if (!mounted) return;
      final dead = const {
        'OTP_EXPIRED',
        'OTP_ATTEMPTS_EXCEEDED',
        'INVALID_OTP',
      };
      setState(() {
        _loading = false;
        _error = _text(e);
        // A code that can no longer work: the screen offers to resend.
        if (dead.contains(e.code) && e.attemptsLeft == null) _code.clear();
      });
    }
  }

  Future<void> _resend() async {
    _code.clear();
    if (await _send() && mounted) {
      AppSnackbar.show(context, context.l10n.otpResent);
    }
  }

  Future<void> _changeChannel() async {
    final picked = await showOtpChannelSheet(
      context,
      destinations: widget.destinations,
      channels: widget.channels,
    );
    if (picked == null || picked == _channel || !mounted) return;
    _channel = picked;
    _error = null;
    await _resend();
  }

  String _clock(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // The masked number / address is an LTR island inside the sentence.
    final masked = _ticket?.destinationMasked ?? '';
    final destination = _ltrIsland(
      masked.isNotEmpty ? masked : widget.destinations.of(context, _channel),
    );
    return AppScreen(
      showBack: true,
      kicker: widget.kicker,
      heading: l.otpTitle,
      subtitle: l.otpSubtitle(
        channelInSentence(context, _channel),
        destination,
      ),
      children: [
        if (_sendError != null)
          AppAlert(
            title: l.otpSendFailed,
            message: _sendError,
            tone: AppTone.danger,
          ),
        if (_ticket?.devCode != null)
          AppAlert(
            title: l.otpTestCode(_ticket!.devCode!),
            message: l.otpTestCodeNote,
            tone: AppTone.info,
          ),
        AppOtpField(
          controller: _code,
          errorText: _error,
          enabled: !_loading,
          onCompleted: (_) => _verify(),
        ),
        AppButton(
          label: l.otpVerify,
          size: AppButtonSize.lg,
          icon: AppIcons.forward,
          loading: _loading || _sending,
          onPressed: _verify,
        ),
        Column(
          children: [
            Text(l.otpDidntGet, style: AppText.small),
            AnimatedBuilder(
              animation: _countdown,
              builder: (context, _) {
                final total = _countdown.duration!.inSeconds;
                final left = (total * (1 - _countdown.value)).ceil();
                if (left > 0) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      l.otpResendIn(_clock(left)),
                      textAlign: TextAlign.center,
                      style: AppText.small.copyWith(color: AppColors.hint),
                    ),
                  );
                }
                return AppTextLink(l.otpResend, onTap: _resend);
              },
            ),
            if (widget.channels.length > 1)
              AppTextLink(l.otpChangeChannel, onTap: _changeChannel),
          ],
        ),
      ],
    );
  }
}
