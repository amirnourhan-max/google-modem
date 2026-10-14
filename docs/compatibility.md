# سازگاری v15 و APIv7

| بخش | قرارداد | محدودیت |
|---|---|---|
| Passwall2 | خواندن native UCI با cursor؛ `global.node` سپس alias `tcp_node`؛ enabled و procd جدا | schema ناشناخته به UNKNOWN می‌رسد؛ ucode-mod-uci لازم است |
| Shunt | `_shunt`، `default_node`، `Iran` و `PrivateIP` | configured routing است؛ قانون با شناسهٔ سفارشی UNKNOWN است |
| Balancer | `_balancing`، `balancingStrategy/strategy` | نود دقیق فعال قابل مشاهده نیست |
| Xray / sing-box | نام پردازش و executable discovery؛ `global_app.xray_file/sing_box_file` | binary اجرا نمی‌شود؛ basename سفارشی نیز جست‌وجو می‌شود |
| LuCI | baseclass include استاندارد `view/status/include/00_proxy-monitor.js`؛ section/button و scoped CSS | قبل از `10_system.js`؛ Overview صاحب polling است و مانیتور درخواست را۳۰ثانیه throttle می‌کند |
| RPC | native script `/usr/share/rpcd/ucode/proxy-monitor`، object صریح `proxy-monitor.status` | rpcd-mod-ucode لازم است؛ بررسی صرف shell list کافی نیست؛ پاسخ revision3 پس از restart انتظار می‌رود |

هیچ وابستگی به JSON موقت engine، PID ثابت یا تغییر فایل‌های متعلق به Passwall2/core وجود ندارد. تغییرهای breaking ناشناخته تضمین نمی‌شوند.

## قراردادهای recovery

این فایل‌ها فقط خوانده می‌شوند؛ هیچ وضعیت جدیدی برای watchdog/LED تولید نمی‌شود. قرارداد واقعی دستگاه در مخزن نیست و باید محلی تطبیق داده شود:

| مسیر | دادهٔ مجاز |
|---|---|
| `/root/recovery/always-on-watchdog.state` | counter عددی حداکثر۸رقم |
| `/root/recovery/resilience-mode` | normal/fallback/degraded/emergency/extreme/zapret2 |
| `/etc/crontabs/root` | دستور فعال internet-watchdog.sh؛ همراه crond و نبود watchdog.disabled |
| `/var/run/internet-led-status/state` یا current | enum رنگ/وضعیت؛ procd سرویس LED جدا |
| `/var/run/internet-health/state` | enum یا JSON با status/state؛ سن حداکثر۱۸۰ثانیه |

watchdog به‌عنوان scheduled نمایش داده می‌شود، نه اثبات اجرای موفق recovery. health فقط healthy/ok/online/degraded/offline/failed را می‌پذیرد. last_event فقط recovered/proxy_restart/dns_restart/fallback_enabled/fallback_disabled/cooldown/healthy است. log آزاد نمایش داده نمی‌شود؛ مفقود/نامعتبر/کهنه UNKNOWN است. وضعیت process به‌تنهایی اثبات سلامت اینترنت یا DNS نیست.

## Android2.11

APK و سورس تغییر نکرده‌اند. ساختار `status/traffic/server_time` و نام فیلدهای RouterApi.kt حفظ شده است؛ وضعیت core و selected profile باقی می‌ماند. تغییرهای عمدی:

- APIv7 توکن می‌خواهد؛ URL قبلی باید `?token=<توکن محلی>` داشته باشد. برنامه fresh=1 را به همین URL اضافه می‌کند.
- traffic.available=false، rx_bytes=tx_bytes=0 و device خالی؛ هیچ collection انجام نمی‌شود. APK قدیمی این flag را نمی‌شناسد و ممکن است سرعت صفر نمایش دهد؛ این اندازه‌گیری نیست.
- public_ip/country_code خالی و active_nodes/balancers آرایهٔ خالی‌اند. فقط LuCI متد دستی exit_refresh دارد؛ status/API هیچ probe خودکار یا حدس active node ندارد. فیلدهای افزوده balancer_nodes و proxy_exit در اپ قدیمی نادیده گرفته می‌شوند. IP-monitor مستقل خود اپ تغییر نکرده است.
- UNKNOWN boolean در backend برابر null است؛ parser قدیمی اندروید آن را false می‌خواند. LuCI UNKNOWN نمایش می‌دهد.

APIv6 را دوباره روی v15 نصب نکنید؛ collector آن حذف شده و احراز هویت ندارد. rollback کامل، API/helper/collector پیشین را با هم برمی‌گرداند. API جدید listener یا دسترسی WAN ایجاد نمی‌کند. LAN restriction به‌تنهایی authentication نیست؛ token نیز لازم است. HTTPS موجود روتر ترجیح دارد؛ URL دارای token را منتشر نکنید.

## پرچم و خروجی SOCKS

[قرارداد دقیق و محدودیت‌های کشور/IP](proxy-monitor-v15-exit-flags-fa.md). کشور سرور metadata/inferred است؛ کشور خروجی فقط از geolocation همان IP مشاهده‌شده تعیین می‌شود. اعضای Balancer configured هستند؛ انتخاب runtime نود قابل مشاهده نیست. نبود curl/CA/uloop، Shunt، auto-switch، fallback DIRECT یا Balancer خالی/نامعتبر فقط check دستی را UNAVAILABLE می‌کند؛ status ادامه دارد.
