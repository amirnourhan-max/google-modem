# Changelog

## Android Proxy Monitor 2.11

- اصلاح شمارش Active Node در ویجت و برنامه.
- اگر `expected_nodes=5` باشد، حتی با دریافت آرایه بزرگ‌تر، فقط همان ۵ نود معتبر نمایش داده می‌شود.
- حفظ قابلیت‌های نسخه‌های 2.8 تا 2.10:
  - رفرش خودکار با تغییر Public IP.
  - همگام‌سازی برنامه و ویجت‌ها هنگام Refresh.
  - ویجت قابل Resize.
  - نمایش اسکرولی نودها در ویجت.
  - تب PassWall2 داخل برنامه.

## OpenWrt Proxy Monitor 14.3

- پنل LuCI برای نمایش Public IPv4، کشور، وضعیت Xray/Sing-Box، پروفایل PassWall2، وضعیت Balancer و ترافیک.
- نمایش Estimated Active Nodes با سقف `expected_nodes`.
- تشخیص گروه Subscription در نودها.

## Mobile API 6

- endpoint روتر برای برنامه Android.
- Refresh دستی از سمت برنامه.
- خروجی JSON شامل status، traffic و server_time.

## PassWall2 Subscribe Fix 2

- اصلاح ناسازگاری `m.uci:set` / `self:set` با LuCI جدید.
- بکاپ‌گیری خودکار و قابلیت `uninstall` برای بازگردانی.

