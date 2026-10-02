import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_tokens.dart';

/// One-time code input: [length] square cells (8px radius), always left-to-right
/// like every number in the app. One hidden field captures the digits, so the
/// code can be typed, pasted or filled by the keyboard's SMS suggestion.
///
///   AppOtpField(controller: code, errorText: errorOrNull, onCompleted: verify)
class AppOtpField extends StatefulWidget {
  const AppOtpField({
    super.key,
    required this.controller,
    this.length = 6,
    this.errorText,
    this.onCompleted,
    this.enabled = true,
    this.autofocus = true,
  });

  final TextEditingController controller;
  final int length;

  /// Shown under the cells in danger color; the cells turn red too.
  final String? errorText;

  /// Called once when the last digit is entered.
  final ValueChanged<String>? onCompleted;
  final bool enabled;
  final bool autofocus;

  @override
  State<AppOtpField> createState() => _AppOtpFieldState();
}

class _AppOtpFieldState extends State<AppOtpField> {
  final _focus = FocusNode();
  String _last = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _focus.dispose();
    super.dispose();
  }

  void _changed() {
    final v = widget.controller.text;
    if (v != _last) {
      _last = v;
      if (v.length == widget.length) widget.onCompleted?.call(v);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final hasError = widget.errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? _focus.requestFocus : null,
          child: Stack(
            children: [
              Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  children: [
                    for (var i = 0; i < widget.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _Cell(
                          char: i < text.length ? text[i] : '',
                          active:
                              _focus.hasFocus &&
                              widget.enabled &&
                              i == text.length.clamp(0, widget.length - 1),
                          error: hasError,
                          enabled: widget.enabled,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // The real input: invisible, sized to nothing, owns the keyboard.
              SizedBox(
                width: 1,
                height: 1,
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    enabled: widget.enabled,
                    autofocus: widget.autofocus,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    maxLength: widget.length,
                    showCursor: false,
                    enableInteractiveSelection: false,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(counterText: ''),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 8),
          Text(
            widget.errorText!,
            style: AppText.xs.copyWith(color: AppColors.danger),
          ),
        ],
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.char,
    required this.active,
    required this.error,
    required this.enabled,
  });

  final String char;
  final bool active;
  final bool error;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final border = error
        ? AppColors.danger
        : active
        ? AppColors.blue
        : AppColors.lineStrong;
    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.easeOut,
      height: AppSizes.buttonLg,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: !enabled
            ? AppColors.mutedBg
            : char.isNotEmpty
            ? AppColors.blue50
            : Colors.white,
        borderRadius: AppRadius.smAll,
        border: Border.all(color: border, width: active || error ? 2 : 1),
      ),
      child: Text(
        char,
        textDirection: TextDirection.ltr,
        style: AppText.stat.copyWith(fontSize: 24),
      ),
    );
  }
}
