---
name: locksys-design-system
description: نظام تصميم تطبيق LockSys HR (Flutter موبايل، ثنائي اللغة عربي RTL + إنجليزي LTR). استخدمه قبل إنشاء أو تعديل أي شاشة أو ويدجت أو ثيم أو أيقونة أو لوجو أو زر أو حقل أو قائمة أو نص أو ترجمة أو حركة أو شاشة Splash/Onboarding/Login في التطبيق. Use before creating or editing ANY screen, widget, theme, icon, logo, string/translation, form, list, animation, or loading/empty/error state in the LockSys HR Flutter app, so every screen shares one identity (white background, LockSys navy/blue, real logo mark, 8px squares, duotone icons, skeleton loading, Arabic + English).
---

# LockSys HR Design System

هوية واحدة لكل شاشة في تطبيق LockSys HR. الخلفية بيضاء، وألوان اللوجو (Navy `#071F3D` وBlue `#126BFF`)، ولوجو LockSys الرسمي، وأزرار وكروت مربعة بحواف 8px، وأيقونات Duotone موحدة، وSkeleton بدل الشاشة الفاضية، والتطبيق **بلغتين: عربي (RTL) وإنجليزي (LTR)**.

- المصدر البصري الحي: [assets/design-system/index.html](assets/design-system/index.html) (افتحه في المتصفح).
- الكود الجاهز: `assets/flutter/` هو **نسخة مطابقة** لما هو مركَّب في `lib/` (مجرَّب: `flutter analyze` نضيف + اختبارات تشغيل ناجحة + بناء APK).
- **مصدر الحقيقة للكود = `lib/` في المشروع.** الـ Skill فيها نسخة للمرجع والتركيب في مشروع جديد.

## متى تستخدم الـ Skill
أي مرة تلمس UI في التطبيق: شاشة جديدة، تعديل شاشة، ويدجت مشترك، ثيم، أيقونة، لوجو، نصوص/ترجمة، حالة تحميل/فارغة/خطأ، نافذة، أو حركة.

## الخطوات الإلزامية لأي شاشة (بالترتيب)

1. **اقرأ المرجع المناسب** من `references/` (الفهرس تحت). للشاشات: `screens.md`. للمكونات: `components.md`. للنصوص: `localization.md`.
2. **ابحث في الكود أولًا** قبل ما تكتب أي ويدجت:
   - `lib/core/widgets/` هل فيه مكوّن بيعمل المطلوب؟ استخدمه.
   - `lib/features/**` هل فيه شاشة شبه المطلوبة؟ اتبع نفس بنيتها.
   - لو لقيت مكوّن قريب، وسّعه بدل ما تنسخه أو تعمل بديل.
3. **اختر نمط الشاشة** من `screens.md` (قائمة، نموذج، تفاصيل، حساب، رئيسية...) وابنِ عليه.
4. **ابنِ بالـ tokens فقط**: ألوان `AppColors`، مسافات `AppSpacing`، حواف `AppRadius`، حركة `AppMotion`، نصوص `AppText`، أيقونات `AppIcons`، **وكل نص واجهة من `context.l10n`**.
5. **غطّي الحالات الأربع**: تحميل (Skeleton) ثم محتوى ثم فارغ ثم خطأ اتصال.
6. **اختبر باللغتين**: العربية (RTL) والإنجليزية (LTR)، وتأكد من عدم وجود overflow.
7. **راجع الـ Checklist** في `references/checklist.md` قبل ما تعتبر الشاشة خلصت.
8. **لو احتجت مكوّن/أيقونة/نص جديد فعلًا**: ضيفه في `lib/`، وحدّث المرجع (`components.md`/`icons.md`) و`assets/design-system/index.html`، ثم زامن `assets/flutter/` (انسخ من `lib/`).

## القواعد الصارمة (غير قابلة للتفاوض)

**الهوية**
- الخلفية **بيضاء**. الكحلي (Navy) لعنصر مميز واحد فقط في الشاشة (`AppCard(navy: true)`)، وللنصوص.
- **اللوجو**: `AppLogoMark` فقط (الـ PNG الرسمي). ممنوع إعادة رسمه أو تلوينه أو وضعه على خلفية داكنة (الجزء الكحلي فيه يختفي). لذلك الـ Splash وشاشة الدخول على **خلفية بيضاء**. الـ `AppLogo` المرسوم بالكود للزخرفة (خطوط خارجية) فقط.
- اسم التطبيق يُكتب دائمًا **LockSys HR** (بحروف لاتينية، LTR) في أي لغة.
- الأزرار والحقول والكروت **Radius 8**. Dialog 12. Bottom Sheet 16. لا قطع مائل ولا Pill.
- **زر رئيسي واحد** في الشاشة، بعرض كامل، آخر الأزرار.
- **الأيقونات من `AppIcons` فقط** عبر `AppIcon`. ممنوع `Icons.*` أو حزم أيقونات تانية (الاستثناء الوحيد: `Icons.close` الصغيرة داخل `AppAlert`).
- **Pattern الـ L** (`LPattern`) في Splash/Onboarding/Login/كارت Navy فقط، بشفافية 9–16%.

**البنية**
- كل شاشة تبدأ بـ **Top bar ثم Page Header**: زر رجوع مربع (`AppBackButton`)، ثم Kicker (علامة L + القسم)، ثم H1، ثم وصف، ثم الخط الأزرق القصير. استخدم `AppScreen`.
- **الشاشة تفتح بـ Skeleton** على شكل محتواها (`AppLoadable` + `AppSkeleton*`)، مش Spinner. الـ Spinner داخل الزر فقط (`loading: true`).
- **Dialog للتأكيد الخطير فقط**. الفلاتر والاختيارات في Bottom Sheet. الرسائل السريعة في Snackbar.
- **مساحة اللمس ≥ 48px** (44 للأيقونات). حجم الخط ≥ 12.

