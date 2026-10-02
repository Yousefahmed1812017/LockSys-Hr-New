import 'package:flutter/material.dart';

import '../../core/icons/app_icons.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_list.dart';
import '../../core/widgets/app_overlays.dart';
import 'auth_api.dart';
import 'otp_page.dart';

/// How a one-time code can reach the employee.
enum OtpChannel {
  sms(AppIcons.message),
  whatsapp(AppIcons.chat),
  email(AppIcons.mail);

  const OtpChannel(this.icon);
  final AppIconData icon;
}

/// Where each channel would deliver, already masked for display. A null value
/// means the employee did not type it, so the screen says "the one on your
/// account" instead of showing a number or an address.
class OtpDestinations {
  const OtpDestinations({this.phone, this.email});

  /// Built from what the employee typed.
  factory OtpDestinations.from({String? phone, String? email}) =>
      OtpDestinations(
        phone: phone == null ? null : maskPhone(phone),
        email: email == null ? null : maskEmail(email),
      );

  final String? phone;
  final String? email;

  String of(BuildContext context, OtpChannel channel) {
    final l = context.l10n;
    return switch (channel) {
      OtpChannel.email => email ?? l.registeredEmail,
      _ => phone ?? l.registeredPhone,
    };
  }
}

/// `+20 10 1234 5678` -> `•••• 5678`: only the last four digits stay visible.
String maskPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  final tail = digits.length <= 4
      ? digits
      : digits.substring(digits.length - 4);
  return '•••• $tail';
}

/// `mohamed@company.com` -> `m•••••@company.com`.
String maskEmail(String email) {
  final at = email.indexOf('@');
  if (at <= 0) return email;
  return '${email[0]}•••••${email.substring(at)}';
}

String channelLabel(BuildContext context, OtpChannel channel) {
  final l = context.l10n;
  return switch (channel) {
    OtpChannel.sms => l.channelSms,
    OtpChannel.whatsapp => l.channelWhatsapp,
    OtpChannel.email => l.channelEmail,
  };
}

/// The channel as used inside a sentence ("sent by text message to ...").
String channelInSentence(BuildContext context, OtpChannel channel) {
  final l = context.l10n;
  return switch (channel) {
    OtpChannel.sms => l.viaSms,
    OtpChannel.whatsapp => l.viaWhatsapp,
    OtpChannel.email => l.viaEmail,
  };
}

/// Bottom sheet that lets the employee pick how to receive the code.
/// Returns the chosen channel, or null when dismissed.
Future<OtpChannel?> showOtpChannelSheet(
  BuildContext context, {
  required OtpDestinations destinations,
  required List<OtpChannel> channels,
}) {
  return showAppBottomSheet<OtpChannel>(
    context,
    title: context.l10n.chooseCodeChannel,
    builder: (ctx) => AppListGroup(
      children: [
        for (final channel in channels)
          AppListTile(
            leading: AppIconTile(channel.icon),
            title: channelLabel(ctx, channel),
            subtitle: destinations.of(ctx, channel),
            onTap: () => Navigator.of(ctx).pop(channel),
          ),
      ],
    ),
  );
}

/// Starts the code step. [channels] are the ones the company allows: with one
/// the code screen opens straight away, with several the employee picks first.
/// The screen asks the server for the code with [request], checks what the
/// employee types with [verify] (it throws [AuthException] when the code is
/// wrong), and calls [onVerified] with what [verify] returned (what happens
/// next depends on the flow: sign in, or set a new password).
Future<void> startOtp(
  BuildContext context, {
  required OtpDestinations destinations,
  required List<OtpChannel> channels,
  required String kicker,
  required Future<OtpTicket> Function(OtpChannel channel) request,
  required Future<Object?> Function(OtpTicket ticket, String code) verify,
  required void Function(BuildContext context, Object? result) onVerified,
}) async {
  if (channels.isEmpty) return;
  final channel = channels.length == 1
      ? channels.single
      : await showOtpChannelSheet(
          context,
          destinations: destinations,
          channels: channels,
        );
  if (channel == null || !context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => OtpPage(
        channel: channel,
        channels: channels,
        destinations: destinations,
        kicker: kicker,
        request: request,
        verify: verify,
        onVerified: onVerified,
      ),
    ),
  );
}
