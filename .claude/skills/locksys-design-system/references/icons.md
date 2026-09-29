# الأيقونات

مجموعة واحدة خاصة بـ LockSys. **ممنوع** استخدام `Icons.*` أو Font Awesome أو أي حزمة أخرى. كل أيقونة تُرسم بـ `AppIcon`.

## الأسلوب (Duotone)
- شبكة **24×24**، مع مسافة داخلية 3px.
- خط **1.75px**، أطراف ومفاصل مستديرة.
- **خط كحلي** (لون النص) + **تعبئة زرقاء ناعمة** داخل الشكل (Accent).
- أيقونات الأفعال (`forward`, `back`, `chevron`, `plus`, `check`, `logout`, `fingerprint`) **خط فقط** بدون تعبئة.
- الأيقونات الاتجاهية (`forward`, `back`, `chevron`) مرسومة لـ RTL وبتتقلب تلقائيًا في LTR.

## الاستخدام
```dart
AppIcon(AppIcons.home)                       // 22px، كحلي + تعبئة زرقاء 16%
AppIcon(AppIcons.bell, size: 24, color: AppColors.blue)
```

### ضبط السياق (اللون + التعبئة)
| السياق | الإعداد |
|---|---|
| على أبيض (افتراضي) | بدون تغيير |
| داخل `AppIconTile` | تلقائي (أزرق، تعبئة 20%) |
| على Navy | `color: white, accentColor: AppColors.blueBright, accentOpacity: .4` |
| على لون حالة صلب | `color: white, accentColor: white, accentOpacity: .3` (`AppIconTile(solid: true)`) |
| Tab نشط | `color: blue, accentOpacity: .3` (تلقائي في `AppBottomNav`) |
| داخل زر | تلقائي (`AppButton`) |

## الأحجام
| الحجم | الاستخدام |
|---|---|
| 18 | داخل الأزرار، chevron في القوائم |
| 20 | داخل الحقول، مربع الأيقونة الصغير |
| 22 | الافتراضي (AppBar، إجراءات) |
| 23–24 | Tab bar |
| 36–56 | الرسومات التوضيحية (Empty state 36، Onboarding hub 56) |

## المجموعة الحالية (33)
`home` `users` `user` `calendar` `clock` `money` `file` `idCard` `settings` `bell` `search` `filter` `info` `warning` `location` `fingerprint` `lock` `shield` `globe` `help` `edit` `download` `inbox` `wifi` `building` `eye` `eyeOff` `forward` `back` `chevron` `plus` `check` `logout`

اقتراحات الاستخدام: `home` الرئيسية · `users` الموظفون · `user` الحساب · `calendar` الإجازات · `clock` الحضور · `money` الرواتب · `file` المستندات/الخطابات · `idCard` البيانات الشخصية · `shield` الأمان/PDPL · `location` الفرع/الموقع · `inbox` حالة فارغة · `wifi` انقطاع الاتصال.

## إضافة أيقونة جديدة
1. ارسمها على شبكة 24×24 بنفس الخط (1.75، round). حدّد: **الـ outline** (عناصر SVG) و**الـ accent** (path واحد يملأ الشكل من الداخل) لو الأيقونة كائن، أو من غير accent لو فعل.
2. أضفها في `lib/core/icons/app_icons.dart`:
   ```dart
   static const payslip = AppIconData(
     'payslip',
     r'<path d="..."/><path d="..."/>',   // outline
     accent: r'M... z',                    // اختياري
   );
   ```
   وأضفها لقائمة `all`.
3. أضفها في `assets/design-system/index.html` (الـ `<symbol>` في الـ sprite + قائمة `IC` في الـ JS) عشان المرجع البصري يفضل مطابق.
4. حدّث قائمة "المجموعة الحالية" في هذا الملف.
5. لو الأيقونة سهم أو اتجاهية، مرّر `directional: true`.

**لا تضيف أيقونة لو فيه واحدة قريبة تنفع.** التنوع الزايد بيكسر التوحيد.

## مربع الأيقونة (`AppIconTile`)
40×40، حواف 8، خلفية `blue50` وحد `line`، الأيقونة زرقاء بحجم 20. بألوان الحالة: `tone:` (فاتح) أو `solid: true` (صلب، الأيقونة بيضاء). ده الشكل الموحد للأيقونة في القوائم والتنبيهات.

## زر الرجوع
`AppBackButton`: مربع 40، حد `line`، حواف 8، ظل `sh1`، أيقونة `back`. أول عنصر في `AppTopBar` بالشاشات المفتوحة بـ push.

## اللوجو (`AppLogoMark`)
- هو الـ PNG الرسمي (`assets/images/locksys-mark-{160,320,640}.png`، شفاف، نسبة 3:4). الويدجت يختار الدقة المناسبة تلقائيًا.
- الأحجام: Top bar 30–32 · Splash 120 · Login 104.
- **ممنوع** تعديل ألوانه أو رسمه بالكود أو وضعه على خلفية كحلية (الجزء الكحلي يختفي). للزخرفة استخدم `AppLogo` (خطوط خارجية) بشفافية 18%.
- اسم العلامة يُكتب دائمًا "LockSys HR" بحروف لاتينية LTR.

## أيقونة التطبيق واسمه
- الأيقونة: اللوجو على **خلفية بيضاء** (`assets/icon/app_icon.png` 1024) + أيقونة Android التكيّفية (`app_icon_foreground.png` بخلفية #FFFFFF). تتولّد لكل المنصات بأمر واحد: `dart run flutter_launcher_icons`.
- الاسم تحت الأيقونة: **LockSys HR** (Android label، iOS CFBundleDisplayName، الويب، Windows، macOS، Linux).