**اللغة (عربي + إنجليزي)**
- **ممنوع أي نص واجهة مكتوب مباشرة في الكود.** كل نص من `context.l10n.xxx`، والمفتاح يُضاف في `lib/l10n/app_ar.arb` **و** `app_en.arb` معًا ثم `flutter gen-l10n`.
- **RTL/LTR تلقائي**: استخدم `EdgeInsetsDirectional` و`AlignmentDirectional` و`PositionedDirectional`. ممنوع `left/right` الصريحة إلا لتوسيط. الأسهم بتتقلب تلقائيًا داخل `AppIcon`.
- **الأرقام والأكواد والتواريخ** (EMP-0012 · 08:30) بـ `AppText.mono` واتجاه LTR. أرقام إنجليزية (0-9) في اللغتين.
- ممنوع `letterSpacing` على نص عربي (بيفكك الحروف). الأسماء الإنجليزية فقط.
- زر تبديل اللغة `AppLanguageToggle` في شاشات الترحيب والدخول، وصف "اللغة" في حسابي. الاختيار محفوظ (`LocaleController`). الافتراضي عربي.

**الحركة**
- من القيم المعتمدة فقط: 150 (ضغط) · 300 (UI) · 320 (صفحة/Sheet) · 500 (ظهور) · 900 (تقدم) بمنحنى `AppMotion.easeOut`.

## ملخص سريع للـ Tokens

| العنصر | القيمة |
|---|---|
| Navy / Blue / Blue bright | `#071F3D` / `#126BFF` / `#168BFF` |
| Blue 50 / Blue light | `#F5FAFF` / `#EAF4FF` |
| Muted / Line / Line strong | `#536477` / `#DCE7F3` / `#BFD3EA` |
| Success / Warning / Danger | `#1F7A4D` / `#B26A00` / `#C62828` |
| الخط | IBM Plex Sans Arabic (عربي + لاتيني) — 24/20/17/15/13/12 |
| المسافات | 4 · 8 · 12 · 16 · 24 · 32 · 48 (gutter 16) |
| Radius | 8 (زر/حقل/كارت) · 12 (Dialog) · 16 (Sheet) |
| الارتفاعات | Touch 48 · AppBar 56 · TabBar 64 · زر 40/48/56 |
| الحركة | 150 / 300 / 320 / 500 / 900 ms · `Cubic(.22,1,.36,1)` |

## فهرس المراجع (اقرأ حسب الحاجة)

| الملف | متى |
|---|---|
| [references/tokens.md](references/tokens.md) | ألوان، خطوط، مسافات، ظلال، حركة بالتفصيل |
| [references/components.md](references/components.md) | مواصفات كل ويدجت وطريقة استخدامه |
| [references/icons.md](references/icons.md) | مجموعة الأيقونات، اللوجو، أيقونة التطبيق |
| [references/screens.md](references/screens.md) | أنماط الشاشات: Splash، Onboarding، Login، رئيسية، قائمة، نموذج، تفاصيل، حساب |
| [references/localization.md](references/localization.md) | عربي/إنجليزي: إضافة نص، RTL، تبديل اللغة، قواعد الصياغة |
| [references/checklist.md](references/checklist.md) | قائمة المراجعة قبل تسليم أي شاشة |
| [references/setup.md](references/setup.md) | تركيب الكود في مشروع جديد، أيقونة التطبيق، اسم التطبيق |

## بنية الكود (`lib/`)

```
lib/
├─ main.dart · app.dart          تهيئة + MaterialApp + تدفق Splash → Onboarding → كود الشركة → Login → Home
├─ l10n/                         app_ar.arb · app_en.arb (+ ملفات مولَّدة)
├─ core/
│  ├─ theme/     app_colors · app_tokens · app_text · app_theme
│  ├─ icons/     app_icons (33 أيقونة)
│  ├─ l10n/      locale_controller (LocaleController · LocaleScope · context.l10n)
│  └─ widgets/   widgets.dart (استيراد واحد لكل شيء)
│                app_button · app_card · app_badge · app_alert · app_text_field
│                app_list · app_overlays · app_screen · app_bottom_nav
│                app_chips · app_skeleton · app_empty_state · app_icon
│                app_logo_mark · app_language_toggle · app_brand_hero
│                l_pattern (LPattern · LTick · AppLogo) · pressable
└─ features/
   ├─ welcome/  splash_page · onboarding_page
   ├─ company/  company · company_registry · company_store · company_code_page
   ├─ auth/     login_page
   └─ home/     home_page (تابات + حسابي)
assets/images/  locksys-mark-{160,320,640}.png   ·   assets/icon/  app_icon(.png/_foreground.png)
```

## ملاحظات
- الاستيراد الموصى به في الشاشات: `import 'package:lock_sys_hr/core/widgets/widgets.dart';` (فيه الألوان والـ tokens والأيقونات والويدجتس وLocaleController). النصوص: `import 'package:lock_sys_hr/core/l10n/locale_controller.dart';` ثم `context.l10n`.
- لو التصميم في `design-system.html` اتغيّر، حدّث الكود والمراجع معًا، والعكس.
- بيانات العرض (أسماء، أرقام، رصيد) وهمية.
