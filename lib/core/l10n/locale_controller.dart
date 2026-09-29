import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';

/// Holds the app language (Arabic / English) and remembers the choice.
/// Read it anywhere with [LocaleScope.of]; flip with [toggle] / [setLocale].
class LocaleController extends ChangeNotifier {
  LocaleController(this._prefs, {Locale? initial})
      : _locale = initial ?? _read(_prefs);

  static const _key = 'app_locale';
  final SharedPreferences _prefs;
  Locale _locale;

  Locale get locale => _locale;
  bool get isArabic => _locale.languageCode == 'ar';

  static Locale _read(SharedPreferences p) =>
      Locale(p.getString(_key) == 'en' ? 'en' : 'ar'); // Arabic by default

  Future<void> setLocale(Locale locale) async {
    if (locale.languageCode == _locale.languageCode) return;
    _locale = Locale(locale.languageCode);
    notifyListeners();
    await _prefs.setString(_key, _locale.languageCode);
  }

  Future<void> toggle() =>
      setLocale(Locale(isArabic ? 'en' : 'ar'));
}

/// Exposes the [LocaleController] to the whole tree.
class LocaleScope extends InheritedNotifier<LocaleController> {
  const LocaleScope({
    super.key,
    required LocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static LocaleController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LocaleScope>();
    assert(scope != null, 'LocaleScope not found above this context');
    return scope!.notifier!;
  }
}

/// Converts Arabic-Indic digits (٠-٩) to Western digits (0-9). The app shows
/// Western digits in both languages (dates from DateFormat come back as
/// Arabic-Indic in the Arabic locale).
String toWesternDigits(String input) {
  const from = '٠١٢٣٤٥٦٧٨٩';
  final b = StringBuffer();
  for (final ch in input.split('')) {
    final i = from.indexOf(ch);
    b.write(i < 0 ? ch : '$i');
  }
  return b.toString();
}

extension AppL10nX on BuildContext {
  /// `context.l10n.next` — localized strings for the current language.
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// true when the current language is Arabic (RTL).
  bool get isArabic => Localizations.localeOf(this).languageCode == 'ar';
}
