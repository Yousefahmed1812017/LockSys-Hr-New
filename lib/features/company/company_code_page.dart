import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/icons/app_icons.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_alert.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_brand_hero.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/app_screen.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/l_pattern.dart';
import '../../l10n/app_localizations.dart';
import 'company.dart';
import 'company_registry.dart';

enum _Phase { idle, checking, found }

/// First-launch screen, shown once before sign-in. The user types the company
/// code, we resolve it to that company's server + enabled features, show what
/// was found, and only then continue. [onConfirmed] receives the company so
/// the caller can save it and move on to sign-in.
class CompanyCodePage extends StatefulWidget {
  const CompanyCodePage({
    super.key,
    required this.registry,
    required this.onConfirmed,
  });

  final CompanyRegistry registry;
  final ValueChanged<Company> onConfirmed;

  @override
  State<CompanyCodePage> createState() => _CompanyCodePageState();
}

class _CompanyCodePageState extends State<CompanyCodePage> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  _Phase _phase = _Phase.idle;
  Company? _company;
  bool _invalid = false;
  bool _network = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
        _phase = _Phase.idle;
        _company = null;
        _invalid = false;
        _network = false;
      });

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _invalid = false;
      _network = false;
    });
    if (!_form.currentState!.validate()) return;
    setState(() => _phase = _Phase.checking);
    try {
      final company = await widget.registry.resolve(_code.text);
      if (!mounted) return;
      setState(() {
        _company = company;
        _phase = _Phase.found;
      });
    } on CompanyNotFoundException {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.idle;
        _invalid = true;
      });
      _form.currentState!.validate();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.idle;
        _network = true;
      });
    }
  }

  String _featureLabel(AppLocalizations l, AppFeature f) => switch (f) {
        AppFeature.attendance => l.navAttendance,
        AppFeature.leave => l.navLeave,
        AppFeature.payslip => l.payslip,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final found = _phase == _Phase.found;
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            children: [
              AppBrandHero(subtitle: l.companySubtitle),
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
                              l.companyKicker,
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
                        child: Text(l.companyTitle, style: AppText.h1),
                      ),
                      const SizedBox(height: 20),
                      AppReveal(
                        index: 1,
                        child: AppTextField(
                          label: l.companyCodeLabel,
                          controller: _code,
                          hint: l.companyCodeHint,
                          helper: _invalid ? null : l.companyCodeHelper,
                          mono: true,
                          enabled: _phase != _Phase.checking,
                          prefixIcon: AppIcons.building,
                          textInputAction: TextInputAction.done,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z0-9_-]'),
                            ),
                            const _UpperCaseFormatter(),
                          ],
                          onChanged: (_) {
                            if (_phase == _Phase.found ||
                                _invalid ||
                                _network) {
                              _reset();
                            }
                          },
                          onSubmitted: (_) => found ? null : _verify(),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return l.companyErrRequired;
                            }
                            if (_invalid) return l.companyErrInvalid;
                            return null;
                          },
                          suffix: found
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: AppIcon(
                                    AppIcons.check,
                                    size: 20,
                                    color: AppColors.success,
                                    accentColor: AppColors.success,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      AnimatedSize(
                        duration: AppMotion.ui,
                        curve: AppMotion.easeOut,
                        alignment: Alignment.topCenter,
                        child: AnimatedSwitcher(
                          duration: AppMotion.ui,
                          switchInCurve: AppMotion.easeOut,
                          child: found && _company != null
                              ? Padding(
                                  key: const ValueKey('found'),
                                  padding: const EdgeInsets.only(top: 16),
                                  child: _FoundCard(
                                    company: _company!,
                                    featureLabel: (f) => _featureLabel(l, f),
                                  ),
                                )
                              : _network
                                  ? Padding(
                                      key: const ValueKey('network'),
                                      padding: const EdgeInsets.only(top: 16),
                                      child: AppAlert(
                                        title: l.offlineTitle,
                                        message: l.companyErrNetwork,
                                        tone: AppTone.danger,
                                      ),
                                    )
                                  : const SizedBox(
                                      key: ValueKey('none'),
                                      width: double.infinity,
                                    ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      AppReveal(
                        index: 2,
                        child: AppButton(
                          label: found
                              ? l.companyContinue
                              : (_network ? l.retry : l.companyVerify),
                          size: AppButtonSize.lg,
                          icon: AppIcons.forward,
                          loading: _phase == _Phase.checking,
                          onPressed: found
                              ? () => widget.onConfirmed(_company!)
                              : _verify,
                        ),
                      ),
                      const SizedBox(height: 24),
                      AppReveal(index: 3, child: _NoCodeNote(l: l)),
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

/// Confirmation shown after the code resolves: company name + what it offers.
class _FoundCard extends StatelessWidget {
  const _FoundCard({required this.company, required this.featureLabel});
  final Company company;
  final String Function(AppFeature) featureLabel;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppCard(
      showMark: false,
      elevated: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIconTile(
                AppIcons.check,
                tone: AppTone.success,
                solid: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.companyFound, style: AppText.xs),
                    Text(
                      company.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.h3,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(l.companyFeatures, style: AppText.label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in AppFeature.values)
                if (company.has(f)) AppBadge(featureLabel(f)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const AppIcon(AppIcons.shield, size: 18, color: AppColors.muted),
              const SizedBox(width: 8),
              Expanded(child: Text(l.companySavedNote, style: AppText.xs)),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoCodeNote extends StatelessWidget {
  const _NoCodeNote({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.blue50,
        borderRadius: AppRadius.smAll,
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppIcon(AppIcons.help, size: 22, color: AppColors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.companyNoCode,
                  style: AppText.small.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(l.companyNoCodeHelp, style: AppText.xs),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  const _UpperCaseFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
