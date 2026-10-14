# گزارش ممیزی Proxy Monitor v15

**مبدأ:** شاخهٔ موجود proxy-monitor-luci-theme-lightweight-v15 با HEAD واقعی `b0064f64bfa047d66826b6ba813c9e79df7351f7`. v14.3 و API6 و سورس/APK اندروید2.11 حفظ شدند؛ main تغییر نکرد و PR merge نمی‌شود.

| ایراد اولیه | اصلاح |
|---|---|
| حذف collector با باقی‌ماندن نیاز API6 | مهاجرت API موجود پیش از حذف؛ API7 بدون traffic collection |
| تبدیل badge به String | نگهداری DOM node |
| دادهٔ مفقود برابر stopped | boolean/null؛ malformed procfs/procd و schema به UNKNOWN |
| theme tokens حدسی و contrast محدود | بررسی Bootstrap واقعی، رنگ/فونت ارثی، scoped borders و fallback |
| enabled برابر running؛ routing برابر connectivity | نمایش جداگانهٔ UCI/procd، برچسب configured، active node برابر UNKNOWN |
| cron-comment برابر watchdog فعال | تشخیص دستور فعال + crond + disabled flag؛ برچسب scheduled |
| shared health صرف وجود فایل | whitelist/schema/age حداکثر۱۸۰ثانیه و event enum؛ بدون log خام |
| backup timestamp قابل تصادم | mktemp، snapshot خصوصی مستقل در هر نصب |
| خطای میانی و نوشتن مستقیم live | staging validation، rename اتمیک، rollback trap، lock و رد symlink |
| قابلیت file.exec در ACL | rpcd method اختصاصی read-only proxy-monitor.status |
| API بدون authentication | token۲۵۶بیتی، LAN restriction، GET-only و JSON validation |
| core سفارشی و alias قدیمی | global_app executable discovery و tcp_node fallback |

**Light/Dark و RTL:** section/button بومی و inherited typography/color؛ background ثابت یا CSS global وجود ندارد. badgeها از رنگ متن تم استفاده می‌کنند. مقادیر فنی LTR و نام فارسی dir=auto هستند. sing-box غیرفعال standby است. CSS Bootstrap در commit `d12d55376188343d790fa40377c084245a4d2b86` بررسی شده است؛ theme واقعی روتر هنوز نیازمند تأیید محلی است.

**بار منابع:** بدون Rx/Tx/history/chart، ping/DNS/HTTP probe، database، cron یا daemon جدید. خواندن status write ندارد؛ polling۳۰ثانیه‌ای هنگام hidden/خروج صفحه درخواست نمی‌دهد و درخواست هم‌زمان تجمیع می‌شود. benchmark۱۰۰درخواست fixture Linux x86_64 با ucode واقعی: median wall۱۱٫۶ms، p95۱۷٫۶ms، median CPU۱۰٫۶ms، حداکثر peak RSS۱۷۵۶KiB. این اندازه‌گیری ARMv7 نیست؛ ubus/UCI واقعی و تعداد processها بر آن اثر دارند. بعد از درخواست monitor process باقی نمی‌ماند.

**سازگاری هسته‌ها:** وابستگی به binaries/API داخلی/generated JSON/PID ثابت حذف شده است. UCI و procd و snapshot پردازش خوانده می‌شوند؛ executableهای استاندارد و تنظیم‌شده فقط کشف می‌شوند. تغییر ناشناختهٔ آینده تضمین نمی‌شود؛ قراردادهای adapter در compatibility.md آمده‌اند.

**اندروید:** نام فیلدهای parser2.11 حفظ شده، core/profile باقی‌اند. URL نیاز به token دارد. traffic.available=false و counters صفر، public IP/country خالی و active_nodes خالی‌اند؛ ویجت قدیمی ممکن است سرعت صفر یا اطلاعات خالی نشان دهد. این intentional است؛ سورس/APK تغییر نکرده و کارکرد واقعی گوشی هنوز تأیید نشده است. parser قدیمی null boolean را false می‌خواند.

