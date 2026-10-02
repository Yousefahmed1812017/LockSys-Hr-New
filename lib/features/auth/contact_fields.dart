import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/icons/app_icons.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/widgets/app_text_field.dart';

/// Mobile number and e-mail inputs shared by sign-in and password recovery.

final _phoneRule = RegExp(r'^\+?[0-9]{8,15}$');
final _emailRule = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Digits, a leading +, and the spaces people type to read a number.
String normalizePhone(String value) => value.replaceAll(' ', '');

AppTextField phoneField(
  BuildContext context, {
  required TextEditingController controller,
  TextInputAction? action,
  ValueChanged<String>? onSubmitted,
}) {
  final l = context.l10n;
  return AppTextField(
    label: l.phoneNumber,
    controller: controller,
    hint: l.phoneHint,
    helper: l.phoneHelper,
    mono: true,
    prefixIcon: AppIcons.phone,
    keyboardType: TextInputType.phone,
    textInputAction: action,
    onSubmitted: onSubmitted,
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
    validator: (v) {
      final value = normalizePhone(v ?? '');
      if (value.isEmpty) return l.errPhoneRequired;
      if (!_phoneRule.hasMatch(value)) return l.errPhoneInvalid;
      return null;
    },
  );
}

AppTextField emailField(
  BuildContext context, {
  required TextEditingController controller,
  TextInputAction? action,
  ValueChanged<String>? onSubmitted,
}) {
  final l = context.l10n;
  return AppTextField(
    label: l.emailAddress,
    controller: controller,
    hint: l.emailHint,
    mono: true,
    prefixIcon: AppIcons.mail,
    keyboardType: TextInputType.emailAddress,
    textInputAction: action,
    onSubmitted: onSubmitted,
    validator: (v) {
      final value = (v ?? '').trim();
      if (value.isEmpty) return l.errEmailRequired;
      if (!_emailRule.hasMatch(value)) return l.errEmailInvalid;
      return null;
    },
  );
}
