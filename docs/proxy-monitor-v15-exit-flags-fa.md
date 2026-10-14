# پرچم نودها و IP خروجی مشاهده‌شدهٔ پروکسی

مبنای این تغییر HEAD موجود `b0ef5627d5d5977f2d906ffb445e276cef12bc41` است. همان شاخهٔ `proxy-monitor-luci-theme-lightweight-v15` و Draft PR #1 ادامه یافته‌اند؛ main، نسخهٔ۱۴٫۳، API6، کد/APK Android و تنظیمات شبکه/هسته‌ها تغییر نکرده‌اند. **نصب روی روتر واقعی تأیید نشده است**؛ SSH از Work به LAN با Network is unreachable مواجه شد.

## رفتار رابط

دو بخش جدید داخل include استاندارد Overview و بالای System قرار دارند:

- **Active Balancer Nodes**: اعضای پیکربندی‌شدهٔ Balancer، نام کامل و گروه اشتراک؛ این عنوان به معنی مشاهدهٔ نود فعال یک اتصال نیست. کشور سرور از `country_code`، `country_iso` یا `country` معتبر گرفته می‌شود و «configured server country» می‌گیرد. کد/نام/پرچم موجود در نام نود صرفاً `inferred` است؛ چند کشور متناقض یا کشور نامشخص 🌐 می‌گیرد. این metadata اثبات جغرافیایی سرور نیست. هیچ آدرس سرور برای تعیین کشور resolve نمی‌شود.
- **Proxy Exit IP**: عنوان دقیق **Observed proxy exit IP — last check**، IPv4/IPv6 عمومی، پرچم و نام/ISO کشور همان IP، زمان آخرین موفقیت، وضعیت آخرین تلاش و مسیر آن بررسی. در leastLoad هر اتصال ممکن است نود دیگری بگیرد؛ از کشور، نام، تأخیر یا IP، نود فعال حدس زده نمی‌شود.

پرچم‌ها Unicode محلی با whitelist همهٔ۲۴۹ کد ISO3166-1 هستند؛ نام انگلیسی کشورها از Intl/CLDR هنگام توسعه در source ثابت ذخیره شده است. asset خارجی وجود ندارد. سیستم‌عامل بدون فونت پرچم ممکن است حروف منطقه‌ای را نمایش دهد؛ نام و ISO همیشه کنار آن هستند. نام/گروه با text node و dir=auto، IP/مسیر با LTR نمایش داده می‌شوند؛ CSS تنها به پنل محدود است و رنگ/فونت تم LuCI را به ارث می‌برد.

## جداسازی قطعی درخواست از WAN مستقیم

فقط دکمهٔ **Check proxy exit IP**، متد authenticated و بدون آرگومان `proxy-monitor.exit_refresh` را اجرا می‌کند. Overview/status، API7، fresh=1 اندروید و نصب هیچ بررسی خارجی انجام نمی‌دهند. RPC با process غیرهمزمان/deferred کار می‌کند تا session و status هنگام انتظار شبکه مسدود نشوند.

SOCKS از native UCI خوانده می‌شود؛ port پیش‌فرض حدس زده نمی‌شود:

1. SOCKS موجود و فعال اختصاصی که مستقیماً به Balancer انتخاب‌شده وصل است، ترجیح دارد.
2. SOCKS اصلی فقط وقتی پروفایل به مسیر پروکسی پشتیبانی‌شده یا Balancer با اعضای معتبر و غیرخالی وصل باشد پذیرفته می‌شود.
3. **SOCKS اصلی Shunt، fallback مستقیم، اعضای خالی/نامعتبر، schema ناشناخته و SOCKS دارای auto-switch پذیرفته نمی‌شوند.** Shunt می‌تواند مقصد echo را DIRECT کند؛ نسبت‌دادن نتیجهٔ آن به پروکسی قابل اعتماد نیست. مانیتور هیچ SOCKS جدیدی ایجاد یا تنظیمات Passwall2 را تغییر نمی‌دهد. اگر دستگاه فقط SOCKS متصل به `iran_auto_shunt` دارد و SOCKS اختصاصیِ مناسب از قبل وجود ندارد، IP card عمداً UNAVAILABLE خواهد بود؛ این محدودیت برای جلوگیری از نمایش WAN به نام پروکسی است.

مسیر `socks5h://127.0.0.1:<port> → <profile-id>` نشان‌دهندهٔ transport استفاده‌شده و پروفایل پیکربندی‌شده است، نه نام نود واقعی یا تضمین همسان‌بودن UCI با یک engine که تنظیمات جدید هنوز روی آن اعمال نشده است.

