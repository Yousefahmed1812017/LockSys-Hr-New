# المكونات

كلها في `lib/core/widgets/` وتُستورد من `widgets.dart`. قبل ما تنشئ ويدجت جديد، تأكد إن مفيش واحد هنا بيعمله.

## الأزرار — `AppButton`
```dart
AppButton(label: 'إرسال الطلب', icon: AppIcons.forward, size: AppButtonSize.lg, onPressed: submit)
AppButton(label: 'إلغاء', variant: AppButtonVariant.ghost, onPressed: cancel)
AppButton(label: 'حفظ', loading: isSaving, onPressed: save)
```
- Variants: `primary` (أزرق) · `navy` · `ghost` (حد رفيع) · `danger`.
- Sizes: `sm` 40 · `md` 48 (افتراضي) · `lg` 56. عرض كامل افتراضيًا، `expanded: false` للصف.
- `icon` بعد النص (بيشاور "لقدّام" حسب الاتجاه)، `leadingIcon` قبله.
- `onPressed: null` = معطّل (شفافية 40%). `loading: true` = دائرة صغيرة ويتجمد الضغط.
- **زر رئيسي واحد في الشاشة**، آخر الأزرار. زوج (إلغاء/تأكيد): Ghost ثم Primary.
- مرتبط: `AppIconButton` (44، أيقونة فقط) · `AppTextLink` (رابط نصي أزرق).

## الكروت — `AppCard` / `AppIconTile` / `AppAvatar`
```dart
AppCard(onTap: open, child: ...)            // أبيض، حد رفيع، علامة L في الركن
AppCard(navy: true, child: ...)             // كارت البطل: واحد فقط في الشاشة
AppIconTile(AppIcons.calendar)              // مربع 40
AppIconTile(AppIcons.check, tone: AppTone.success, solid: true)
AppAvatar('أم')                             // مربع بحواف، أحرف الاسم
```
الكارت العادي بدون ظل. `elevated: true` فقط للعناصر العائمة في الرسومات.

## الشارات — `AppBadge`
```dart
AppBadge('معتمد', tone: AppTone.success)
AppBadge('تم التحويل', tone: AppTone.success, solid: true)   // على الكحلي
```
Tones: `info` `success` `warning` `danger` `muted`. الفاتحة للقوائم، الصلبة للتمييز.
خريطة الحالات: حاضر/معتمد/تم = success · معلّق/تأخير/إجازة = warning · غائب/مرفوض/منتهي = danger · مسودة/غير نشط = muted · جديد/قيد المراجعة = info.

## التنبيه داخل الصفحة — `AppAlert`
```dart
AppAlert(title: 'تنبيه', message: 'عقدك ينتهي خلال 30 يومًا.', tone: AppTone.warning)
```
كارت أبيض + مربع أيقونة ملوّن صلب + خط سفلي بلون الحالة. للرسائل المؤقتة استخدم `AppSnackbar`.

## الحقول — `AppTextField`
```dart
AppTextField(label: 'رقم الهوية', required: true, mono: true, keyboardType: TextInputType.number,
             prefixIcon: AppIcons.idCard, helper: '10 أرقام', errorText: errorOrNull)
```
- العنوان **فوق** الحقل دائمًا (لا floating label). النجمة الحمراء للإجباري.
- الخطأ تحت الحقل باللون الأحمر ويحل محل الـ helper.
- `mono: true` للأرقام والأكواد (LTR). `suffix:` لأي عنصر في النهاية (مثل زر إظهار كلمة المرور). `onSubmitted` لزر Done في لوحة المفاتيح. `textCapitalization` للأكواد (`characters`) مع `inputFormatters`. للنص الطويل `maxLines: 4`.
- الاختيار من قائمة: افتح `showAppBottomSheet` بدل Dropdown.
- Checkbox / Switch: من الثيم (`Checkbox`, `Switch`) بدون تخصيص.

