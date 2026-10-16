# Awake Glass

بطاقة زجاجية خفيفة للماك، تخلي شغلك يكمل بدون سكون أثناء المهام الطويلة. اختار مؤقت، أو خلي الجلسة شغّالة لحد ما توقفها بنفسك. الواجهة تبدأ بالعربية وتقدر تبدّلها للإنجليزية من زر 🌐.

## شنو تسوي؟

- تبقي الماك شغّال أثناء التنزيلات، المعالجة، ومهام أدوات الذكاء الاصطناعي.
- تبقي الشاشة مضاءة، مع خيار لتأجيل القفل التلقائي بسبب الخمول.
- مؤقتات جاهزة: **15، 30، 60، 120 دقيقة**؛ وقت مخصص من **1 إلى 1440 دقيقة**؛ أو **∞ لحد ما توقفها**.
- عدّاد واضح، زر إيقاف، وخيار لتثبيت البطاقة فوق النوافذ.
- عند انتهاء المؤقت، الإيقاف، أو إنهاء الأداة، ترجع قواعد السكون الطبيعية تلقائياً.
- تعمل من شريط المينو، بدون أيقونة بالـDock، مكتبات إضافية، أو اتصال بالشبكة.

## التنزيل والاستخدام

تحتاج **macOS 26 أو أحدث**. النسخة الجاهزة الحالية مخصصة لأجهزة **Apple Silicon**.

1. نزّل التطبيق من [صفحة الإصدارات](https://github.com/HostX0/awake-glass/releases)، وافتحه.
2. اختار مدة، أو **∞** لجلسة مفتوحة.
3. اختار إذا تريد الشاشة تبقى مضاءة، وإذا تريد تأجيل القفل بسبب الخمول.
4. اضغط **ابدأ الجلسة**. تقدر توقفها بأي وقت من البطاقة أو شريط المينو.

**لإبقاء الماك شغّال مع السماح للشاشة تطفي:** عطّل «إبقاء الشاشة مضاءة»؛ ينطفئ خيار تأجيل القفل أيضاً. هذا الوضع مناسب للمهام التي لا تحتاج الوصول للشاشة.

**إخفاء البطاقة يبقي الجلسة شغّالة.** لإظهارها أو إيقاف الجلسة أو إنهاء الأداة، استخدم أيقونتها في شريط المينو.

النسخة الجاهزة موقعة محلياً وليست موثقة لدى Apple. إذا منع Gatekeeper فتحها، تقدر تبني التطبيق من المصدر باستخدام أدوات Apple للتطوير.

## السكون وقفل الشاشة

Awake Glass يطلب من macOS إبقاء الجهاز مستيقظاً بشكل مؤقت، ولا يغيّر إعدادات السكون أو الباسورد المحفوظة. بانتهاء الجلسة، تُرفع الطلبات المؤقتة وتُطبق إعداداتك المعتادة. التطبيقات الأخرى وإعدادات الجهاز قد تؤثر أيضاً على وقت السكون.

خيار تأجيل القفل يستخدم طلبات نشاط الشاشة العامة التي يوفرها macOS، وهو **محاولة بأفضل ما يتيحه النظام**. قد يظل القفل اليدوي أو سياسات أمان الجهاز فعّالاً. الأداة لا تلغي طلب الباسورد ولا تفتح شاشة مقفولة، ولا تضمن منع كل حالات القفل.

## English

**Awake Glass is a small, native glass desktop companion that keeps your Mac awake while your work runs.** Its interface defaults to Arabic; switch to English with the globe button.

- Choose **15, 30, 60, or 120 minutes**, a custom **1–1440 minutes**, or **∞ until stopped**.
- Keep the display awake, optionally request a delay to idle screen locking, and pin the widget above other windows.
- For background work with the display allowed to turn off, disable **Keep the display awake**. Idle-lock delay is disabled with it; the Mac stays awake.
- Temporary awake requests end when the timer expires, you stop the session, or you quit. Your saved sleep and password settings are never rewritten.
- Hiding the widget keeps the session running. Use its menu bar icon to show it, stop a session, or quit.
- No Dock icon, additional dependencies, analytics, or network access.

Requires **macOS 26 or later**. The current packaged download is for **Apple Silicon**. Get it from [Releases](https://github.com/HostX0/awake-glass/releases). The app is ad-hoc signed and is not notarized by Apple; if Gatekeeper blocks it, building from source with Apple's development tools is an alternative.

Idle-lock delay uses public macOS activity requests on a best-effort basis. **Manual locks and managed security policies still apply.** Awake Glass does not change password policy, unlock a locked Mac, or guarantee prevention of every lock. Once a session ends, normal sleep rules apply, including any other active apps and your Mac's own settings.

Feedback and problems: [open an issue](https://github.com/HostX0/awake-glass/issues).

Released under the MIT License.