درخواست IP به `https://api64.ipify.org?format=json` می‌رود. کشور با `https://ipwho.is/<observed-IP>?fields=success,ip,country,country_code` تعیین می‌شود؛ IP بازگشتی geolocation باید با IP مشاهده‌شده برابر باشد. **هر دو درخواست از همان SOCKS عبور می‌کنند**؛ ممکن است اتصال دوم در leastLoad خروجی دیگری بگیرد، ولی geolocation برای IP صریح درخواست‌شده است. endpoint از کاربر گرفته نمی‌شود.

curl با argv مستقل و بدون shell interpolation اجرا می‌شود: `--disable` برای حذف curlrc، `--proxy socks5h://127.0.0.1:...`، `--noproxy ''`، HTTPS-only/TLS verification، connect timeout۲ثانیه، max-time۵ثانیه و max-filesize۴۰۹۶بایت. محیط curl whitelist شده، redirect و insecure فعال نیستند؛ هیچ fallback مستقیم وجود ندارد. پاسخ JSON، IP عمومی و code کشور validate می‌شوند. خروجی فایل نیز با ulimit محدود است. loopback/private/CGNAT/multicast/reserved/documentation و IPv6 transition/zone-id رد می‌شوند؛ پذیرش IPv6 عمداً محافظه‌کارانه است.

curl دارای HTTPS/SOCKS، CAهای معتبر و `ucode-mod-uloop` فقط برای این قابلیت اختیاری لازم‌اند. نبود آن‌ها status/flags و نصب را خراب نمی‌کند و IP card UNAVAILABLE می‌شود. package خودکار نصب نمی‌شود.

## کش و هزینه

کش خصوصی۶۰۰ root در `/tmp/proxy-monitor-exit.json`، حداکثر۱۶KiB، با rename اتمیک نوشته می‌شود. status فقط آن را می‌خواند. آخرین موفقیت هنگام خطای بعدی حفظ می‌شود و همچنان با زمان/مسیر قبلی نمایش داده می‌شود؛ وضعیت خطا جداست. پس از reboot کش پاک می‌شود.

کش geolocation تا۱۶ IP است؛ IP ثابت lookup موفق تکراری ندارد، IPهای رفت‌وبرگشتی از کش استفاده می‌کنند و خطای geo cache منفی۵دقیقه‌ای دارد. retry تنها با کلیک دستی بعدی انجام می‌شود. درخواست دستی کمتر از۱۵ثانیه یا همزمان چند تب، بررسی دیگری راه نمی‌اندازد. lock موقتِ check کرش‌کرده پس از۳۰ثانیه قابل بازیابی است؛ daemon یا timer دائمی وجود ندارد. نصب/rollback با check همزمان تداخل نمی‌کنند.

نمونهٔ محلی با سه عضو و process/UCI fixtures: میانگین۳۰ اجرای helper حدود۲۲٫۵۴ms، CPU یک اجرا حدود۲۰ms و peak RSS حدود۱۸۲۸KiB؛ JSON حدود۱۸۷۴بایت. این اندازه‌گیری x86 محیط توسعه است، نه ARM روتر. هزینهٔ router CPU/RAM باید محلی سنجیده شود؛ curl فقط هنگام درخواست دستی و حداکثر دو اتصال کوتاه اجرا می‌شود. هیچ traffic/RxTx/ping/database یا نوشتن دوره‌ای به flash اضافه نشده است.

## قرارداد Balancer و Android

adapter حالت manual (`balancing_node` لیست یا رشته)، و batch (`node_group` URL-encoded و قواعد literal AND/OR با !/^/$) را بر اساس source Passwall2 پشتیبانی می‌کند. اعضای تکراری حذف، reference مفقود UNAVAILABLE و schema ناشناخته مشخص می‌شود. نمایش حداکثر۱۲۸ عضو، نام۱۰۲۴بایت و گروه۵۱۲بایت است؛ محدودیت لیست آشکار نمایش داده می‌شود و metadata URL/credentials/control/oversize منتشر نمی‌شود. آدرس/رمز/کلید/URL subscription خروجی نمی‌شوند.

