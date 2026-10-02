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

  /// No description provided for @loginMethodUsername.
  ///
  /// In ar, this message translates to:
  /// **'اسم المستخدم'**
  String get loginMethodUsername;

  /// No description provided for @loginMethodPhone.
  ///
  /// In ar, this message translates to:
  /// **'الموبايل'**
  String get loginMethodPhone;

  /// No description provided for @loginMethodEmail.
  ///
  /// In ar, this message translates to:
  /// **'البريد'**
  String get loginMethodEmail;

  /// No description provided for @phoneNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم الموبايل'**
  String get phoneNumber;

  /// No description provided for @phoneHint.
  ///
  /// In ar, this message translates to:
  /// **'+20 10 1234 5678'**
  String get phoneHint;

  /// No description provided for @phoneHelper.
  ///
  /// In ar, this message translates to:
  /// **'أدخل الرقم مع رمز الدولة.'**
  String get phoneHelper;

  /// No description provided for @emailAddress.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني'**
  String get emailAddress;

  /// No description provided for @emailHint.
  ///
  /// In ar, this message translates to:
  /// **'name@company.com'**
  String get emailHint;

  /// No description provided for @errPhoneRequired.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رقم الموبايل'**
  String get errPhoneRequired;

  /// No description provided for @errPhoneInvalid.
  ///
  /// In ar, this message translates to:
  /// **'رقم الموبايل غير صحيح'**
  String get errPhoneInvalid;

  /// No description provided for @errEmailRequired.
  ///
  /// In ar, this message translates to:
  /// **'أدخل البريد الإلكتروني'**
  String get errEmailRequired;

  /// No description provided for @errEmailInvalid.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني غير صحيح'**
  String get errEmailInvalid;

  /// No description provided for @sendCode.
  ///
  /// In ar, this message translates to:
  /// **'إرسال رمز التحقق'**
  String get sendCode;

  /// No description provided for @chooseCodeChannel.
  ///
  /// In ar, this message translates to:
  /// **'كيف تريد استلام الرمز؟'**
  String get chooseCodeChannel;

  /// No description provided for @channelSms.
  ///
  /// In ar, this message translates to:
  /// **'رسالة نصية SMS'**
  String get channelSms;

  /// No description provided for @channelWhatsapp.
  ///
  /// In ar, this message translates to:
  /// **'واتساب'**
  String get channelWhatsapp;

  /// No description provided for @channelEmail.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني'**
  String get channelEmail;

  /// No description provided for @viaSms.
  ///
  /// In ar, this message translates to:
  /// **'رسالة نصية'**
  String get viaSms;

  /// No description provided for @viaWhatsapp.
  ///
  /// In ar, this message translates to:
  /// **'واتساب'**
  String get viaWhatsapp;

  /// No description provided for @viaEmail.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني'**
  String get viaEmail;

  /// No description provided for @registeredPhone.
  ///
  /// In ar, this message translates to:
  /// **'رقم الموبايل المسجّل في حسابك'**
  String get registeredPhone;

  /// No description provided for @registeredEmail.
  ///
  /// In ar, this message translates to:
  /// **'البريد المسجّل في حسابك'**
  String get registeredEmail;

  /// No description provided for @otpKicker.
  ///
  /// In ar, this message translates to:
  /// **'التحقق'**
  String get otpKicker;

  /// No description provided for @otpTitle.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رمز التحقق'**
  String get otpTitle;

  /// No description provided for @otpSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أرسلنا رمزًا من 6 أرقام عبر {channel} إلى {destination}.'**
  String otpSubtitle(String channel, String destination);

  /// No description provided for @otpVerify.
  ///
  /// In ar, this message translates to:
  /// **'تحقق'**
  String get otpVerify;

  /// No description provided for @errOtpIncomplete.
  ///
  /// In ar, this message translates to:
  /// **'أدخل الرمز المكوّن من 6 أرقام'**
  String get errOtpIncomplete;

  /// No description provided for @otpDidntGet.
  ///
  /// In ar, this message translates to:
  /// **'لم يصلك الرمز؟'**
  String get otpDidntGet;

  /// No description provided for @otpResendIn.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك إعادة الإرسال بعد {time}'**
  String otpResendIn(String time);

  /// No description provided for @otpResend.
  ///
  /// In ar, this message translates to:
  /// **'إعادة إرسال الرمز'**
  String get otpResend;

  /// No description provided for @otpResent.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال رمز جديد'**
  String get otpResent;

  /// No description provided for @otpChangeChannel.
  ///
  /// In ar, this message translates to:
  /// **'تغيير طريقة الاستلام'**
  String get otpChangeChannel;

  /// No description provided for @forgotKicker.
  ///
  /// In ar, this message translates to:
  /// **'استعادة الحساب'**
  String get forgotKicker;

  /// No description provided for @forgotTitle.
  ///
  /// In ar, this message translates to:
  /// **'نسيت كلمة المرور؟'**
  String get forgotTitle;

  /// No description provided for @forgotSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'اختر كيف نتحقق من هويتك لإعادة تعيين كلمة المرور.'**
  String get forgotSubtitle;

  /// No description provided for @resetKicker.
  ///
  /// In ar, this message translates to:
  /// **'كلمة مرور جديدة'**
  String get resetKicker;

  /// No description provided for @resetTitle.
  ///
  /// In ar, this message translates to:
  /// **'عيّن كلمة مرور جديدة'**
  String get resetTitle;

  /// No description provided for @resetSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'اختر كلمة مرور قوية لا تستخدمها في مكان آخر.'**
  String get resetSubtitle;

  /// No description provided for @newPassword.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور الجديدة'**
  String get newPassword;

  /// No description provided for @confirmPassword.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد كلمة المرور'**
  String get confirmPassword;

  /// No description provided for @errPasswordMismatch.
  ///
  /// In ar, this message translates to:
  /// **'كلمتا المرور غير متطابقتين'**
  String get errPasswordMismatch;

  /// No description provided for @resetSave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ كلمة المرور'**
  String get resetSave;

  /// No description provided for @resetDone.
  ///
  /// In ar, this message translates to:
  /// **'تم تغيير كلمة المرور. سجّل الدخول بها.'**
  String get resetDone;

  /// No description provided for @signInUnavailableTitle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول غير متاح'**
  String get signInUnavailableTitle;

  /// No description provided for @signInUnavailableMessage.
  ///
  /// In ar, this message translates to:
  /// **'لم تفعّل شركتك أي طريقة للدخول بعد. تواصل مع الموارد البشرية.'**
  String get signInUnavailableMessage;

  /// No description provided for @attendanceTitle.
  ///
  /// In ar, this message translates to:
  /// **'الحضور والانصراف'**
  String get attendanceTitle;

  /// No description provided for @attendanceTileNotYet.
  ///
  /// In ar, this message translates to:
  /// **'لم تسجّل حضورك اليوم'**
  String get attendanceTileNotYet;

  /// No description provided for @attendanceTileIn.
  ///
  /// In ar, this message translates to:
  /// **'حضرت الساعة {time}'**
  String attendanceTileIn(String time);

  /// No description provided for @attendanceTileDone.
  ///
  /// In ar, this message translates to:
  /// **'اكتمل يوم اليوم'**
  String get attendanceTileDone;

  /// No description provided for @leaveTileBalance.
  ///
  /// In ar, this message translates to:
  /// **'رصيدك {days} يومًا'**
  String leaveTileBalance(int days);

  /// No description provided for @servicesTitle.
  ///
  /// In ar, this message translates to:
  /// **'الخدمات'**
  String get servicesTitle;

  /// No description provided for @shiftToday.
  ///
  /// In ar, this message translates to:
  /// **'دوام اليوم {start} – {end}'**
  String shiftToday(String start, String end);

  /// No description provided for @checkedInAtTime.
  ///
  /// In ar, this message translates to:
  /// **'حضرت الساعة {time}'**
  String checkedInAtTime(String time);

  /// No description provided for @checkedOutAtTime.
  ///
  /// In ar, this message translates to:
  /// **'انصرفت الساعة {time}'**
  String checkedOutAtTime(String time);

  /// No description provided for @dayComplete.
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل حضورك وانصرافك اليوم'**
  String get dayComplete;

  /// No description provided for @workedLabel.
  ///
  /// In ar, this message translates to:
  /// **'ساعات العمل'**
  String get workedLabel;

  /// No description provided for @checkOut.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل انصراف'**
  String get checkOut;

  /// No description provided for @verifyMethodTitle.
  ///
  /// In ar, this message translates to:
  /// **'طريقة التحقق'**
  String get verifyMethodTitle;

  /// No description provided for @methodBiometric.
  ///
  /// In ar, this message translates to:
  /// **'بصمة + موقع + صورة'**
  String get methodBiometric;

  /// No description provided for @methodQr.
  ///
  /// In ar, this message translates to:
  /// **'بصمة + QR'**
  String get methodQr;

  /// No description provided for @stepsTitle.
  ///
  /// In ar, this message translates to:
  /// **'خطوات التحقق'**
  String get stepsTitle;

  /// No description provided for @stepLocation.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الموقع'**
  String get stepLocation;

  /// No description provided for @stepLocationSub.
  ///
  /// In ar, this message translates to:
  /// **'يجب أن تكون داخل نطاق الفرع'**
  String get stepLocationSub;

  /// No description provided for @stepCamera.
  ///
  /// In ar, this message translates to:
  /// **'صورة شخصية'**
  String get stepCamera;

  /// No description provided for @stepCameraSub.
  ///
  /// In ar, this message translates to:
  /// **'التقط صورة لوجهك'**
  String get stepCameraSub;

  /// No description provided for @stepQr.
  ///
  /// In ar, this message translates to:
  /// **'مسح رمز QR'**
  String get stepQr;

  /// No description provided for @stepQrSub.
  ///
  /// In ar, this message translates to:
  /// **'امسح رمز الفرع'**
  String get stepQrSub;

  /// No description provided for @stepFingerprint.
  ///
  /// In ar, this message translates to:
  /// **'البصمة'**
  String get stepFingerprint;

  /// No description provided for @stepFingerprintSub.
  ///
  /// In ar, this message translates to:
  /// **'المس مستشعر البصمة'**
  String get stepFingerprintSub;

  /// No description provided for @permNote.
  ///
  /// In ar, this message translates to:
  /// **'سيطلب التطبيق إذن الموقع والكاميرا عند أول استخدام.'**
  String get permNote;

  /// No description provided for @todayLog.
  ///
  /// In ar, this message translates to:
  /// **'سجل اليوم'**
  String get todayLog;

  /// No description provided for @logCheckIn.
  ///
  /// In ar, this message translates to:
  /// **'الحضور'**
  String get logCheckIn;

  /// No description provided for @logCheckOut.
  ///
  /// In ar, this message translates to:
  /// **'الانصراف'**
  String get logCheckOut;

  /// No description provided for @monthSummary.
  ///
  /// In ar, this message translates to:
  /// **'هذا الشهر'**
  String get monthSummary;

  /// No description provided for @statPresent.
  ///
  /// In ar, this message translates to:
  /// **'حضور'**
  String get statPresent;

  /// No description provided for @statLate.
  ///
  /// In ar, this message translates to:
  /// **'تأخير'**
  String get statLate;

  /// No description provided for @statAbsent.
  ///
  /// In ar, this message translates to:
  /// **'غياب'**
  String get statAbsent;

  /// No description provided for @recentRecords.
  ///
  /// In ar, this message translates to:
  /// **'آخر السجلات'**
  String get recentRecords;

  /// No description provided for @statusPresent.
  ///
  /// In ar, this message translates to:
  /// **'حاضر'**
  String get statusPresent;

  /// No description provided for @statusLate.
  ///
  /// In ar, this message translates to:
  /// **'متأخر'**
  String get statusLate;

  /// No description provided for @statusAbsent.
  ///
  /// In ar, this message translates to:
  /// **'غائب'**
  String get statusAbsent;

  /// No description provided for @statusOnLeave.
  ///
  /// In ar, this message translates to:
  /// **'إجازة'**
  String get statusOnLeave;

  /// No description provided for @verifyTitleIn.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الحضور'**
  String get verifyTitleIn;

  /// No description provided for @verifyTitleOut.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الانصراف'**
  String get verifyTitleOut;

  /// No description provided for @verifyStepOf.
  ///
  /// In ar, this message translates to:
  /// **'الخطوة {n} من {total}'**
  String verifyStepOf(int n, int total);

  /// No description provided for @locSearching.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تحديد موقعك...'**
  String get locSearching;

  /// No description provided for @locFound.
  ///
  /// In ar, this message translates to:
  /// **'أنت داخل نطاق الفرع'**
  String get locFound;

  /// No description provided for @locDistance.
  ///
  /// In ar, this message translates to:
  /// **'تبعد {meters} م عن موقع الفرع'**
  String locDistance(int meters);

  /// No description provided for @camHint.
  ///
  /// In ar, this message translates to:
  /// **'ضع وجهك داخل الإطار'**
  String get camHint;

  /// No description provided for @camCapture.
  ///
  /// In ar, this message translates to:
  /// **'التقاط صورة'**
  String get camCapture;

  /// No description provided for @camRetake.
  ///
  /// In ar, this message translates to:
  /// **'إعادة الالتقاط'**
  String get camRetake;

  /// No description provided for @camCaptured.
  ///
  /// In ar, this message translates to:
  /// **'تم التقاط الصورة'**
  String get camCaptured;

  /// No description provided for @qrHint.
  ///
  /// In ar, this message translates to:
  /// **'وجّه الكاميرا نحو رمز QR الخاص بالفرع'**
  String get qrHint;

  /// No description provided for @qrScanning.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ المسح...'**
  String get qrScanning;

  /// No description provided for @qrFound.
  ///
  /// In ar, this message translates to:
  /// **'تم التعرف على رمز الفرع'**
  String get qrFound;

  /// No description provided for @fpHint.
  ///
  /// In ar, this message translates to:
  /// **'المس مستشعر البصمة للتحقق من هويتك'**
  String get fpHint;

  /// No description provided for @fpVerify.
  ///
  /// In ar, this message translates to:
  /// **'التحقق بالبصمة'**
  String get fpVerify;

  /// No description provided for @fpVerifying.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التحقق...'**
  String get fpVerifying;

  /// No description provided for @fpDone.
  ///
  /// In ar, this message translates to:
  /// **'تم التحقق من هويتك'**
  String get fpDone;

  /// No description provided for @doneCheckedIn.
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل حضورك'**
  String get doneCheckedIn;

  /// No description provided for @doneCheckedOut.
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل انصرافك'**
  String get doneCheckedOut;

  /// No description provided for @doneBranch.
  ///
  /// In ar, this message translates to:
  /// **'الفرع'**
  String get doneBranch;

  /// No description provided for @doneTime.
  ///
  /// In ar, this message translates to:
  /// **'الوقت'**
  String get doneTime;

  /// No description provided for @doneButton.
  ///
  /// In ar, this message translates to:
  /// **'تم'**
  String get doneButton;

  /// No description provided for @leaveTitle.
  ///
  /// In ar, this message translates to:
  /// **'الإجازات'**
  String get leaveTitle;

  /// No description provided for @leaveSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'رصيدك وطلباتك'**
  String get leaveSubtitle;

  /// No description provided for @leaveSick.
  ///
  /// In ar, this message translates to:
  /// **'إجازة مرضية'**
  String get leaveSick;

  /// No description provided for @leaveEmergency.
  ///
  /// In ar, this message translates to:
  /// **'إجازة عارضة'**
  String get leaveEmergency;

  /// No description provided for @leaveUnpaid.
  ///
  /// In ar, this message translates to:
  /// **'إجازة بدون راتب'**
  String get leaveUnpaid;

  /// No description provided for @leaveBalanceLeft.
  ///
  /// In ar, this message translates to:
  /// **'{days} يومًا متبقية'**
  String leaveBalanceLeft(int days);

  /// No description provided for @leaveOfTotal.
  ///
  /// In ar, this message translates to:
  /// **'من أصل {total} يومًا'**
  String leaveOfTotal(int total);

  /// No description provided for @leaveNoLimit.
  ///
  /// In ar, this message translates to:
  /// **'بدون حد'**
  String get leaveNoLimit;

  /// No description provided for @daysCount.
  ///
  /// In ar, this message translates to:
  /// **'{count} يوم'**
  String daysCount(int count);

  /// No description provided for @leaveNewRequest.
  ///
  /// In ar, this message translates to:
  /// **'طلب إجازة جديدة'**
  String get leaveNewRequest;

  /// No description provided for @leaveMyRequests.
  ///
  /// In ar, this message translates to:
  /// **'طلباتي'**
  String get leaveMyRequests;

  /// No description provided for @filterAll.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get filterAll;

  /// No description provided for @statusPending.
  ///
  /// In ar, this message translates to:
  /// **'قيد المراجعة'**
  String get statusPending;

  /// No description provided for @statusApproved.
  ///
  /// In ar, this message translates to:
  /// **'معتمد'**
  String get statusApproved;

  /// No description provided for @statusRejected.
  ///
  /// In ar, this message translates to:
  /// **'مرفوض'**
  String get statusRejected;

  /// No description provided for @leaveEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات'**
  String get leaveEmptyTitle;

  /// No description provided for @leaveEmptyMessage.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات بهذه الحالة.'**
  String get leaveEmptyMessage;

  /// No description provided for @showAll.
  ///
  /// In ar, this message translates to:
  /// **'عرض الكل'**
  String get showAll;

  /// No description provided for @detailType.
  ///
  /// In ar, this message translates to:
  /// **'النوع'**
  String get detailType;

  /// No description provided for @detailFrom.
  ///
  /// In ar, this message translates to:
  /// **'من'**
  String get detailFrom;

  /// No description provided for @detailTo.
  ///
  /// In ar, this message translates to:
  /// **'إلى'**
  String get detailTo;

  /// No description provided for @detailDays.
  ///
  /// In ar, this message translates to:
  /// **'المدة'**
  String get detailDays;

  /// No description provided for @detailReason.
  ///
  /// In ar, this message translates to:
  /// **'السبب'**
  String get detailReason;

  /// No description provided for @detailStatus.
  ///
  /// In ar, this message translates to:
  /// **'الحالة'**
  String get detailStatus;

  /// No description provided for @detailSubmitted.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الطلب'**
  String get detailSubmitted;

  /// No description provided for @noReason.
  ///
  /// In ar, this message translates to:
  /// **'لم يُذكر سبب'**
  String get noReason;

  /// No description provided for @cancelRequest.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الطلب'**
  String get cancelRequest;

  /// No description provided for @cancelRequestTitle.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الطلب؟'**
  String get cancelRequestTitle;

  /// No description provided for @cancelRequestMessage.
  ///
  /// In ar, this message translates to:
  /// **'لن يصل الطلب إلى مديرك.'**
  String get cancelRequestMessage;

  /// No description provided for @keepRequest.
  ///
  /// In ar, this message translates to:
  /// **'الاحتفاظ بالطلب'**
  String get keepRequest;

  /// No description provided for @requestCancelled.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء الطلب'**
  String get requestCancelled;

  /// No description provided for @leaveFormTitle.
  ///
  /// In ar, this message translates to:
  /// **'طلب إجازة جديد'**
  String get leaveFormTitle;

  /// No description provided for @leaveFormSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'يصل طلبك إلى مديرك المباشر.'**
  String get leaveFormSubtitle;

  /// No description provided for @leaveBalanceInfo.
  ///
  /// In ar, this message translates to:
  /// **'رصيدك المتاح من الإجازة السنوية {days} يومًا.'**
  String leaveBalanceInfo(int days);

  /// No description provided for @leaveType.
  ///
  /// In ar, this message translates to:
  /// **'نوع الإجازة'**
  String get leaveType;

  /// No description provided for @leaveTypeHint.
  ///
  /// In ar, this message translates to:
  /// **'اختر نوع الإجازة'**
  String get leaveTypeHint;

  /// No description provided for @dateFrom.
  ///
  /// In ar, this message translates to:
  /// **'من تاريخ'**
  String get dateFrom;

  /// No description provided for @dateTo.
  ///
  /// In ar, this message translates to:
  /// **'إلى تاريخ'**
  String get dateTo;

  /// No description provided for @dateHint.
  ///
  /// In ar, this message translates to:
  /// **'اختر التاريخ'**
  String get dateHint;

  /// No description provided for @leaveDurationLabel.
  ///
  /// In ar, this message translates to:
  /// **'المدة'**
  String get leaveDurationLabel;

  /// No description provided for @leaveReason.
  ///
  /// In ar, this message translates to:
  /// **'السبب'**
  String get leaveReason;

  /// No description provided for @leaveReasonHint.
  ///
  /// In ar, this message translates to:
  /// **'اكتب سبب الإجازة (اختياري)'**
  String get leaveReasonHint;

  /// No description provided for @attachDocument.
  ///
  /// In ar, this message translates to:
  /// **'إرفاق مستند'**
  String get attachDocument;

  /// No description provided for @removeAttachment.
  ///
  /// In ar, this message translates to:
  /// **'إزالة المرفق'**
  String get removeAttachment;

  /// No description provided for @leaveSubmit.
  ///
  /// In ar, this message translates to:
  /// **'إرسال الطلب'**
  String get leaveSubmit;

  /// No description provided for @leaveSubmitted.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال طلبك إلى المدير'**
  String get leaveSubmitted;

  /// No description provided for @errLeaveType.
  ///
  /// In ar, this message translates to:
  /// **'اختر نوع الإجازة'**
  String get errLeaveType;

  /// No description provided for @errDateFrom.
  ///
  /// In ar, this message translates to:
  /// **'اختر تاريخ البداية'**
  String get errDateFrom;

  /// No description provided for @errDateTo.
  ///
  /// In ar, this message translates to:
  /// **'اختر تاريخ النهاية'**
  String get errDateTo;

  /// No description provided for @errDateOrder.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ النهاية قبل تاريخ البداية'**
  String get errDateOrder;

  /// No description provided for @errBalance.
  ///
  /// In ar, this message translates to:
  /// **'رصيدك لا يكفي. المتاح {days} يومًا.'**
  String errBalance(int days);

  /// No description provided for @sampleManager.
  ///
  /// In ar, this message translates to:
  /// **'أحمد المنصوري'**
  String get sampleManager;

  /// No description provided for @tileLetters.
  ///
  /// In ar, this message translates to:
  /// **'الخطابات'**
  String get tileLetters;

  /// No description provided for @tileDocuments.
  ///
  /// In ar, this message translates to:
  /// **'المستندات'**
  String get tileDocuments;

  /// No description provided for @tileNotifications.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات'**
  String get tileNotifications;

  /// No description provided for @tileSecurity.
  ///
  /// In ar, this message translates to:
  /// **'الأمان'**
  String get tileSecurity;

  /// No description provided for @signInFailedTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تسجيل الدخول'**
  String get signInFailedTitle;

  /// No description provided for @otpSendFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر إرسال الرمز'**
  String get otpSendFailed;

  /// No description provided for @otpTestCode.
  ///
  /// In ar, this message translates to:
  /// **'الرمز التجريبي: {code}'**
  String otpTestCode(String code);

  /// No description provided for @otpTestCodeNote.
  ///
  /// In ar, this message translates to:
  /// **'وضع تجريبي: لا يتم إرسال أي رسالة حاليًا، لذلك يظهر الرمز هنا.'**
  String get otpTestCodeNote;

  /// No description provided for @profileGroupWork.
  ///
  /// In ar, this message translates to:
  /// **'العمل'**
  String get profileGroupWork;

  /// No description provided for @profileGroupContact.
  ///
  /// In ar, this message translates to:
  /// **'التواصل'**
  String get profileGroupContact;

  /// No description provided for @profileJob.
  ///
  /// In ar, this message translates to:
  /// **'الوظيفة'**
  String get profileJob;

  /// No description provided for @profileDepartment.
  ///
  /// In ar, this message translates to:
  /// **'القسم'**
  String get profileDepartment;

  /// No description provided for @profileSite.
  ///
  /// In ar, this message translates to:
  /// **'موقع العمل'**
  String get profileSite;

  /// No description provided for @profileManager.
  ///
  /// In ar, this message translates to:
  /// **'المدير المباشر'**
  String get profileManager;

  /// No description provided for @profileStatus.
  ///
  /// In ar, this message translates to:
  /// **'حالة العمل'**
  String get profileStatus;

  /// No description provided for @profileHireDate.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ التعيين'**
  String get profileHireDate;

  /// No description provided for @profileCompany.
  ///
  /// In ar, this message translates to:
  /// **'الشركة'**
  String get profileCompany;

  /// No description provided for @profileBranch.
  ///
  /// In ar, this message translates to:
  /// **'الفرع'**
  String get profileBranch;

  /// No description provided for @profileCategory.
  ///
  /// In ar, this message translates to:
  /// **'الفئة'**
  String get profileCategory;

  /// No description provided for @leaveHubSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'اختر ما تريد'**
  String get leaveHubSubtitle;

  /// No description provided for @leaveMyLeaves.
  ///
  /// In ar, this message translates to:
  /// **'إجازاتي'**
  String get leaveMyLeaves;

  /// No description provided for @leaveMyBalances.
  ///
  /// In ar, this message translates to:
  /// **'أرصدتي'**
  String get leaveMyBalances;

  /// No description provided for @leaveRequestTile.
  ///
  /// In ar, this message translates to:
  /// **'طلب إجازة'**
  String get leaveRequestTile;

  /// No description provided for @statusOpen.
  ///
  /// In ar, this message translates to:
  /// **'قيد المعالجة'**
  String get statusOpen;

  /// No description provided for @statusCancelled.
  ///
  /// In ar, this message translates to:
  /// **'ملغاة'**
  String get statusCancelled;

  /// No description provided for @leaveShowMore.
  ///
  /// In ar, this message translates to:
  /// **'عرض المزيد'**
  String get leaveShowMore;

  /// No description provided for @leaveDaysValue.
  ///
  /// In ar, this message translates to:
  /// **'{n} يوم'**
  String leaveDaysValue(String n);

  /// No description provided for @leaveCountTotal.
  ///
  /// In ar, this message translates to:
  /// **'{count} طلب'**
  String leaveCountTotal(int count);

  /// No description provided for @balTitle.
  ///
  /// In ar, this message translates to:
  /// **'أرصدتي'**
  String get balTitle;

  /// No description provided for @balSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'المتبقي من كل نوع إجازة'**
  String get balSubtitle;

  /// No description provided for @balRemaining.
  ///
  /// In ar, this message translates to:
  /// **'المتبقي'**
  String get balRemaining;

  /// No description provided for @balUsed.
  ///
  /// In ar, this message translates to:
  /// **'المستخدم'**
  String get balUsed;

  /// No description provided for @balEntitlement.
  ///
  /// In ar, this message translates to:
  /// **'الاستحقاق'**
  String get balEntitlement;

  /// No description provided for @balCarried.
  ///
  /// In ar, this message translates to:
  /// **'المرحّل'**
  String get balCarried;

  /// No description provided for @balTotalAvailable.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي المتاح'**
  String get balTotalAvailable;

  /// No description provided for @balSickPrevious.
  ///
  /// In ar, this message translates to:
  /// **'السابق'**
  String get balSickPrevious;

  /// No description provided for @balSickCurrent.
  ///
  /// In ar, this message translates to:
  /// **'هذا العام'**
  String get balSickCurrent;

  /// No description provided for @balSickChronic.
  ///
  /// In ar, this message translates to:
  /// **'المزمنة'**
  String get balSickChronic;

  /// No description provided for @balInjury.
  ///
  /// In ar, this message translates to:
  /// **'إصابة عمل'**
  String get balInjury;

  /// No description provided for @balDeduction.
  ///
  /// In ar, this message translates to:
  /// **'بدون مرتب (خصم)'**
  String get balDeduction;

  /// No description provided for @balAbsence.
  ///
  /// In ar, this message translates to:
  /// **'غياب'**
  String get balAbsence;

  /// No description provided for @balOtherTitle.
  ///
  /// In ar, this message translates to:
  /// **'أخرى'**
  String get balOtherTitle;

  /// No description provided for @balYearLabel.
  ///
  /// In ar, this message translates to:
  /// **'السنة'**
  String get balYearLabel;

  /// No description provided for @balNoneTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد رصيد مسجّل'**
  String get balNoneTitle;

  /// No description provided for @balNoneMessage.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد رصيد إجازات لهذه السنة بعد.'**
  String get balNoneMessage;

  /// No description provided for @leaveApprovalSteps.
  ///
  /// In ar, this message translates to:
  /// **'مراحل الاعتماد'**
  String get leaveApprovalSteps;

  /// No description provided for @stepApproved.
  ///
  /// In ar, this message translates to:
  /// **'تمت الموافقة'**
  String get stepApproved;

  /// No description provided for @stepPending.
  ///
  /// In ar, this message translates to:
  /// **'في الانتظار'**
  String get stepPending;

  /// No description provided for @stepRejected.
  ///
  /// In ar, this message translates to:
  /// **'مرفوض'**
  String get stepRejected;

  /// No description provided for @detailWaitingAt.
  ///
  /// In ar, this message translates to:
  /// **'في انتظار'**
  String get detailWaitingAt;

  /// No description provided for @detailStatusReason.
  ///
  /// In ar, this message translates to:
  /// **'سبب الحالة'**
  String get detailStatusReason;

  /// No description provided for @detailSubstitute.
  ///
  /// In ar, this message translates to:
  /// **'الموظف البديل'**
  String get detailSubstitute;

  /// No description provided for @leaveListSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'كل طلبات إجازاتك'**
  String get leaveListSubtitle;

  /// No description provided for @detailWorkingDays.
  ///
  /// In ar, this message translates to:
  /// **'أيام العمل'**
  String get detailWorkingDays;

  /// No description provided for @detailWeekend.
  ///
  /// In ar, this message translates to:
  /// **'أيام الإجازة الأسبوعية'**
  String get detailWeekend;

  /// No description provided for @detailHolidays.
  ///
  /// In ar, this message translates to:
  /// **'العطلات الرسمية'**
  String get detailHolidays;

  /// No description provided for @balDaysLeft.
  ///
  /// In ar, this message translates to:
  /// **'يومًا متبقيًا'**
  String get balDaysLeft;

  /// No description provided for @attTileCheckIn.
  ///
  /// In ar, this message translates to:
  /// **'التحضير'**
  String get attTileCheckIn;

  /// No description provided for @attTileMonth.
  ///
  /// In ar, this message translates to:
  /// **'ملخص الشهر'**
  String get attTileMonth;

  /// No description provided for @attTileAbsence.
  ///
  /// In ar, this message translates to:
  /// **'الغياب'**
  String get attTileAbsence;

  /// No description provided for @attendanceHubSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'اختر ما تريد'**
  String get attendanceHubSubtitle;

  /// No description provided for @attHowTitle.
  ///
  /// In ar, this message translates to:
  /// **'طريقة التحضير'**
  String get attHowTitle;

  /// No description provided for @attModeFaceLocation.
  ///
  /// In ar, this message translates to:
  /// **'التحقق من الوجه'**
  String get attModeFaceLocation;

  /// No description provided for @attModeFace.
  ///
  /// In ar, this message translates to:
  /// **'التحقق من الوجه'**
  String get attModeFace;

  /// No description provided for @attModeLocation.
  ///
  /// In ar, this message translates to:
  /// **'الموقع'**
  String get attModeLocation;

  /// No description provided for @attHowFaceLocation.
  ///
  /// In ar, this message translates to:
  /// **'تحقق سريع من وجهك بالكاميرا. وموقعك بيتأكد تلقائيًا في الخلفية.'**
  String get attHowFaceLocation;

  /// No description provided for @attHowFace.
  ///
  /// In ar, this message translates to:
  /// **'تحقق سريع من وجهك بالكاميرا.'**
  String get attHowFace;

  /// No description provided for @attHowLocation.
  ///
  /// In ar, this message translates to:
  /// **'كن داخل منطقة عملك، ثم أكّد من الخريطة.'**
  String get attHowLocation;

  /// No description provided for @permTitle.
  ///
  /// In ar, this message translates to:
  /// **'قبل ما نبدأ'**
  String get permTitle;

  /// No description provided for @permMessage.
  ///
  /// In ar, this message translates to:
  /// **'عشان تسجّل حضورك التطبيق محتاج إذنك. بيتستخدم فقط وقت التحضير.'**
  String get permMessage;

  /// No description provided for @permLocationTitle.
  ///
  /// In ar, this message translates to:
  /// **'الموقع'**
  String get permLocationTitle;

  /// No description provided for @permLocationMsg.
  ///
  /// In ar, this message translates to:
  /// **'للتأكد إنك في مكان عملك.'**
  String get permLocationMsg;

  /// No description provided for @permCameraTitle.
  ///
  /// In ar, this message translates to:
  /// **'الكاميرا'**
  String get permCameraTitle;

  /// No description provided for @permCameraMsg.
  ///
  /// In ar, this message translates to:
  /// **'للتأكد بشكل مباشر إنك أنت.'**
  String get permCameraMsg;

  /// No description provided for @permAllow.
  ///
  /// In ar, this message translates to:
  /// **'سماح ومتابعة'**
  String get permAllow;

  /// No description provided for @blkLocationOffTitle.
  ///
  /// In ar, this message translates to:
  /// **'خدمة الموقع مقفولة'**
  String get blkLocationOffTitle;

  /// No description provided for @blkLocationOffMsg.
  ///
  /// In ar, this message translates to:
  /// **'شغّل الموقع (GPS) من إعدادات الهاتف، ثم ارجع.'**
  String get blkLocationOffMsg;

  /// No description provided for @blkLocationOffAction.
  ///
  /// In ar, this message translates to:
  /// **'فتح إعدادات الموقع'**
  String get blkLocationOffAction;

  /// No description provided for @blkPermissionTitle.
  ///
  /// In ar, this message translates to:
  /// **'محتاجين إذن الموقع'**
  String get blkPermissionTitle;

  /// No description provided for @blkPermissionMsg.
  ///
  /// In ar, this message translates to:
  /// **'اسمح لـ LockSys HR باستخدام موقعك من إعدادات التطبيق، ثم ارجع.'**
  String get blkPermissionMsg;

  /// No description provided for @blkPermissionAction.
  ///
  /// In ar, this message translates to:
  /// **'فتح إعدادات التطبيق'**
  String get blkPermissionAction;

  /// No description provided for @blkMockTitle.
  ///
  /// In ar, this message translates to:
  /// **'تم اكتشاف موقع وهمي'**
  String get blkMockTitle;

  /// No description provided for @blkMockMsg.
  ///
  /// In ar, this message translates to:
  /// **'اقفل أي تطبيق بيغيّر موقعك، ثم حاول مرة أخرى.'**
  String get blkMockMsg;

  /// No description provided for @blkMockAction.
  ///
  /// In ar, this message translates to:
  /// **'حاول مرة أخرى'**
  String get blkMockAction;

  /// No description provided for @blkVpnTitle.
  ///
  /// In ar, this message translates to:
  /// **'اقفل الـ VPN'**
  String get blkVpnTitle;

  /// No description provided for @blkVpnMsg.
  ///
  /// In ar, this message translates to:
  /// **'الـ VPN أو البروكسي بيخفي موقعك الحقيقي. اقفله ثم ارجع.'**
  String get blkVpnMsg;

  /// No description provided for @blkVpnAction.
  ///
  /// In ar, this message translates to:
  /// **'فتح إعدادات الشبكة'**
  String get blkVpnAction;

  /// No description provided for @blkDevTitle.
  ///
  /// In ar, this message translates to:
  /// **'خيارات المطوّر مفتوحة'**
  String get blkDevTitle;

  /// No description provided for @blkDevMsg.
  ///
  /// In ar, this message translates to:
  /// **'اقفل خيارات المطوّر من إعدادات الهاتف، ثم ارجع.'**
  String get blkDevMsg;

  /// No description provided for @blkDevAction.
  ///
  /// In ar, this message translates to:
  /// **'فتح إعدادات المطوّر'**
  String get blkDevAction;

  /// No description provided for @blkRetry.
  ///
  /// In ar, this message translates to:
  /// **'حاول مرة أخرى'**
  String get blkRetry;

  /// No description provided for @faceStepOf.
  ///
  /// In ar, this message translates to:
  /// **'الخطوة {n} من {total}'**
  String faceStepOf(int n, int total);

  /// No description provided for @faceGetReady.
  ///
  /// In ar, this message translates to:
  /// **'ضع وجهك داخل الشكل البيضاوي وانظر للأمام'**
  String get faceGetReady;

  /// No description provided for @faceRight.
  ///
  /// In ar, this message translates to:
  /// **'لف رأسك لليمين'**
  String get faceRight;

  /// No description provided for @faceLeft.
  ///
  /// In ar, this message translates to:
  /// **'لف رأسك لليسار'**
  String get faceLeft;

  /// No description provided for @faceUp.
  ///
  /// In ar, this message translates to:
  /// **'انظر لأعلى'**
  String get faceUp;

  /// No description provided for @faceDown.
  ///
  /// In ar, this message translates to:
  /// **'انظر لأسفل'**
  String get faceDown;

  /// No description provided for @faceHold.
  ///
  /// In ar, this message translates to:
  /// **'ثبّت وجهك'**
  String get faceHold;

  /// No description provided for @faceVerified.
  ///
  /// In ar, this message translates to:
  /// **'تم التحقق، أنت صاحب الحساب'**
  String get faceVerified;

  /// No description provided for @faceConfirmingLocation.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تأكيد موقعك...'**
  String get faceConfirmingLocation;

  /// No description provided for @faceLiveNote.
  ///
  /// In ar, this message translates to:
  /// **'تحقق مباشر. الصورة أو الشاشة لن تنفع.'**
  String get faceLiveNote;

  /// No description provided for @mapLocating.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تحديد موقعك...'**
  String get mapLocating;

  /// No description provided for @mapInside.
  ///
  /// In ar, this message translates to:
  /// **'أنت داخل {place}'**
  String mapInside(String place);

  /// No description provided for @mapOutside.
  ///
  /// In ar, this message translates to:
  /// **'أنت خارج منطقة العمل'**
  String get mapOutside;

  /// No description provided for @mapDistance.
  ///
  /// In ar, this message translates to:
  /// **'على بعد حوالي {m} متر'**
  String mapDistance(int m);

  /// No description provided for @mapRefresh.
  ///
  /// In ar, this message translates to:
  /// **'تحديث موقعي'**
  String get mapRefresh;

  /// No description provided for @mapPlace.
  ///
  /// In ar, this message translates to:
  /// **'منطقة عملك'**
  String get mapPlace;

  /// No description provided for @attSamplePlace.
  ///
  /// In ar, this message translates to:
  /// **'المصنع'**
  String get attSamplePlace;

  /// No description provided for @doneMode.
  ///
  /// In ar, this message translates to:
  /// **'تم التحقق بـ'**
  String get doneMode;

  /// No description provided for @doneModeFaceLocation.
  ///
  /// In ar, this message translates to:
  /// **'التحقق من الوجه والموقع'**
  String get doneModeFaceLocation;

  /// No description provided for @doneModeFace.
  ///
  /// In ar, this message translates to:
  /// **'التحقق من الوجه'**
  String get doneModeFace;

  /// No description provided for @doneModeLocation.
  ///
  /// In ar, this message translates to:
  /// **'الموقع'**
  String get doneModeLocation;

  /// No description provided for @attSitesTitle.
  ///
  /// In ar, this message translates to:
  /// **'مواقعك'**
  String get attSitesTitle;

  /// No description provided for @attLeftBadge.
  ///
  /// In ar, this message translates to:
  /// **'منصرف'**
  String get attLeftBadge;

  /// No description provided for @attNotEnabledTitle.
  ///
  /// In ar, this message translates to:
  /// **'التحضير من التطبيق غير مفعّل'**
  String get attNotEnabledTitle;

  /// No description provided for @attNotEnabledMsg.
  ///
  /// In ar, this message translates to:
  /// **'اطلب من الموارد البشرية تفعيل التحضير من التطبيق لك.'**
  String get attNotEnabledMsg;

  /// No description provided for @attNoSitesTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد موقع مخصص'**
  String get attNoSitesTitle;

  /// No description provided for @attNoSitesMsg.
  ///
  /// In ar, this message translates to:
  /// **'ليس لك موقع عمل بعد. تواصل مع الموارد البشرية.'**
  String get attNoSitesMsg;

  /// No description provided for @attInTime.
  ///
  /// In ar, this message translates to:
  /// **'وقت الحضور'**
  String get attInTime;

  /// No description provided for @attOutTime.
  ///
  /// In ar, this message translates to:
  /// **'وقت الانصراف'**
  String get attOutTime;

  /// No description provided for @attAreasTitle.
  ///
  /// In ar, this message translates to:
  /// **'مناطق العمل'**
  String get attAreasTitle;

  /// No description provided for @faceNoFace.
  ///
  /// In ar, this message translates to:
  /// **'مش شايف وجهك. ادخل داخل الشكل البيضاوي'**
  String get faceNoFace;

  /// No description provided for @faceMultiple.
  ///
  /// In ar, this message translates to:
  /// **'لازم تكون أنت بس قدّام الكاميرا'**
  String get faceMultiple;

  /// No description provided for @faceTooFar.
  ///
  /// In ar, this message translates to:
  /// **'قرّب شوية'**
  String get faceTooFar;

  /// No description provided for @faceTooClose.
  ///
  /// In ar, this message translates to:
  /// **'ابعد شوية'**
  String get faceTooClose;

  /// No description provided for @faceLookStraight.
  ///
  /// In ar, this message translates to:
  /// **'انظر للكاميرا مباشرة'**
  String get faceLookStraight;

  /// No description provided for @faceCameraDeniedTitle.
  ///
  /// In ar, this message translates to:
  /// **'محتاجين إذن الكاميرا'**
  String get faceCameraDeniedTitle;

  /// No description provided for @faceCameraDeniedMsg.
  ///
  /// In ar, this message translates to:
  /// **'اسمح لـ LockSys HR باستخدام الكاميرا من إعدادات التطبيق، ثم حاول مرة أخرى.'**
  String get faceCameraDeniedMsg;

  /// No description provided for @faceCameraFailedTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تشغيل الكاميرا'**
  String get faceCameraFailedTitle;

  /// No description provided for @faceCameraFailedMsg.
  ///
  /// In ar, this message translates to:
  /// **'اقفل أي تطبيق بيستخدم الكاميرا، ثم حاول مرة أخرى.'**
  String get faceCameraFailedMsg;

  /// No description provided for @faceFailedTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر التحقق إنك أنت'**
  String get faceFailedTitle;

  /// No description provided for @faceFailedMsg.
  ///
  /// In ar, this message translates to:
  /// **'انظر للكاميرا واتبع الحركات، ثم حاول مرة أخرى.'**
  String get faceFailedMsg;

  /// No description provided for @monthPresent.
  ///
  /// In ar, this message translates to:
  /// **'حضور'**
  String get monthPresent;

  /// No description provided for @monthAbsent.
  ///
  /// In ar, this message translates to:
  /// **'غياب'**
  String get monthAbsent;

  /// No description provided for @monthOff.
  ///
  /// In ar, this message translates to:
  /// **'إجازات وراحات'**
  String get monthOff;

  /// No description provided for @monthHours.
  ///
  /// In ar, this message translates to:
  /// **'ساعات'**
  String get monthHours;

  /// No description provided for @monthPrev.
  ///
  /// In ar, this message translates to:
  /// **'الشهر السابق'**
  String get monthPrev;

  /// No description provided for @monthNext.
  ///
  /// In ar, this message translates to:
  /// **'الشهر التالي'**
  String get monthNext;

  /// No description provided for @legPresent.
  ///
  /// In ar, this message translates to:
  /// **'حاضر'**
  String get legPresent;

  /// No description provided for @legAbsent.
  ///
  /// In ar, this message translates to:
  /// **'غائب'**
  String get legAbsent;

  /// No description provided for @legOff.
  ///
  /// In ar, this message translates to:
  /// **'إجازة أو عطلة أو راحة'**
  String get legOff;

  /// No description provided for @legMission.
  ///
  /// In ar, this message translates to:
  /// **'مأمورية'**
  String get legMission;

  /// No description provided for @legStar.
  ///
  /// In ar, this message translates to:
  /// **'حضرت في يوم راحة'**
  String get legStar;

  /// No description provided for @dayPresent.
  ///
  /// In ar, this message translates to:
  /// **'حاضر'**
  String get dayPresent;

  /// No description provided for @dayAbsent.
  ///
  /// In ar, this message translates to:
  /// **'غائب'**
  String get dayAbsent;

  /// No description provided for @dayLeave.
  ///
  /// In ar, this message translates to:
  /// **'في إجازة'**
  String get dayLeave;

  /// No description provided for @dayMission.
  ///
  /// In ar, this message translates to:
  /// **'في مأمورية'**
  String get dayMission;

  /// No description provided for @dayWeeklyOff.
  ///
  /// In ar, this message translates to:
  /// **'راحة أسبوعية'**
  String get dayWeeklyOff;

  /// No description provided for @dayHoliday.
  ///
  /// In ar, this message translates to:
  /// **'عطلة رسمية'**
  String get dayHoliday;

  /// No description provided for @dayComp.
  ///
  /// In ar, this message translates to:
  /// **'راحة مستحقة'**
  String get dayComp;

  /// No description provided for @dayPartTimeOff.
  ///
  /// In ar, this message translates to:
  /// **'راحة نصف وقت'**
  String get dayPartTimeOff;

  /// No description provided for @dayFuture.
  ///
  /// In ar, this message translates to:
  /// **'يوم قادم'**
  String get dayFuture;

  /// No description provided for @dayToday.
  ///
  /// In ar, this message translates to:
  /// **'اليوم، لم تحضر بعد'**
  String get dayToday;

  /// No description provided for @dayNoCheckout.
  ///
  /// In ar, this message translates to:
  /// **'لم يُسجّل انصراف'**
  String get dayNoCheckout;

  /// No description provided for @dayWorkedOnOff.
  ///
  /// In ar, this message translates to:
  /// **'حضرت في يوم راحة'**
  String get dayWorkedOnOff;

  /// No description provided for @dayAbsenceLogged.
  ///
  /// In ar, this message translates to:
  /// **'غياب مسجّل'**
  String get dayAbsenceLogged;

  /// No description provided for @monthUnavailableTitle.
  ///
  /// In ar, this message translates to:
  /// **'غير متاح بعد'**
  String get monthUnavailableTitle;

  /// No description provided for @mapContinue.
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get mapContinue;

  /// No description provided for @monthLeave.
  ///
  /// In ar, this message translates to:
  /// **'إجازة'**
  String get monthLeave;

  /// No description provided for @monthHoliday.
  ///
  /// In ar, this message translates to:
  /// **'عطلة'**
  String get monthHoliday;

  /// No description provided for @monthRest.
  ///
  /// In ar, this message translates to:
  /// **'راحة'**
  String get monthRest;

  /// No description provided for @legLeave.
  ///
  /// In ar, this message translates to:
  /// **'إجازة'**
  String get legLeave;

  /// No description provided for @legHoliday.
  ///
  /// In ar, this message translates to:
  /// **'عطلة رسمية'**
  String get legHoliday;

  /// No description provided for @legRest.
  ///
  /// In ar, this message translates to:
  /// **'راحة'**
  String get legRest;

  /// No description provided for @leaveRequestNew.
  ///
  /// In ar, this message translates to:
  /// **'طلب إجازة'**
  String get leaveRequestNew;

  /// No description provided for @leaveHalfDay.
  ///
  /// In ar, this message translates to:
  /// **'نصف يوم'**
  String get leaveHalfDay;

  /// No description provided for @leaveHalfFirst.
  ///
  /// In ar, this message translates to:
  /// **'النصف الأول'**
  String get leaveHalfFirst;

  /// No description provided for @leaveHalfSecond.
  ///
  /// In ar, this message translates to:
  /// **'النصف الثاني'**
  String get leaveHalfSecond;

  /// No description provided for @leaveFullDay.
  ///
  /// In ar, this message translates to:
  /// **'يوم كامل'**
  String get leaveFullDay;

  /// No description provided for @leaveReasonRequiredHint.
  ///
  /// In ar, this message translates to:
  /// **'اكتب سبب الإجازة'**
  String get leaveReasonRequiredHint;

  /// No description provided for @errReasonRequired.
  ///
  /// In ar, this message translates to:
  /// **'سبب الإجازة مطلوب'**
  String get errReasonRequired;

  /// No description provided for @leaveSumDays.
  ///
  /// In ar, this message translates to:
  /// **'أيام الإجازة'**
  String get leaveSumDays;

  /// No description provided for @leaveSumWeekend.
  ///
  /// In ar, this message translates to:
  /// **'راحة'**
  String get leaveSumWeekend;

  /// No description provided for @leaveSumHolidays.
  ///
  /// In ar, this message translates to:
  /// **'عطلات رسمية'**
  String get leaveSumHolidays;

  /// No description provided for @leaveSumDeducted.
  ///
  /// In ar, this message translates to:
  /// **'تُخصم من الرصيد'**
  String get leaveSumDeducted;

  /// No description provided for @leaveSumReturn.
  ///
  /// In ar, this message translates to:
  /// **'العودة للعمل'**
  String get leaveSumReturn;

  /// No description provided for @leaveSumBalanceAfter.
  ///
  /// In ar, this message translates to:
  /// **'المتبقي بعد الطلب'**
  String get leaveSumBalanceAfter;

  /// No description provided for @leaveTypesError.
  ///
  /// In ar, this message translates to:
  /// **'تعذر تحميل أنواع الإجازات'**
  String get leaveTypesError;

  /// No description provided for @approvalsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الاعتمادات'**
  String get approvalsTitle;

  /// No description provided for @apprTabWaiting.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار قراري'**
  String get apprTabWaiting;

  /// No description provided for @apprTabLater.
  ///
  /// In ar, this message translates to:
  /// **'لاحقًا'**
  String get apprTabLater;

  /// No description provided for @apprTabDone.
  ///
  /// In ar, this message translates to:
  /// **'تمت'**
  String get apprTabDone;

  /// No description provided for @apprEmptyWaitingTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا طلبات بانتظارك'**
  String get apprEmptyWaitingTitle;

  /// No description provided for @apprEmptyWaitingMsg.
  ///
  /// In ar, this message translates to:
  /// **'ستظهر هنا الطلبات التي جاء دورك في اعتمادها.'**
  String get apprEmptyWaitingMsg;

  /// No description provided for @apprEmptyLaterTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا شيء قادم'**
  String get apprEmptyLaterTitle;

  /// No description provided for @apprEmptyLaterMsg.
  ///
  /// In ar, this message translates to:
  /// **'الطلبات التي تنتظر قرار مرحلة قبلك تظهر هنا.'**
  String get apprEmptyLaterMsg;

  /// No description provided for @apprEmptyDoneTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا قرارات بعد'**
  String get apprEmptyDoneTitle;

  /// No description provided for @apprEmptyDoneMsg.
  ///
  /// In ar, this message translates to:
  /// **'الطلبات التي وافقت عليها أو رفضتها تظهر هنا.'**
  String get apprEmptyDoneMsg;

  /// No description provided for @apprRequester.
  ///
  /// In ar, this message translates to:
  /// **'مقدّم الطلب'**
  String get apprRequester;

  /// No description provided for @apprDetailTitle.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الطلب'**
  String get apprDetailTitle;

  /// No description provided for @apprYourStage.
  ///
  /// In ar, this message translates to:
  /// **'مرحلتك'**
  String get apprYourStage;

  /// No description provided for @apprWaitingFirst.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار {name} أولًا'**
  String apprWaitingFirst(String name);

  /// No description provided for @apprNotYet.
  ///
  /// In ar, this message translates to:
  /// **'ليس دورك بعد. يجب أن تُقرّر المرحلة السابقة أولًا.'**
  String get apprNotYet;

  /// No description provided for @apprApprove.
  ///
  /// In ar, this message translates to:
  /// **'موافقة'**
  String get apprApprove;

  /// No description provided for @apprReject.
  ///
  /// In ar, this message translates to:
  /// **'رفض'**
  String get apprReject;

  /// No description provided for @apprApproveTitle.
  ///
  /// In ar, this message translates to:
  /// **'الموافقة على الطلب'**
  String get apprApproveTitle;

  /// No description provided for @apprRejectTitle.
  ///
  /// In ar, this message translates to:
  /// **'رفض الطلب'**
  String get apprRejectTitle;

  /// No description provided for @apprNotesHint.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات (اختياري)'**
  String get apprNotesHint;

  /// No description provided for @apprRejectHint.
  ///
  /// In ar, this message translates to:
  /// **'اكتب سبب الرفض'**
  String get apprRejectHint;

  /// No description provided for @apprRejectRequired.
  ///
  /// In ar, this message translates to:
  /// **'سبب الرفض مطلوب'**
  String get apprRejectRequired;

  /// No description provided for @apprConfirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get apprConfirm;

  /// No description provided for @apprApproved.
  ///
  /// In ar, this message translates to:
  /// **'تمت الموافقة على الطلب'**
  String get apprApproved;

  /// No description provided for @apprRejected.
  ///
  /// In ar, this message translates to:
  /// **'تم رفض الطلب'**
  String get apprRejected;

  /// No description provided for @apprYourDecision.
  ///
  /// In ar, this message translates to:
  /// **'قرارك'**
  String get apprYourDecision;

  /// No description provided for @apprNotes.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات'**
  String get apprNotes;

  /// No description provided for @apprHomeTitle.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار قرارك'**
  String get apprHomeTitle;

  /// No description provided for @apprShowAll.
  ///
  /// In ar, this message translates to:
  /// **'عرض الكل ({n})'**
  String apprShowAll(String n);

  /// No description provided for @apprInfo.
  ///
  /// In ar, this message translates to:
  /// **'بيانات الطلب'**
  String get apprInfo;

  /// No description provided for @apprYouLabel.
  ///
  /// In ar, this message translates to:
  /// **'أنت'**
  String get apprYouLabel;

  /// No description provided for @apprConfirmApproveMsg.
  ///
  /// In ar, this message translates to:
  /// **'هل تريد الموافقة على طلب {name}؟'**
  String apprConfirmApproveMsg(String name);

  /// No description provided for @promoNew.
  ///
  /// In ar, this message translates to:
  /// **'جديد'**
  String get promoNew;

  /// No description provided for @promoTitle.
  ///
  /// In ar, this message translates to:
  /// **'LockSys HR. موارد بشرية أذكى.'**
  String get promoTitle;

  /// No description provided for @promoBody.
  ///
  /// In ar, this message translates to:
  /// **'حضورك وإجازاتك واعتماداتك في مكان واحد.'**
  String get promoBody;

  /// No description provided for @promoButton.
  ///
  /// In ar, this message translates to:
  /// **'اكتشف المزيد'**
  String get promoButton;
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
