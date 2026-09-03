# Proxy Monitor Android v2.11

نسخه دوم اپ Android برای مانیتور OpenWrt / PassWall2 / Xray با دو ویجت Home Screen.

## تب‌های برنامه

- تب `Monitor` برای IP، وضعیت Core، ترافیک و حداکثر ۵ Node فعال
- تب `PassWall2` برای خلاصه وضعیت، Profile فعال و بازکردن مستقیم پنل LuCI روتر
- تب انتخاب‌شده ذخیره می‌شود و دفعه بعد همان تب باز خواهد شد.

در ویجت‌ها، زمان `Updated` بزرگ‌تر و پررنگ‌تر نمایش داده می‌شود. اگر Refresh کامل به‌دلیل
تغییر Public IP انجام شده باشد، ویجت کامل عبارت `IP changed • Updated` و ویجت Compact
علامت `IP ↻` را همراه با همان زمان Refresh نمایش می‌دهند.

ویجت Full از عرض ۱۶۰dp و ارتفاع ۱۱۰dp تا ۷۲۰dp در هر دو جهت قابل Resize است. چیدمان
در اندازه‌های کوچک بخش‌های فرعی را خودکار جمع می‌کند تا اطلاعات اصلی بریده نشوند. نودها
دیگر به سه ردیف ثابت محدود نیستند؛ نودهای فعال تا سقف دقیق `expected_nodes` گزارش‌شده
توسط روتر در یک ListView نمایش داده می‌شوند و
در اندازه معمول دقیقاً سه ردیف دیده می‌شود و ردیف چهارم به بعد با اسکرول عمودی قابل مشاهده
است. در کوچک‌ترین ارتفاع ممکن، بخش نود موقتاً جمع می‌شود تا IP و Updated بریده نشوند.

## ویجت‌ها

### 1) Compact 4×2
برای صفحه اصلی و مصرف فضای کم:
- Public IP + پرچم کشور
- وضعیت Xray
- بهترین Node زنده + نام گروه Subscription + Ping
- Download / Upload
- دکمه ↻ برای Refresh فوری
- دکمه هوشمند Connect / Disconnect

### 2) Full Resizable (پیش‌فرض 4×4)
نسخه کامل شبیه داشبورد Proxy Monitor:
- تب مستقل `Monitor` و `PassWall2`
- Public IP + پرچم
- Xray و Sing-Box
- PassWall2 profile
- Download / Upload
- فقط Nodeهای Active تا سقف `expected_nodes` با نام گروه و Ping در لیست اسکرولی
- زمان آخرین Update
- دکمه ↻ Refresh
- دکمه‌های Connect و Disconnect روی خود ویجت
- دکمه `Open PassWall2 Panel` برای بازکردن مستقیم صفحه LuCI روتر

تب PassWall2 وضعیت Cacheشده هسته Xray، Profile و تعداد Nodeهای فعال را نشان می‌دهد.
صفحه کامل مدیریت PassWall2 با مرورگر باز می‌شود و ممکن است ورود LuCI لازم باشد. آدرس پنل
به‌صورت خودکار از IP و پورت Router API ساخته می‌شود.

## 1. نصب API روی OpenWrt
فایل زیر را از پوشه `openwrt/` با WinSCP داخل `/tmp/` روتر کپی کنید:

`install-proxy-monitor-mobile-api.sh`

سپس SSH:

```sh
chmod +x /tmp/install-proxy-monitor-mobile-api.sh
sh /tmp/install-proxy-monitor-mobile-api.sh
```

در پایان فقط URL چاپ می‌شود. نمونه:

```text
URL: http://192.168.28.1/cgi-bin/proxy-monitor-mobile
```

URL را در اپ ذخیره کنید؛ این نسخه توکن ندارد و فقط از شبکه داخلی روتر پاسخ می‌دهد.