**امنیت:** دو فرمان ثابت local ubus؛ UCI values/process names وارد shell نمی‌شوند. secrets/subscriptions/private keys خروجی نیستند؛ دادهٔ config در حافظه به فیلدهای allowlist محدود می‌شود. token/backup خصوصی، ACL narrow، بدون anonymous status و بدون listener/WAN/firewall change. HTTPS موجود برای token ترجیح دارد.

**آزمایش واقعی:** ۲۱ آزمون محلی با ucode واقعی و filesystem disposable پاس شدند: core/routing، missing Xray، inactive sing-box، UCI خراب/partial/future، executable سفارشی، procfs/procd مفقود/خراب، health تازه/کهنه/خراب، counter۰، cron، secrets، API shape/auth/LAN/GET/malformed، نصب تکراری، snapshot rollback، write/rpcd failure، lock و symlink. shell/JS syntax و ACL/menu JSON نیز بررسی شدند. fixtureها مرزهای ubus/rpcd/procfs را شبیه‌سازی می‌کنند؛ OpenWrt کامل نیستند.

CI اختصاصی ucode+Chromium برای۶حالت Bootstrap Light/Dark/RTL در۳۶۰/۷۶۸/۱۳۶۶ و fallback بدون tokens، contrast، partial JSON و hidden polling اجرا شد. در run38531105768، آزمون‌های shell/runtime/API و browser پاس شدند؛ تنها upload-artifact با خطای صریح quota شکست خورد. ذخیرهٔ شواهد به ZIP دارای SHA256 در job log و گزارش در step summary منتقل شد؛ مجوز CI همچنان contents:read است و test failure مخفی نمی‌شود. اجراهای قبلی با URL نادرست upstream و نبود root در runner شکست خورده بودند؛ هر دو اصلاح شدند. نتیجهٔ workflow نهایی در PR/تحویل ثبت می‌شود.

**نتیجهٔ ثبت‌شده:** [Run38531448259 — Success](https://github.com/amirnourhan-max/google-modem/actions/runs/38531448259)؛ ۲۱ آزمون runtime و تمام آزمون‌های Chromium و export شواهد موفق شدند. تصاویر واقعی renderer و JSON در `tests/proxy-monitor/evidence/` حفظ شده‌اند. نسبت contrast اندازه‌گیری‌شده۱۰٫۳۷در Light و۸٫۶۵در Dark است. Light desktop و Dark mobile نیز بصری بازبینی شدند و هم‌پوشانی/اسکرول افقی مشاهده نشد. این fixture صفحهٔ واقعی روتر نیست.

**نصب:** NOT VERIFIED. SSH از Work با Network is unreachable شکست خورد؛ هیچ فایل یا سرویس روتر تغییر نکرد. پیش از deploy باید سلامت Extreme Internet Resilience، SSH و تم واقعی محلی تأیید شود. دستورات دقیق و rollback در installation-fa.md و دستور کار Codex ویندوز در deployment-local-codex-fa.md هستند.

**محدودیت‌ها:** قرارداد واقعی watchdog/LED در مخزن نیست؛ ناسازگاری UNKNOWN است. خواندن UCI حداکثر۲۶۲۱۴۴بایت است؛ config بسیار بزرگ یا schema ناشناخته ممکن است UNKNOWN بدهد. کل نصب transaction اتمیک filesystem نیست؛ فقط هر فایل اتمیک جایگزین می‌شود. SIGKILL/قطع برق ممکن است rollback خودکار را متوقف کند؛ snapshot/manual rollback باقی می‌ماند. نود دقیق فعال balancer دانسته نمی‌شود. ACL/rpcd/Android/theme واقعی باید روی دستگاه آزمایش شوند.

منابع بررسی‌شده: rpcd plugin.c و LuCI conventions؛ Passwall2 upstream `492309ea672c9c40725e2a72cb4d4f1625d9ee53` برای global/shunt/balancing/custom binaries؛ ucode `fa288dd9b827045265900d0d25f9d834ffd755bf` برای runtime واقعی.
