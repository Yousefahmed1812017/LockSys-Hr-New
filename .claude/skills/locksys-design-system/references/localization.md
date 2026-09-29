# اللغة: عربي + إنجليزي

التطبيق بلغتين. **العربية هي الافتراضية** (RTL)، والإنجليزية (LTR). كل الواجهة تتبدل فورًا، والاختيار محفوظ على الجهاز.

## كيف يعمل
- `LocaleController` (في `core/l10n/locale_controller.dart`) يحمل اللغة الحالية ويحفظها (`shared_preferences`، المفتاح `app_locale`).
- `LocaleScope` فوق `MaterialApp` يمرّر الـ controller للشجرة. `MaterialApp.locale` بيتحدث تلقائيًا فيتبدل الاتجاه (RTL ↔ LTR).
- النصوص من ملفات ARB: `lib/l10n/app_ar.arb` (القالب) و`app_en.arb`. الكود المولَّد: `AppLocalizations`.
- في أي ويدجت: `context.l10n.next` (من `core/l10n/locale_controller.dart`)، و`context.isArabic` للتفريعات.
- التبديل: `AppLanguageToggle` (زر صغير أعلى شاشات الترحيب والدخول)، أو `LocaleScope.of(context).setLocale(Locale('en'))`. في حسابي: صف "اللغة" يفتح Bottom Sheet.

## إضافة نص جديد (خطوات ثابتة)
1. أضف المفتاح في **الملفين** بنفس الاسم:
   ```json
   // app_ar.arb
   "leaveBalance": "رصيد الإجازات",
   // app_en.arb
   "leaveBalance": "Leave balance",
   ```
2. مع متغير:
   ```json
   "greetingName": "أهلاً {name}",
   "@greetingName": { "placeholders": { "name": { "type": "String" } } }
   ```
3. شغّل `flutter gen-l10n`.
4. استخدمه: `Text(context.l10n.leaveBalance)` / `context.l10n.greetingName(user.name)`.

**ممنوع** نص مكتوب مباشرة في الويدجت (`Text('...')`). الاستثناءات: الأسماء اللاتينية للعلامة ("LockSys HR")، الأرقام والأكواد، وبيانات API.

## قواعد الصياغة
- عربي فصيح مبسّط، قصير ومباشر. أفعال أمر مهذبة ("سجّل حضورك"). لا لهجة عامية في الواجهة.
- الإنجليزية Sentence case ("Leave request" وليس "Leave Request")، بدون نقطة في نهاية العناوين والأزرار.
- الأزرار فعل واضح: "إرسال الطلب" / "Submit request". لا "موافق/OK" العامة.
- رسائل الخطأ تقول المطلوب فعله: "أدخل كلمة المرور" / "Enter your password".
- المصطلحات: إجازة = Leave · حضور = Attendance · كشف الراتب = Payslip · الموارد البشرية = HR · موافقة = Approval.
- اسم التطبيق: **LockSys HR** في اللغتين.

## RTL/LTR في الكود
- استخدم دائمًا الصيغ الاتجاهية: `EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional`, `BorderRadiusDirectional`, `TextAlign.start/end`.
- ممنوع `left/right` أو `Alignment.centerLeft` لمحتوى (مسموح للتوسيط والزخرفة المتماثلة).
- الأسهم والـ chevron: استخدم `AppIcons.forward/back/chevron` (بتنقلب تلقائيًا).
- الأرقام والأكواد: `Text(..., textDirection: TextDirection.ltr, style: AppText.mono)` أو `AppTextField(mono: true)`.
- **لا `letterSpacing`** على نص عربي (يفكك اتصال الحروف). استخدمه فقط لو `!context.isArabic`.
- التواريخ: `DateFormat.yMMMMEEEEd(locale)` مع `initializeDateFormatting()` (موجود في `main.dart`). اعمل `import 'package:intl/intl.dart' show DateFormat;` لتجنب تعارض `TextDirection`.
- العملة: "ر.س" / "SAR" من الترجمة.
- تحقق من الشاشة باللغتين، وعلى عرض 320 وبخط مكبّر (لا overflow: `Expanded` + `ellipsis`).

## إضافة لغة ثالثة (لو لزم)
أضف `app_xx.arb` (نسخة كل المفاتيح)، و`Locale('xx')` في `LocaleController._read`/`toggle` (يتحول لقائمة اختيار بدل toggle)، وأضف الخيار في Bottom Sheet اللغة، وشغّل `flutter gen-l10n`.

## الأرقام في التواريخ
التواريخ من `DateFormat` بالعربية بترجع بأرقام هندية (٠-٩). التطبيق يستخدم أرقامًا إنجليزية (0-9) في اللغتين، فمرّر أي نص تاريخ/رقم منسّق بالعربية على `toWesternDigits(...)` (موجودة في `core/l10n/locale_controller.dart`).
