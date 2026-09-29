# Checklist قبل تسليم أي شاشة

اعتبر الشاشة غير جاهزة لو فيه بند غير مُحقَّق. مرّ عليها بالترتيب.

## قبل الكتابة
- [ ] بحثت في `lib/core/widgets/` و`lib/features/` عن مكوّن/شاشة قريبة واستخدمتها.
- [ ] حددت نمط الشاشة من `screens.md`.

## الهوية
- [ ] الخلفية بيضاء، وكارت Navy واحد كحد أقصى.
- [ ] كل الألوان من `AppColors` / `AppTone`. لا `Color(0x...)` ولا `Colors.blue` مكتوبة يدويًا (الاستثناء: `Colors.white` و`Colors.transparent`).
- [ ] كل المسافات من `AppSpacing`، والحواف من `AppRadius` (8/12/16)، والحركة من `AppMotion`.
- [ ] النصوص من `AppText.*`، أقل حجم 12.
- [ ] الأيقونات من `AppIcons` عبر `AppIcon`. لا `Icons.*`.

## البنية
- [ ] الشاشة مبنية بـ `AppScreen` (أو `AppTopBar` + `AppPageHeader`) بالترتيب: رجوع ← Kicker ← H1 ← وصف ← الخط الأزرق.
- [ ] زر رئيسي واحد فقط، عريض، آخر الأزرار.
- [ ] كل عنصر قابل للضغط ≥ 48px (44 للأيقونات) وله `semanticLabel` لو أيقونة فقط.
- [ ] Dialog للخطير فقط، والفلاتر/الاختيارات في Bottom Sheet.

## الحالات
- [ ] **Skeleton** أثناء التحميل بشكل مطابق للمحتوى (`AppLoadable`).
- [ ] **حالة فارغة** (`AppEmptyState.empty`) بنص مفيد وإجراء.
- [ ] **حالة خطأ/انقطاع** (`AppEmptyState.offline` أو `AppSnackbar` danger) مع "إعادة المحاولة".
- [ ] زر الإرسال يعرض `loading` ويمنع الضغط المتكرر.
- [ ] رسائل تحقق تحت الحقول.

## RTL واللغة (عربي + إنجليزي)
- [ ] **لا نص مكتوب مباشرة في الكود**: كل النصوص من `context.l10n` وأضفت المفتاح في `app_ar.arb` و`app_en.arb` وشغّلت `flutter gen-l10n`.
- [ ] جربت الشاشة **بالعربية (RTL) والإنجليزية (LTR)** ولا overflow في أي منهما.
- [ ] لا `letterSpacing` على نص عربي.
- [ ] اللوجو من `AppLogoMark` على خلفية بيضاء فقط.
- [ ] استخدمت `EdgeInsetsDirectional` / `AlignmentDirectional` / `PositionedDirectional` بدل left/right.
- [ ] جربت الشاشة بـ `Locale('ar')` (RTL) والأسهم في اتجاهها الصحيح.
- [ ] الأرقام والأكواد والتواريخ `AppText.mono`.

## الجودة
- [ ] لا overflow على عرض 320px ومع تكبير الخط 1.3× (استخدم `Expanded`/`Flexible`/`FittedBox` للنصوص داخل الأبعاد الثابتة).
- [ ] `flutter analyze` بدون تحذيرات.
- [ ] لو أضفت مكوّنًا/أيقونة جديدة: حدّثت `components.md` / `icons.md` و`assets/design-system/index.html`.