API نسخه ۶ آخرین وضعیت را در RAM روتر نگه می‌دارد. درخواست معمولی سریع از Cache پاسخ
می‌گیرد، اما Refresh کامل برنامه با پارامتر `fresh=1` تا تولید وضعیت تازه صبر می‌کند.
این Refresh کامل فقط با دکمه `↻` یا بعد از تشخیص تغییر Public IP اجرا می‌شود و زمان انتظار
آن تا ۹۰ ثانیه است.

## اتصال دائمی و تشخیص تغییر IP

پس از وارد کردن URL فقط یک‌بار `Connect` را بزنید. وضعیت اتصال با یک Foreground Service
از نوع `connectedDevice` حتی پس از بسته‌شدن صفحه برنامه، حذف از Recent Apps یا راه‌اندازی
مجدد گوشی حفظ می‌شود. گزینه `Auto refresh when Public IP changes` به‌صورت پیش‌فرض روشن
است. برنامه هنگام اتصال، هر ۳۰ ثانیه فقط یک بررسی سبک IPv4 انجام می‌دهد؛ تا وقتی IP عوض
نشود هیچ Refresh کاملی از روتر انجام نمی‌شود. با تغییر IP، یک Refresh کامل اجرا شده و
برنامه و هر دو Widget به‌روز می‌شوند. این گزینه از داخل برنامه قابل خاموش‌کردن است و دکمه
`↻ Refresh` همچنان برای Refresh دستی باقی می‌ماند.

بررسی سبک IPv4 از آدرس HTTPS رسمی `https://api.ipify.org` انجام می‌شود و در صورت خطا
بی‌صدا تا نوبت بعدی صبر می‌کند؛ خطای این بررسی ارتباط برنامه با روتر را قطع نمی‌کند.

خطای Refresh اتصال را قطع نمی‌کند. اتصال با `Disconnect` یا هنگام قطع‌شدن Wi-Fi متوقف
می‌شود؛ روشن‌شدن دوباره Wi-Fi اتصال را خودکار برقرار نمی‌کند و باید خودتان Connect را بزنید.

در Android 13 و بالاتر هنگام اولین Connect اجازه اعلان درخواست می‌شود. اعلان دائمی شامل
دکمه‌های Refresh و Disconnect است.

## 2. ساخت APK در Android Studio
پوشه `ProxyMonitorAndroid` را به عنوان Project باز کنید، Gradle Sync را انجام دهید و سپس:

`Build > Build App Bundles or APKs > Build APKs`

تنظیم پروژه:
- minSdk 26
- targetSdk / compileSdk 36
- JDK 17

## 3. اضافه کردن Widget
بعد از نصب APK:

1. روی Home Screen گوشی نگه دارید.
2. Widgets را باز کنید.
3. `Proxy Monitor` را پیدا کنید.
4. یکی از این دو را اضافه کنید:
   - `Proxy Monitor • Compact 4×2`
   - `Proxy Monitor • Full Resizable`
5. در صورت نیاز اندازه Widget را Resize کنید.

## Refresh

- فشردن ↻ دقیقاً یک Refresh کامل از روتر اجرا می‌کند.
- پایش سبک IP هر ۳۰ ثانیه فقط در حالت Connected، روی Wi-Fi و با روشن‌بودن گزینه مربوطه است.
- بدون تغییر IP، داده کامل روتر دوباره خوانده نمی‌شود.
- پس از تغییر IP، نتیجه جدید در برنامه و هر دو Widget ذخیره و نمایش داده می‌شود.

برای این قابلیت نیازی به نصب مجدد API نسخه ۶ روی روتر نیست.

در نسخه ۲.۱۱ شمارش نودهای ویجت اصلاح شده است: اگر آرایه خام API رکوردهای اضافه داشته باشد
ولی `expected_nodes` مثلاً ۵ باشد، برنامه و ویجت فقط همان ۵ نود برتر را نمایش می‌دهند.

## نکته امنیتی
Endpoint بدون توکن و فقط برای IPهای خصوصی LAN فعال است. سرویس `uhttpd`/LuCI و این
Endpoint را روی WAN یا اینترنت منتشر نکنید.
