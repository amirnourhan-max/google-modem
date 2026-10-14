# تعمیر RPC و انتقال به Overview

مبدأ این تعمیر HEAD موجود `3e280bdba6c701aa897a8da06b0f9eb55750f2df` در شاخهٔ `proxy-monitor-luci-theme-lightweight-v15` است. main، v14.3، API6، Android و سرویس‌های اینترنت تغییر نکرده‌اند. Draft PR1 موجود به‌روز می‌شود؛ branch جدید یا merge ایجاد نمی‌شود.

## تشخیص با شواهد

روی روتر، installer اولیه با hash درست و syntax معتبر به `Command failed: Not found` و rollback رسیده بود. اجرای مستقیم staged exec-plugin با list فقط اعتبار فایل/خروجی را ثابت می‌کند؛ loader، شروع daemon، socket و registry را آزمایش نمی‌کند. پس از rollback نیز object جدید حذف شده و Not found انتظار می‌رود.

ایراد اثبات‌شدهٔ installer: بعد از `/etc/init.d/rpcd restart` بلافاصله RPC می‌خواست؛ procd restart تضمین آماده‌بودن daemon و pluginها نیست. آزمون قدیمی ubus را مستقیم به shell helper متصل می‌کرد و initialization/registration را دور می‌زد. آزمون تأخیر ثبت همین failure و false rollback را روی کد قدیمی بازتولید کرد.

بدون دسترسی به router log نمی‌توان تنها علت دستگاه را با قطعیت تعیین کرد. مسیر ثبت با native loader استاندارد نصب‌شده روی دستگاه جایگزین شده و readiness جدا بررسی می‌شود؛ مشکل واقعیِ باقی‌مانده مخفی نمی‌شود و به rollback می‌رسد.

## اصلاح

- plugin در `/usr/share/rpcd/ucode/proxy-monitor`، object صریح `proxy-monitor` و method فقط‌خواندنی `status` است. schema و callback پیش از deploy compile/validate می‌شوند. plugin اجرایی قبلی در `/usr/libexec/rpcd` از نصب جدید حذف، ولی در snapshot حفظ می‌شود.
- readiness با حداکثر۱۰ تلاش محدود، timeout۲ثانیه و فاصله۱ثانیه بررسی می‌شود؛ `backend_version15/rpc_backend:ucode/rpc_revision2` باید از **plugin جدید** برسد. وجود object قدیمی یا اجرای shell list به‌تنهایی قبول نیست.
- UCI با native cursor فقط خوانده می‌شود. call بازگشتی ubus به UCI همان rpcd حذف شد، چون callback هم‌زمان native می‌توانست daemon را قفل کند. درخواست procd.service.list حداکثر۱ثانیه timeout دارد و خطا به UNKNOWN می‌رسد.
- callback native هم‌زمان است؛ مسیر helper شامل خواندن محلی و یک درخواست محدود به procd است. daemon مستقل یا traffic collector ایجاد نمی‌شود.
- ACL فقط proxy-monitor.status را مجاز می‌کند؛ file.exec، command ورودی، listener یا WAN access اضافه نشده‌اند. fs/uci و rpcd-mod-ucode پیش‌نیازِ بررسی‌شدهٔ نصب‌اند.

## رابط

`view/status/include/00_proxy-monitor.js` از baseclass و قرارداد load/render/title استفاده می‌کند؛ sort استاندارد آن را قبل از `10_system.js` قرار می‌دهد. core فایل‌های LuCI و Overview تغییر نمی‌کنند. view/menu جداگانهٔ Services و include75 حذف می‌شوند؛ backup امکان برگشت دقیق دارد.

Overview صاحب polling است. include مستقل timer/poll.add ندارد؛ RPC cache و request coalescing دارد، حدود هر۳۰ثانیه درخواست می‌دهد و در tab hidden یا section collapsed درخواست تازه نمی‌فرستد. root DOM ثابت است و data کش‌شده render مجدد غیرضروری ندارد. Refresh دستی به‌صورت فوری و deduplicated کار می‌کند. Light/Dark، RTL، LTR مقادیر فنی و همهٔ وضعیت‌های قبلی حفظ شده‌اند؛ ترافیک/آپلود/دانلود/RxTx جمع‌آوری نمی‌شود.