API7 فقط فیلدهای افزودهٔ `balancer_nodes`، `balancer_nodes_supported/truncated` و `proxy_exit` دارد. `status/traffic/server_time`، core/profile و احراز هویت قبلی حفظ شده‌اند. `expected_nodes` شمار اعضای configured است؛ `active_nodes` همچنان خالی و `public_ip/country_code` قدیمی همچنان خالی‌اند تا Android2.11 نتواند عضو configured را active یا مشاهدهٔ قدیمی را IP زنده فرض کند. Android parsing جدید لازم نیست؛ اپ قدیمی فیلدهای جدید را نادیده می‌گیرد. مشاهدهٔ کارت‌های جدید در APK قدیمی اضافه نشده و تست روی گوشی واقعی هنوز تأیید نشده است.

## امنیت، نصب و اعتبارسنجی

ACL فقط `status` و `exit_refresh` را به خوانندهٔ مجاز LuCI می‌دهد؛ command، URL، host، port یا credentials از RPC پذیرفته نمی‌شود. دسترسی anonymous مجاز نیست و exec/file permission عمومی افزوده نشده است. API موبایل همان token/LAN/GET را می‌خواهد. هیچ listener یا سرویس WAN ساخته نمی‌شود.

installer خودکفا همهٔ فایل‌های جدید، ACL و کش موجود را snapshot می‌کند؛ rollback فایل‌ها و permissionهای قبلی را بازمی‌گرداند. فقط rpcd/cache LuCI refresh می‌شود؛ Xray/Passwall2/sing-box/DNS/Watchdog/LED/Wi-Fi/LAN/WAN/firewall دست‌نخورده‌اند. پاسخ readiness اکنون `rpc_revision:3` است. راهنمای دقیق انتقال/هش/rollback در installation-fa.md است.

آزمون‌ها شامل known/unknown/name inference/Unicode، نام/گروه طولانی، manual/batch/empty OR، Balancer خالی و DIRECT/auto-switch، IPv4/IPv6/آدرس خصوصی و cache خراب، failure/geo cache/manual refresh، نصب مجدد/rollback/نبود dependency اختیاری و API7 هستند. آزمایش شبکه با **curl واقعی، TLS معتبر و SOCKS5h محلی** انجام می‌شود؛ هیچ سرویس IP عمومی در آزمون تماس نمی‌گیرد و direct fallback احتمالی به localhost بسته هدایت می‌شود. daemonهای واقعی ubusd/rpcd و بررسی Light/Dark/RTL/عرض‌های۳۶۰،۷۶۸،۱۳۶۶ نیز در CI اجرا می‌شوند. وضعیت نهایی CI و تصاویر پس از اتمام اجرا در PR و گزارش تحویل ثبت می‌شود؛ نتایج fixture جای نصب واقعی دستگاه را نمی‌گیرند.

در بازبینی مستقل، خطر fallback مستقیم Balancer بدون عضو، اختلاف قواعد OR خالی، تشخیص auto-switch و dependency اختیاری پیدا و با آزمون رگرسیون اصلاح شد.

اعتبارسنجی پیاده‌سازی در [CI38631563055](https://github.com/amirnourhan-max/google-modem/actions/runs/38631563055) روی commit `2f621d09d95d22c2a81f6cb4c43b986644109321` موفق شد: **۴۹ آزمون بدون skip**، build و اجرای daemonهای واقعی، پاسخ deferred بدون مسدودشدن session/status، شبکهٔ curl/TLS/SOCKS5h واقعی و شش چیدمان Chromium. محلی۴۶ آزمون موفق و۳ آزمون daemon یونیکس به علت محدودیت محیط skipped بودند؛ آن سه در CI اجرا شدند. تصاویر جدید در `tests/proxy-monitor/evidence/` از ZIP با SHA256 `2ba1a8c251a842e2ba999c5044d82353a136e9e9ab8d8231a49e14dcb06cb2fd` بازیابی، صحت‌سنجی و بصری بررسی شدند. contrast در Light حدود۱۰٫۳۷ و Dark حدود۸٫۶۵ و opacity نهایی۱ است. هر دو کارت قبل از System، بدون overflow، با حفظ RTL/LTR و پرچم‌های محلی دیده می‌شوند. این نتیجهٔ fixture توسعه است؛ نصب روتر یا Refresh واقعی گوشی را اثبات نمی‌کند.

منابع قراردادها: [curl](https://curl.se/docs/manpage.html)، [ipify](https://www.ipify.org/)، [ipwho.is](https://ipwhois.io/documentation)، source اصلی Passwall2 در adapter بررسی‌شده. API geolocation سرویس خارجی بدون SLA است؛ خرابی/تغییر schema آن تنها کشور را UNKNOWN می‌کند.
