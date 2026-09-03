# راهنمای نصب فارسی

## 1. نصب پنل Proxy Monitor روی OpenWrt

فایل زیر را روی روتر، مثلاً داخل `/tmp`، کپی کنید:

```text
openwrt/proxy-monitor/install-proxy-monitor-v14.3.sh
```

سپس از SSH اجرا کنید:

```sh
chmod +x /tmp/install-proxy-monitor-v14.3.sh
/tmp/install-proxy-monitor-v14.3.sh
```

بعد از نصب، صفحه LuCI را Refresh کنید و از مسیر Status، پنل Proxy Monitor را ببینید.

## 2. نصب API موبایل

فایل زیر را روی روتر کپی کنید:

```text
openwrt/mobile-api/install-proxy-monitor-mobile-api-v6-manual-refresh.sh
```

سپس اجرا کنید:

```sh
chmod +x /tmp/install-proxy-monitor-mobile-api-v6-manual-refresh.sh
/tmp/install-proxy-monitor-mobile-api-v6-manual-refresh.sh
```

خروجی نصب، آدرس API و مقدار موردنیاز برای اتصال برنامه Android را نمایش می‌دهد.

## 3. نصب برنامه Android

آخرین APK آماده:

```text
releases/ProxyMonitorAndroid-v2.11.apk
```

APK را روی نسخه قبلی نصب کنید و برنامه را حذف نکنید تا تنظیمات باقی بماند.

## 4. اصلاح خطای ذخیره Subscription در PassWall2

اگر هنگام افزودن یا ذخیره Subscription خطای `node_subscribe_config.lua` دیدید، فایل زیر را روی روتر اجرا کنید:

```sh
chmod +x /tmp/fix-passwall2-subscribe-set.sh
/tmp/fix-passwall2-subscribe-set.sh
```

برای بازگردانی:

```sh
/tmp/fix-passwall2-subscribe-set.sh uninstall
```

