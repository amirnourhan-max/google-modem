# نصب و rollback نسخهٔ۱۵

**Router deployment: NOT VERIFIED.** از Work مسیر SSH به192.168.28.1 وجود ندارد. نصب CLI و آزمایش fixture جای تأیید صفحهٔ واقعی روتر را نمی‌گیرند.

ابتدا داخل LAN سلامت اینترنت/DNS، SSH، Extreme Internet Resilience و LED را فقط‌خواندنی بررسی کنید. اگر baseline یا مدیریت سالم نیست، نصب را انجام ندهید. شاخهٔ موجود `proxy-monitor-luci-theme-lightweight-v15` را دریافت و HEAD را با SHA گزارش تحویل تطبیق دهید. ucode+fs+uci، ubus، rpcd-mod-ucode و LuCI Overview پیش‌نیازند؛ installer مستقل و آفلاین است. در نبود module، نصب پیش از تغییر فایل‌ها متوقف می‌شود و package خودکار نصب نمی‌کند.

داخل clone در PowerShell:

```powershell
ssh root@192.168.28.1 "true"
Get-FileHash .\openwrt\proxy-monitor\install-proxy-monitor-v15.sh -Algorithm SHA256
scp -O .\openwrt\proxy-monitor\install-proxy-monitor-v15.sh root@192.168.28.1:/tmp/install-proxy-monitor-v15.sh
ssh root@192.168.28.1 "sha256sum /tmp/install-proxy-monitor-v15.sh; sh -n /tmp/install-proxy-monitor-v15.sh"
```

هش روتر و محلی باید برابر باشند. host key را با fingerprint معتبر تطبیق دهید؛ StrictHostKeyChecking را غیرفعال نکنید. پس از تأیید baseline:

SHA256 نصب‌کنندهٔ اصلاح‌شده: `5ec512dcb571c619405cb3bf9d9b379b3c1cbae472b641a68e44f3b0397bb630`.

```powershell
ssh root@192.168.28.1 "sh /tmp/install-proxy-monitor-v15.sh"
ssh root@192.168.28.1 "ubus call proxy-monitor status"
ssh root@192.168.28.1 "test ! -e /usr/libexec/proxy-monitor-traffic"
ssh root@192.168.28.1 "true"
```

installer ابتدا snapshot خصوصی با نام یکتا `/root/recovery/proxy-monitor-v15-XXXXXXXX` می‌سازد؛ compile/runtime/JSON checks پیش از نوشتن انجام می‌شوند. هر فایل با rename اتمیک جایگزین می‌شود. خطای میانی یا RPC موجب rollback می‌شود. فقط rpcd restart و cache LuCI refresh می‌شود؛ جلسهٔ LuCI ممکن است ورود مجدد بخواهد. proxy/DNS/watchdog/LED/wireless/network/firewall/uhttpd restart نمی‌شوند.

صفحهٔ **Status → Overview** را در تم واقعی Light/Dark، RTL و موبایل بررسی کنید؛ Proxy Monitor باید **بالای System** باشد و فقط include00 جدید وجود داشته باشد. include75 و منوی Services قبلی حذف می‌شوند؛ هیچ core file LuCI تغییر نمی‌کند. Overview ممکن است سایر بخش‌ها را با چرخهٔ سریع‌تر بخواند؛ درخواست RPC خود مانیتور حدود۳۰ثانیه و تنها در تب visible و بخش باز است. درخواست درحال اجرا ممکن است بعد از مخفی‌شدن تکمیل شود. پاسخ RPC باید `rpc_backend:ucode` و `rpc_revision:3` داشته باشد. سلامت شبکه/SSH را دوباره تأیید کنید.

خطای قبلی `Not found` در installer بلافاصله بعد از restart بررسی می‌شد؛ نسخهٔ جدید حداکثر۱۰ تلاش با timeout۲ثانیه و فاصله۱ثانیه دارد. این انتظار فقط هنگام نصب است و loop دائمی نیست. اگر ثبت/پاسخ native واقعاً شکست بخورد، snapshot بازمی‌گردد. بعد از rollback نبود object طبیعی است؛ نتیجهٔ مستقیم script.list اثبات ثبت آن در daemon نیست.

## موبایل

API موجود خودکار به v7 مهاجرت می‌کند. اگر وجود ندارد، ایجاد اختیاری:

```powershell
ssh root@192.168.28.1 "sh /tmp/install-proxy-monitor-v15.sh --mobile-api"
```

companion v7 نیز باید کنار installer v15 باشد. token۲۵۶بیتی در `/etc/proxy-monitor/mobile-token` با permission0600 است؛ installer آن را چاپ نمی‌کند. در ترمینال محلی امن بخوانید و URL اپ را به `http://192.168.28.1/cgi-bin/proxy-monitor-mobile?token=<توکن محلی>` تغییر دهید. HTTPS موجود ترجیح دارد. token را در chat/log/GitHub ذخیره نکنید. بدون token باید403 و با token پاسخ API7 و traffic.available=false دریافت شود. Refresh واقعی اپ/ویجت2.11 را آزمایش کنید؛ محدودیت‌های intentional در compatibility.md آمده‌اند.

## بازگشت

مسیر دقیق snapshot در خروجی نصب است:

```sh
sh /root/recovery/proxy-monitor-v15-XXXXXXXX/rollback.sh
```

نام واقعی backup را جایگزین کنید. snapshot منتخب فایل‌ها/permissions قبلی و API/collector را برمی‌گرداند و فایل‌های تازه را حذف می‌کند؛ فقط rpcd refresh می‌شود. backup در نصب مجدد بازنویسی نمی‌شود. rollback نیز lock نصب را رعایت می‌کند. قطع برق/SIGKILL ممکن است مانع rollback خودکار شود؛ اسکریپت باقی می‌ماند. اگر lock مانده، ابتدا محلی نبودن عملیات نصب/rollback را تأیید و سپس فقط directory خالی lock را rmdir کنید. v14.3 یا API6 را کورکورانه روی v15 اجرا نکنید.

## بررسی دستی IP خروجی و پرچم‌ها

[قرارداد و محدودیت مسیر](proxy-monitor-v15-exit-flags-fa.md) را بخوانید. پس از نصب، اعضای configured Balancer و دو نوع کشور سرور/IP خروجی را در Overview بررسی کنید. فقط دکمهٔ Check proxy exit IP درخواست خارجی می‌دهد؛ status/Android fresh=1 درخواست خارجی نمی‌دهند. curl با HTTPS/SOCKS و CA معتبر و ucode-mod-uloop برای این دکمه اختیاری لازم‌اند؛ installer package نصب نمی‌کند. با SOCKS اصلی متصل به Shunt یا Balancer بدون عضو معتبر، DIRECT fallback یا auto-switch، کارت IP عمداً UNAVAILABLE است. مانیتور تنظیمات proxy را برای عبور از این محدودیت عوض نمی‌کند. در صورت مسیر مناسب موجود، یک بررسی دستی و سپس بررسی کش IP/کش کشور را انجام دهید؛ شکست بعدی باید آخرین موفقیت و زمانش را حفظ کند.

متد محلی دستی (فقط هنگام مسیر مناسب):

```sh
ubus -t 15 call proxy-monitor exit_refresh
ubus call proxy-monitor status
```

هنگام بررسی دستی، نصب/rollback تا پایان آن متوقف می‌شود؛ snapshot جدید کش قبلی و helperهای جدید را نیز حفظ می‌کند. کش /tmp پس از reboot پاک می‌شود. هیچ upload/download یا collector ترافیک اضافه نشده است.
