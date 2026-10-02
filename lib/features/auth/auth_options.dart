import '../company/company.dart';
import 'otp_flow.dart';

/// How an employee can sign in.
enum LoginMethod { username, phone, email }

/// How an employee can identify themselves to recover a password.
enum RecoveryMethod { email, phone }

/// What the company allows on the sign-in and recovery screens. Everything here
/// comes from the company's features (auth.*), nothing is hard-coded: a screen
/// asks this class and shows only what it returns.
///
/// A method is offered only when its own feature is on AND at least one delivery
/// channel under it is on (a mobile-number sign-in that can send no code would
/// be a dead end).
class AuthOptions {
  const AuthOptions(this.company);
  final Company company;

  static const _phoneChannels = {
    OtpChannel.sms: AppFeature.authPhoneViaSms,
    OtpChannel.whatsapp: AppFeature.authPhoneViaWhatsapp,
    OtpChannel.email: AppFeature.authPhoneViaEmail,
  };
  static const _emailChannels = {
    OtpChannel.sms: AppFeature.authEmailViaSms,
    OtpChannel.whatsapp: AppFeature.authEmailViaWhatsapp,
    OtpChannel.email: AppFeature.authEmailViaEmail,
  };
  static const _forgotEmailChannels = {
    OtpChannel.sms: AppFeature.authForgotEmailViaSms,
    OtpChannel.whatsapp: AppFeature.authForgotEmailViaWhatsapp,
    OtpChannel.email: AppFeature.authForgotEmailViaEmail,
  };
  static const _forgotPhoneChannels = {
    OtpChannel.sms: AppFeature.authForgotPhoneViaSms,
    OtpChannel.whatsapp: AppFeature.authForgotPhoneViaWhatsapp,
    OtpChannel.email: AppFeature.authForgotPhoneViaEmail,
  };

  List<OtpChannel> _on(Map<OtpChannel, AppFeature> map) => [
    for (final e in map.entries)
      if (company.has(e.value)) e.key,
  ];

  /// Channels the company allows for the code of [method] (empty for username).
  List<OtpChannel> channelsFor(LoginMethod method) => switch (method) {
    LoginMethod.username => const [],
    LoginMethod.phone => _on(_phoneChannels),
    LoginMethod.email => _on(_emailChannels),
  };

  /// Sign-in methods to show, in screen order. Empty = the company has not
  /// turned any on (the screen explains instead of showing a blank form).
  List<LoginMethod> get loginMethods => [
    if (company.has(AppFeature.authPassword)) LoginMethod.username,
    if (company.has(AppFeature.authPhone) &&
        channelsFor(LoginMethod.phone).isNotEmpty)
      LoginMethod.phone,
    if (company.has(AppFeature.authEmail) &&
        channelsFor(LoginMethod.email).isNotEmpty)
      LoginMethod.email,
  ];

  /// Channels for the code of a password recovery done with [method].
  List<OtpChannel> recoveryChannelsFor(RecoveryMethod method) =>
      switch (method) {
        RecoveryMethod.email => _on(_forgotEmailChannels),
        RecoveryMethod.phone => _on(_forgotPhoneChannels),
      };

  /// Recovery methods to show. Empty = "forgot password" is not available.
  List<RecoveryMethod> get recoveryMethods => [
    if (company.has(AppFeature.authForgotEmail) &&
        recoveryChannelsFor(RecoveryMethod.email).isNotEmpty)
      RecoveryMethod.email,
    if (company.has(AppFeature.authForgotPhone) &&
        recoveryChannelsFor(RecoveryMethod.phone).isNotEmpty)
      RecoveryMethod.phone,
  ];

  /// Whether the "forgot password?" link is shown at all.
  bool get canRecover =>
      company.has(AppFeature.authForgot) && recoveryMethods.isNotEmpty;
}
