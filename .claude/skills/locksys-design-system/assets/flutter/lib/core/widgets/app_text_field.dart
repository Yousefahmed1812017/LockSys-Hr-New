import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../icons/app_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'app_icon.dart';

/// Text field with the label ABOVE the field (never floating), 48px tall.
/// Error text appears under the field in danger color.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.errorText,
    this.prefixIcon,
    this.suffix,
    this.required = false,
    this.obscureText = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.readOnly = false,
    this.enabled = true,
    this.maxLines = 1,
    this.inputFormatters,
    this.mono = false,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final String? errorText;
  final AppIconData? prefixIcon;
  final Widget? suffix;
  final bool required;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool enabled;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;

  /// Numbers / IDs: LTR + monospace.
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            style: AppText.label,
            children: [
              if (required)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: AppColors.danger),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          textInputAction: textInputAction,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          onTap: onTap,
          readOnly: readOnly,
          enabled: enabled,
          minLines: maxLines > 1 ? 3 : 1,
          maxLines: maxLines,
          inputFormatters: inputFormatters,
          textDirection: mono ? TextDirection.ltr : null,
          style: mono ? AppText.mono.copyWith(fontSize: 15) : AppText.body,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            suffixIcon: suffix,
            prefixIcon: prefixIcon == null
                ? null
                : Padding(
                    padding: const EdgeInsets.all(12),
                    child: AppIcon(prefixIcon!, size: 20, color: AppColors.muted),
                  ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ),
        if (helper != null && errorText == null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(helper!, style: AppText.xs),
          ),
      ],
    );
  }
}
