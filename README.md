# google-modem

کدهای مرتب‌شدهٔ پروژه Google Modem / Proxy Monitor برای روتر OpenWrt + PassWall2 و برنامه Android.

## آخرین نسخه‌ها

| بخش | نسخه | مسیر |
| --- | --- | --- |
| Android Proxy Monitor | 2.11 | `android/proxy-monitor/` |
| APK خروجی Android | 2.11 | `releases/ProxyMonitorAndroid-v2.11.apk` |
| OpenWrt Proxy Monitor LuCI panel | 14.3 | `openwrt/proxy-monitor/install-proxy-monitor-v14.3.sh` |
| Mobile API for Android | 6 | `openwrt/mobile-api/install-proxy-monitor-mobile-api-v6-manual-refresh.sh` |
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
sh /tmp/install-proxy-monitor-v14.3.sh
sh /tmp/install-proxy-monitor-mobile-api-v6-manual-refresh.sh
```

اگر هنگام ذخیره Subscription در PassWall2 خطای `node_subscribe_config.lua` دیدید:

```sh
sh /tmp/fix-passwall2-subscribe-set.sh
```

جزئیات کامل در `docs/installation-fa.md` آمده است.

## نکته امنیتی

API موبایل فقط برای LAN طراحی شده است. URL، توکن، Subscription، رمز Wi-Fi، کلید امضا و فایل‌های شخصی نباید در ریپو commit شوند.

