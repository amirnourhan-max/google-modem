# نصب و rollback نسخهٔ۱۵

**Router deployment: NOT VERIFIED.** از Work مسیر SSH به192.168.28.1 وجود ندارد. نصب CLI و آزمایش fixture جای تأیید صفحهٔ واقعی روتر را نمی‌گیرند.

ابتدا داخل LAN سلامت اینترنت/DNS، SSH، Extreme Internet Resilience و LED را فقط‌خواندنی بررسی کنید. اگر baseline یا مدیریت سالم نیست، نصب را انجام ندهید. شاخهٔ موجود `proxy-monitor-luci-theme-lightweight-v15` را دریافت و HEAD را با SHA گزارش تحویل تطبیق دهید. ucode+fs، ubus، rpcd با exec-plugin و LuCI پیش‌نیازند؛ installer مستقل و آفلاین است.

داخل clone در PowerShell:

```powershell
ssh root@192.168.28.1 "true"
Get-FileHash .\openwrt\proxy-monitor\install-proxy-monitor-v15.sh -Algorithm SHA256
scp -O .\openwrt\proxy-monitor\install-proxy-monitor-v15.sh root@192.168.28.1:/tmp/install-proxy-monitor-v15.sh
ssh root@192.168.28.1 "sha256sum /tmp/install-proxy-monitor-v15.sh; sh -n /tmp/install-proxy-monitor-v15.sh"
```

هش روتر و محلی باید برابر باشند. host key را با fingerprint معتبر تطبیق دهید؛ StrictHostKeyChecking را غیرفعال نکنید. پس از تأیید baseline:

SHA256 نصب‌کنندهٔ آزموده‌شده: `2f4e18b4e88995c583d3c1fdc80294444d0af1e87bb5966ad7bd3ed5704d04d3`.

```powershell
ssh root@192.168.28.1 "sh /tmp/install-proxy-monitor-v15.sh"
ssh root@192.168.28.1 "ubus call proxy-monitor status"
ssh root@192.168.28.1 "test ! -e /usr/libexec/proxy-monitor-traffic"
ssh root@192.168.28.1 "true"
```

installer ابتدا snapshot خصوصی با نام یکتا `/root/recovery/proxy-monitor-v15-XXXXXXXX` می‌سازد؛ compile/runtime/JSON checks پیش از نوشتن انجام می‌شوند. هر فایل با rename اتمیک جایگزین می‌شود. خطای میانی یا RPC موجب rollback می‌شود. فقط rpcd restart و cache LuCI refresh می‌شود؛ جلسهٔ LuCI ممکن است ورود مجدد بخواهد. proxy/DNS/watchdog/LED/wireless/network/firewall/uhttpd restart نمی‌شوند.

صفحهٔ **Services → Proxy Monitor** را در تم واقعی Light/Dark، RTL و موبایل بررسی کنید. Status Overview نباید duplicate داشته باشد. درخواست وضعیت حدود هر۳۰ثانیه و تنها در تب visible است؛ درخواست درحال اجرا ممکن است بعد از مخفی‌شدن تکمیل شود. حذف includeهای00 و75 را بررسی و سلامت شبکه/SSH را دوباره تأیید کنید.

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