## القوائم — `AppListGroup` / `AppListTile` / `AppGroupTitle`
```dart
AppGroupTitle('الحساب'),
AppListGroup(children: [
  AppListTile(leading: AppIconTile(AppIcons.idCard), title: 'البيانات الشخصية', subtitle: '...', onTap: ...),
  AppListTile(leading: AppAvatar('أم'), title: 'أحمد محمد', trailing: AppBadge('حاضر', tone: AppTone.success)),
])
```
ارتفاع أدنى 64. الـ chevron يظهر تلقائيًا لو فيه `onTap` ومفيش `trailing`. الـ trailing: شارة، قيمة نصية، أو Switch.

## التنقل — `AppBottomNav` / `AppNavItem`
3–5 عناصر، ارتفاع 64. النشط: أزرق، يرتفع 2px، مؤشر مائل 28×2. `badge:` لعدد غير المقروء.

## الفلاتر — `AppChipRow` / `AppSegmented`
- `AppChipRow`: رقاقات أفقية قابلة للتمرير، المحددة كحلية.
- `AppSegmented`: 2–3 خيارات لتبديل العرض (شهري/أسبوعي/يومي).

## النوافذ — `app_overlays.dart`
```dart
showAppBottomSheet(context, title: 'تصفية', builder: (ctx) => ...)     // فلاتر واختيارات
final ok = await showAppConfirmDialog(context, title: 'إلغاء الطلب؟', message: '...', destructive: true)
AppSnackbar.show(context, 'تم الحفظ')                                   // نجاح
AppSnackbar.show(context, 'فشل الحفظ', tone: AppTone.danger, actionLabel: 'إعادة', onAction: retry)
```
Dialog للتأكيد الخطير فقط (حذف، إلغاء، خروج).

## هيكل الشاشة — `AppScreen` / `AppTopBar` / `AppPageHeader` / `AppBackButton` / `AppReveal`
```dart
AppScreen(
  title: 'طلب إجازة', showBack: true,
  kicker: 'الإجازات', heading: 'طلب إجازة جديد', subtitle: 'يصل طلبك للمدير المباشر.',
  children: [ ... ],            // مسافة 16 بينها، وظهور متتابع تلقائي
  onRefresh: reload,            // اختياري: سحب للتحديث
  bottomBar: AppBottomNav(...), // للشاشات الرئيسية بالتابات
)
```
لجسم مخصص (قائمة طويلة، تابات) استخدم `body:` بدل `children:`، وضع `AppPageHeader` بنفسك في أعلاه.

## التحميل والحالات
```dart
AppLoadable(loading: state.loading, skeleton: const AppSkeletonList(count: 4), child: content)
```
- `AppSkeletonList` / `AppSkeletonCard` / `AppSkeletonTile` / `AppSkeletonBox` (داخل `AppShimmer`).
- الـ Skeleton لازم يطابق شكل المحتوى الحقيقي (نفس الارتفاعات والترتيب). ابنِ واحدًا مخصصًا من `AppSkeletonBox` لو الشاشة مختلفة.
- `AppEmptyState.empty(title:, message:, actionLabel:, onAction:)` لـ "لا توجد بيانات".
- `AppEmptyState.offline(onAction: retry)` لانقطاع الاتصال أو فشل الطلب (النص والزر بلغة الواجهة تلقائيًا).

## اللوجو واللغة
- `AppBrandHero(subtitle:)`: هيرو أبيض لشاشات ما قبل الدخول (كود الشركة، الدخول): Pattern L + زر اللغة + اللوجو + "LockSys HR" + سطر وصف.
- `AppLogoMark(height:)`: اللوجو الرسمي (PNG). للتبديل بين اللغتين: `AppLanguageToggle()` (زر صغير بأيقونة globe واسم اللغة الأخرى)، و`LocaleScope.of(context).setLocale(...)`.
- كل النصوص: `context.l10n.xxx` (راجع localization.md).

## عناصر الهوية — `l_pattern.dart`
`LPattern` (نسيج الخطوط) · `LTick` (علامة L) · `AppLogo(progress:)` (اللوجو مع رسم تدريجي).

## `Pressable`
غلاف تفاعل عام (Scale .98 خلال 150ms). لأي عنصر مخصص قابل للضغط: `Pressable(onTap: ..., child: ...)`. لا تستخدم `InkWell` بتموّج Material على الأزرار والكروت.
