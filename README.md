# google-modem

کدهای مرتب‌شدهٔ پروژه Google Modem / Proxy Monitor برای روتر OpenWrt + PassWall2 و برنامه Android.

## آخرین نسخه‌ها

| بخش | نسخه | مسیر |
| --- | --- | --- |
| Android Proxy Monitor | 2.11 | `android/proxy-monitor/` |
| APK خروجی Android | 2.11 | `releases/ProxyMonitorAndroid-v2.11.apk` |
| OpenWrt Proxy Monitor LuCI panel | 15 | `openwrt/proxy-monitor/install-proxy-monitor-v15.sh` |
| Mobile API for Android | 7 | `openwrt/mobile-api/install-proxy-monitor-mobile-api-v7.sh` |
| نسخه‌های بازگشت | 14.3 / API 6 | فایل‌های اصلی حفظ شده‌اند |
| PassWall2 subscribe save fix | 2 | `openwrt/passwall2-fix/fix-passwall2-subscribe-set.sh` |

## ساختار ریپو

```text
google-modem/
├── android/proxy-monitor/       # سورس کامل برنامه Android
├── openwrt/proxy-monitor/       # نصب‌کننده پنل LuCI Proxy Monitor
├── openwrt/mobile-api/          # API روتر برای اتصال اپ Android
├── openwrt/passwall2-fix/       # اصلاح خطای ذخیره Subscription در PassWall2
├── docs/                        # راهنمای نصب و سازگاری
└── releases/                    # آخرین APK آماده نصب
```

## نصب سریع روی روتر

```sh
sh /tmp/install-proxy-monitor-v15.sh
```

اگر هنگام ذخیره Subscription در PassWall2 خطای `node_subscribe_config.lua` دیدید:

```sh
sh /tmp/fix-passwall2-subscribe-set.sh
```

نسخهٔ ۱۵ در **Services → Proxy Monitor** است. ترافیک یا probe مستقل ندارد و در صفحهٔ visible هر۳۰ثانیه وضعیت را می‌خواند. API موجود پیش از حذف collector به v7 مهاجرت می‌کند. v7 توکن می‌خواهد؛ URL اندروید را به‌روز کنید. اگر API موجود نیست، ایجاد آن با `--mobile-api` اختیاری است.

[راهنمای نصب و rollback](docs/installation-fa.md)، [استقرار با Codex محلی](docs/deployment-local-codex-fa.md)، [گزارش ممیزی](docs/proxy-monitor-v15-audit-fa.md). **نصب روتر از Work تأیید نشده است.**

## نکته امنیتی

API موبایل فقط برای LAN طراحی شده است. URL، توکن، Subscription، رمز Wi-Fi، کلید امضا و فایل‌های شخصی نباید در ریپو commit شوند.


