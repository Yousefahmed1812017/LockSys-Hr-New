# التركيب في مشروع جديد

المشروع الحالي (`lock_sys_hr`) **مركَّب فيه كل شيء بالفعل**. هذا الملف لتركيب النظام في مشروع Flutter جديد أو لإعادة التركيب. الكود في `assets/flutter/` نسخة مطابقة لـ `lib/` (مجرَّب: `flutter analyze` نضيف + اختبارات ناجحة + بناء APK).

## 1) Dependencies
```bash
flutter pub add flutter_svg google_fonts shared_preferences intl "flutter_localizations:{sdk: flutter}"
flutter pub add --dev flutter_launcher_icons
```
> على ويندوز: فعّل **Developer Mode** (`start ms-settings:developers`) وإلا فشل `pub get` عند إنشاء الروابط الرمزية للـ plugins.

## 2) `pubspec.yaml`
```yaml
flutter:
  generate: true            # لتوليد الترجمة
  uses-material-design: true
  assets:
    - assets/images/

flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon/app_icon.png"
  remove_alpha_ios: true
  adaptive_icon_background: "#FFFFFF"
  adaptive_icon_foreground: "assets/icon/app_icon_foreground.png"
  web: { generate: true, image_path: "assets/icon/app_icon.png", background_color: "#FFFFFF", theme_color: "#126BFF" }
  windows: { generate: true, image_path: "assets/icon/app_icon.png", icon_size: 256 }
  macos: { generate: true, image_path: "assets/icon/app_icon.png" }
```
وأنشئ `l10n.yaml` في الجذر (موجود في `assets/flutter/l10n.yaml`):
```yaml
arb-dir: lib/l10n
template-arb-file: app_ar.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
nullable-getter: false
```

## 3) انسخ الملفات
من `assets/flutter/` إلى جذر المشروع:
- `lib/` كلها (`core/`, `features/`, `l10n/`, `app.dart`, `main.dart`)
- `assets/images/` (اللوجو) و`assets/icon/` (الأيقونة)
- `l10n.yaml` و`test/widget_test.dart` (غيّر `package:lock_sys_hr/` لاسم مشروعك لو مختلف)

ثم:
```bash
flutter pub get
flutter gen-l10n
dart run flutter_launcher_icons
flutter analyze && flutter test
```

## 4) اسم التطبيق: LockSys HR
| المنصة | الملف |
|---|---|
| Android | `android/app/src/main/AndroidManifest.xml` → `android:label="LockSys HR"` |
| iOS | `ios/Runner/Info.plist` → `CFBundleDisplayName` و`CFBundleName` |
| Web | `web/index.html` (title + apple-mobile-web-app-title) و`web/manifest.json` (name/short_name) |
| Windows | `windows/runner/main.cpp` (عنوان النافذة) و`Runner.rc` (ProductName/FileDescription) |
| macOS | `macos/Runner/Configs/AppInfo.xcconfig` → `PRODUCT_NAME` |
| Linux | `linux/runner/my_application.cc` |

## 5) أيقونة التطبيق
اللوجو الرسمي (نسخة 640px من موقع locksys.co) مركّب على مربع أبيض 1024×1024. لتغيير الأيقونة استبدل `assets/icon/app_icon.png` (خلفية بيضاء، اللوجو ~62% من الارتفاع) و`app_icon_foreground.png` (شفاف، اللوجو ~55% لتبقى داخل المنطقة الآمنة)، ثم `dart run flutter_launcher_icons`.

## 6) الخط للأوفلاين (موصى به لتطبيق موارد بشرية)
`google_fonts` بيحمّل IBM Plex Sans Arabic من الإنترنت أول مرة. لتضمينه:
1. نزّل الخط (أوزان 400/500/600/700) وضع ملفات `.ttf` في `assets/google_fonts/` بأسمائها الأصلية.
2. أضف `- assets/google_fonts/` تحت `assets:` في `pubspec.yaml`.
3. اختياريًا `GoogleFonts.config.allowRuntimeFetching = false;` في `main()`.

## 7) الاختبارات
- ضع `GoogleFonts.config.allowRuntimeFetching = false;` في `setUp` (يتفادى تحميل الخط، ويظهر خط الاختبار الأعرض).
- اضبط حجم الشاشة: `t.view.physicalSize = const Size(390, 844); t.view.devicePixelRatio = 1;`.
- بعد `tap` استخدم `pump(100ms)` ثم `pump(600ms)` (انتقالات الصفحات تحتاج إطارين).

## ملاحظات
- الإصدارات المجرَّبة: Flutter 3.41 / Dart 3.11، `flutter_svg` 2.3، `google_fonts` 8.2، `shared_preferences` 2.5، `intl` 0.20.
- عند استيراد `intl` في ملف يستخدم `TextDirection` اكتب `import 'package:intl/intl.dart' show DateFormat;` لتجنب التعارض.
