import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @companyKicker.
  ///
  /// In ar, this message translates to:
  /// **'الخطوة الأولى'**
  String get companyKicker;

  /// No description provided for @companyTitle.
  ///
  /// In ar, this message translates to:
  /// **'كود الشركة'**
  String get companyTitle;

  /// No description provided for @companySubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أدخل الكود الذي حصلت عليه من شركتك لنوصلك بخدماتها.'**
  String get companySubtitle;

  /// No description provided for @companyCodeLabel.
  ///
  /// In ar, this message translates to:
  /// **'كود الشركة'**
  String get companyCodeLabel;

  /// No description provided for @companyCodeHint.
  ///
  /// In ar, this message translates to:
  /// **'مثال: ACME01'**
  String get companyCodeHint;

  /// No description provided for @companyCodeHelper.
  ///
  /// In ar, this message translates to:
  /// **'حروف وأرقام إنجليزية، ستجده لدى مسؤول الموارد البشرية.'**
  String get companyCodeHelper;

  /// No description provided for @companyVerify.
  ///
  /// In ar, this message translates to:
  /// **'تحقق من الكود'**
  String get companyVerify;

  /// No description provided for @companyContinue.
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get companyContinue;

  /// No description provided for @companyErrRequired.
  ///
  /// In ar, this message translates to:
  /// **'أدخل كود الشركة'**
  String get companyErrRequired;

  /// No description provided for @companyErrInvalid.
  ///
  /// In ar, this message translates to:
  /// **'كود الشركة غير صحيح. تأكد منه وحاول مرة أخرى.'**
  String get companyErrInvalid;

  /// No description provided for @companyErrNetwork.
  ///
  /// In ar, this message translates to:
  /// **'تعذر الاتصال بالخادم. تأكد من الإنترنت وحاول مرة أخرى.'**
  String get companyErrNetwork;

  /// No description provided for @companyFound.
  ///
  /// In ar, this message translates to:
  /// **'تم التعرف على الشركة'**
  String get companyFound;

  /// No description provided for @companyFeatures.
  ///
  /// In ar, this message translates to:
  /// **'الخدمات المتاحة'**
  String get companyFeatures;

  /// No description provided for @companySavedNote.
  ///
  /// In ar, this message translates to:
  /// **'لن نطلب الكود مرة أخرى على هذا الجهاز.'**
  String get companySavedNote;

  /// No description provided for @companyNoCode.
  ///
  /// In ar, this message translates to:
  /// **'ليس لديك كود؟'**
  String get companyNoCode;

  /// No description provided for @companyNoCodeHelp.
  ///
  /// In ar, this message translates to:
  /// **'تواصل مع مسؤول الموارد البشرية في شركتك.'**
  String get companyNoCodeHelp;

  /// No description provided for @appName.
  ///
  /// In ar, this message translates to:
  /// **'LockSys HR'**
  String get appName;

  /// No description provided for @splashTagline.
  ///
  /// In ar, this message translates to:
  /// **'الموارد البشرية'**
  String get splashTagline;

  /// No description provided for @back.
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get back;

  /// No description provided for @next.
  ///
  /// In ar, this message translates to:
  /// **'التالي'**
  String get next;

  /// No description provided for @start.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ الآن'**
  String get start;

  /// No description provided for @skip.
  ///
  /// In ar, this message translates to:
  /// **'تخطي'**
  String get skip;

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'تراجع'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get confirm;

  /// No description provided for @retry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get retry;

  /// No description provided for @offlineTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد اتصال'**
  String get offlineTitle;

  /// No description provided for @offlineMessage.
  ///
  /// In ar, this message translates to:
  /// **'تأكد من الإنترنت وحاول مرة أخرى.'**
  String get offlineMessage;

  /// No description provided for @comingSoon.
  ///
  /// In ar, this message translates to:
  /// **'قريبًا'**
  String get comingSoon;

  /// No description provided for @comingSoonMessage.
  ///
  /// In ar, this message translates to:
  /// **'هذه الشاشة قيد التطوير.'**
  String get comingSoonMessage;

  /// No description provided for @language.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get language;

  /// No description provided for @languageName.
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get languageName;

  /// No description provided for @switchLanguageLabel.
  ///
  /// In ar, this message translates to:
  /// **'English'**
  String get switchLanguageLabel;

  /// No description provided for @chooseLanguage.
  ///
  /// In ar, this message translates to:
  /// **'اختر اللغة'**
  String get chooseLanguage;

  /// No description provided for @arabic.
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get arabic;

  /// No description provided for @english.
  ///
  /// In ar, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @onb1Title.
  ///
  /// In ar, this message translates to:
  /// **'سجّل حضورك بلمسة واحدة'**
  String get onb1Title;

  /// No description provided for @onb1Desc.
  ///
  /// In ar, this message translates to:
  /// **'بالبصمة أو بموقع الفرع، تسجّل حضورك وانصرافك من هاتفك في ثوانٍ.'**
  String get onb1Desc;

  /// No description provided for @onb2Title.
  ///
  /// In ar, this message translates to:
  /// **'كل طلباتك في مكان واحد'**
  String get onb2Title;

  /// No description provided for @onb2Desc.
  ///
  /// In ar, this message translates to:
  /// **'قدّم إجازتك وخطاباتك، وتابع الموافقات لحظة بلحظة بدون أوراق.'**
  String get onb2Desc;

  /// No description provided for @onb3Title.
  ///
  /// In ar, this message translates to:
  /// **'راتبك ومستنداتك بأمان'**
  String get onb3Title;

  /// No description provided for @onb3Desc.
  ///
  /// In ar, this message translates to:
  /// **'اطّلع على كشف راتبك وعقدك في أي وقت، وبياناتك محمية بالكامل.'**
  String get onb3Desc;

  /// No description provided for @artBranch.
  ///
  /// In ar, this message translates to:
  /// **'الفرع الرئيسي'**
  String get artBranch;

  /// No description provided for @artInRange.
  ///
  /// In ar, this message translates to:
  /// **'داخل النطاق'**
  String get artInRange;

  /// No description provided for @artCheckinTime.
  ///
  /// In ar, this message translates to:
  /// **'وقت الحضور'**
  String get artCheckinTime;

  /// No description provided for @artPresent.
  ///
  /// In ar, this message translates to:
  /// **'حاضر'**
  String get artPresent;

  /// No description provided for @artAnnualLeave.
  ///
  /// In ar, this message translates to:
  /// **'إجازة سنوية'**
  String get artAnnualLeave;

  /// No description provided for @artThreeDays.
  ///
  /// In ar, this message translates to:
  /// **'3 أيام'**
  String get artThreeDays;

  /// No description provided for @artApproved.
  ///
  /// In ar, this message translates to:
  /// **'تمت الموافقة'**
  String get artApproved;

  /// No description provided for @artDirectManager.
  ///
  /// In ar, this message translates to:
  /// **'المدير المباشر'**
  String get artDirectManager;

  /// No description provided for @artBalanceDays.
  ///
  /// In ar, this message translates to:
  /// **'18 يوم'**
  String get artBalanceDays;

  /// No description provided for @artBalanceLeft.
  ///
  /// In ar, this message translates to:
  /// **'رصيد متبقٍ'**
  String get artBalanceLeft;

  /// No description provided for @artNetSalary.
  ///
  /// In ar, this message translates to:
  /// **'صافي الراتب'**
  String get artNetSalary;

  /// No description provided for @artCurrency.
  ///
  /// In ar, this message translates to:
  /// **'ر.س'**
  String get artCurrency;

  /// No description provided for @artTransferred.
  ///
  /// In ar, this message translates to:
  /// **'تم التحويل'**
  String get artTransferred;

  /// No description provided for @artBasic.
  ///
  /// In ar, this message translates to:
  /// **'الراتب الأساسي'**
  String get artBasic;

  /// No description provided for @artAllowances.
  ///
  /// In ar, this message translates to:
  /// **'البدلات'**
  String get artAllowances;

  /// No description provided for @artDeductions.
  ///
  /// In ar, this message translates to:
  /// **'الاستقطاعات'**
  String get artDeductions;

  /// No description provided for @artProtected.
  ///
  /// In ar, this message translates to:
  /// **'بياناتك محمية'**
  String get artProtected;

  /// No description provided for @artPdpl.
  ///
  /// In ar, this message translates to:
  /// **'متوافق مع PDPL'**
  String get artPdpl;

  /// No description provided for @loginWelcome.
  ///
  /// In ar, this message translates to:
  /// **'مرحبًا بعودتك'**
  String get loginWelcome;

  /// No description provided for @loginTitle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'سجّل دخولك لإدارة حضورك وإجازاتك وراتبك.'**
  String get loginSubtitle;

  /// No description provided for @username.
  ///
  /// In ar, this message translates to:
  /// **'اسم المستخدم أو رقم الموظف'**
  String get username;

  /// No description provided for @usernameHint.
  ///
  /// In ar, this message translates to:
  /// **'مثال: EMP-0012'**
  String get usernameHint;

  /// No description provided for @password.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور'**
  String get password;

  /// No description provided for @passwordHint.
  ///
  /// In ar, this message translates to:
  /// **'••••••••'**
  String get passwordHint;

  /// No description provided for @showPassword.
  ///
  /// In ar, this message translates to:
  /// **'إظهار كلمة المرور'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء كلمة المرور'**
  String get hidePassword;

  /// No description provided for @rememberMe.
  ///
  /// In ar, this message translates to:
  /// **'تذكرني'**
  String get rememberMe;

  /// No description provided for @forgotPassword.
  ///
  /// In ar, this message translates to:
  /// **'نسيت كلمة المرور؟'**
  String get forgotPassword;

  /// No description provided for @loginButton.
  ///
  /// In ar, this message translates to:
  /// **'دخول'**
  String get loginButton;

  /// No description provided for @biometricLogin.
  ///
  /// In ar, this message translates to:
  /// **'الدخول بالبصمة'**
  String get biometricLogin;

  /// No description provided for @errUsernameRequired.
  ///
  /// In ar, this message translates to:
  /// **'أدخل اسم المستخدم أو رقم الموظف'**
  String get errUsernameRequired;

  /// No description provided for @errPasswordRequired.
  ///
  /// In ar, this message translates to:
  /// **'أدخل كلمة المرور'**
  String get errPasswordRequired;

  /// No description provided for @errPasswordShort.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور قصيرة جدًا (6 أحرف على الأقل)'**
  String get errPasswordShort;

  /// No description provided for @contactHr.
  ///
  /// In ar, this message translates to:
  /// **'تواصل مع الموارد البشرية لاستعادة كلمة المرور.'**
  String get contactHr;

  /// No description provided for @sampleName.
  ///
  /// In ar, this message translates to:
  /// **'يوسف الزرقاني'**
  String get sampleName;

  /// No description provided for @greeting.
  ///
  /// In ar, this message translates to:
  /// **'صباح الخير'**
  String get greeting;

  /// No description provided for @navHome.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get navHome;

  /// No description provided for @navAttendance.
  ///
  /// In ar, this message translates to:
  /// **'الحضور'**
  String get navAttendance;

  /// No description provided for @navLeave.
  ///
  /// In ar, this message translates to:
  /// **'الإجازات'**
  String get navLeave;

  /// No description provided for @navAccount.
  ///
  /// In ar, this message translates to:
  /// **'حسابي'**
  String get navAccount;

  /// No description provided for @notCheckedIn.
  ///
  /// In ar, this message translates to:
  /// **'لم تسجّل حضورك بعد'**
  String get notCheckedIn;

  /// No description provided for @checkIn.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل حضور'**
  String get checkIn;

  /// No description provided for @checkedIn.
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل الحضور'**
  String get checkedIn;

  /// No description provided for @quickServices.
  ///
  /// In ar, this message translates to:
  /// **'خدمات سريعة'**
  String get quickServices;

  /// No description provided for @leaveRequest.
  ///
  /// In ar, this message translates to:
  /// **'طلب إجازة'**
  String get leaveRequest;

  /// No description provided for @leaveRequestSub.
  ///
  /// In ar, this message translates to:
  /// **'سنوية · مرضية · بدون راتب'**
  String get leaveRequestSub;

  /// No description provided for @payslip.
  ///
  /// In ar, this message translates to:
  /// **'كشف الراتب'**
  String get payslip;

  /// No description provided for @payslipSub.
  ///
  /// In ar, this message translates to:
  /// **'آخر كشف: أغسطس 2026'**
  String get payslipSub;

  /// No description provided for @newBadge.
  ///
  /// In ar, this message translates to:
  /// **'جديد'**
  String get newBadge;

  /// No description provided for @noticeTitle.
  ///
  /// In ar, this message translates to:
  /// **'تنبيه'**
  String get noticeTitle;

  /// No description provided for @contractNotice.
  ///
  /// In ar, this message translates to:
  /// **'عقدك ينتهي خلال 30 يومًا.'**
  String get contractNotice;

  /// No description provided for @accountGroupPrefs.
  ///
  /// In ar, this message translates to:
  /// **'التفضيلات'**
  String get accountGroupPrefs;

  /// No description provided for @accountGroupSupport.
  ///
  /// In ar, this message translates to:
  /// **'الدعم'**
  String get accountGroupSupport;

  /// No description provided for @helpSupport.
  ///
  /// In ar, this message translates to:
  /// **'المساعدة والدعم'**
  String get helpSupport;

  /// No description provided for @helpSupportSub.
  ///
  /// In ar, this message translates to:
  /// **'تواصل مع الموارد البشرية'**
  String get helpSupportSub;

  /// No description provided for @logout.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get logout;

  /// No description provided for @logoutTitle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج؟'**
  String get logoutTitle;

  /// No description provided for @logoutMessage.
  ///
  /// In ar, this message translates to:
  /// **'ستحتاج إلى تسجيل الدخول مرة أخرى.'**
  String get logoutMessage;

  /// No description provided for @versionLabel.
  ///
  /// In ar, this message translates to:
  /// **'الإصدار {version}'**
  String versionLabel(String version);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