## اعتبارسنجی و حدود آن

آزمون‌های filesystem/ucode: delayed registration، migration native plugin/Overview، نصب تکراری، snapshot rollback، failure واقعی نوشتن، restart failure و AndroidAPI7 shape/auth/LAN/GET/malformed. کد API7 و parser اندروید تغییر نکرده‌اند.

CI جدید actual ubusd، rpcd+rpcd-mod-ucode، libuci و ucode را از منابع pinned می‌سازد. آزمون مستقیم list معتبر ولی registry مفقود، reload واقعی، status روی socket واقعی، schema، پنج call پیاپی بدون بن‌بست UCI، anonymous ACL denial و plugin خراب بررسی می‌شوند. daemon/loader logic mock نیست؛ فقط filesystem constants به prefix خصوصی تست منتقل شده‌اند. این تست Linux است، نه firmware کامل ARM/procd روی دستگاه.

مرورگر fixture جدید، **کد اصلی و تغییرنکردهٔ host Overview** را با include واقعی اجرا می‌کند؛ صرفاً RPC/دادهٔ System و helperهای عمومی DOM fixture هستند. ترتیب بالای System، یک host poll، gate۳۰ثانیه، hidden/collapsed، DOM ثابت، Refresh، Light/Dark، RTL و عرض‌های۳۶۰/۷۶۸/۱۳۶۶ و fallback آزمایش می‌شوند. نتیجه و شواهد اجرای نهایی در PR و تحویل ثبت می‌شود.

اجرای [38623021287](https://github.com/amirnourhan-max/google-modem/actions/runs/38623021287) تمام۲۵آزمون و browser را پاس کرد، از جمله دو آزمون واقعی loader/daemon که در CI skip نشدند. هنگام بازبینی تصاویر، frame میانی fade-in استاندارد Overview دیده شد؛ آزمون عکس به انتظار پایان animation و بررسی opacity نهایی ارتقا یافت تا شواهد تصویری حالت settled را نشان دهند. contrast متن پایه۱۰٫۳۷در Light و۸٫۶۵در Dark است؛ نسخهٔ نهایی شواهد و اجرای نهایی در PR ثبت می‌شود.

اجرای [38623703561 — Success](https://github.com/amirnourhan-max/google-modem/actions/runs/38623703561) نیز همهٔ۲۵آزمون و renderer را پاس کرد؛ opacity نهایی در هر۶حالت۱ است. تصاویر جدید در `tests/proxy-monitor/evidence/` حفظ و Light desktop و Dark mobile بصری بررسی شدند؛ Proxy Monitor پیش از System دیده می‌شود و overlap/overflow مشاهده نشد. فایل installer مستقل با SHA256 در کنار آن تحویل شده است: `cb4404f5556276f86ca20c5408839b027b37b916278d2ec04f6483c1e95e4231`.

محیط Work ساخت daemonها و خواندن native UCI را انجام داد؛ اجرای socket Unix محلی با Operation not permitted مسدود بود، بنابراین آزمون daemon باید در runner CI اجرا شود و نتیجهٔ skip محلی به‌عنوان pass معرفی نمی‌شود.

**Router deployment: NOT VERIFIED.** هیچ نصب روی روتر از Work تأیید نشده است. snapshotهای دو نصب شکست‌خوردهٔ کاربر باید حفظ شوند. مسیر انتقال/hash/install/rollback در installation-fa.md و دستور کار محلی در deployment-local-codex-fa.md است. Xray/Passwall2/DNS/Watchdog/LED/Wi-Fi/LAN/WAN/firewall تغییر یا restart نمی‌شوند؛ فقط rpcd refresh می‌شود.
