# Google Modem Repository Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** آخرین نسخه‌های Proxy Monitor Android، اسکریپت‌های OpenWrt و اصلاح PassWall2 را در ریپوی `amirnourhan-max/google-modem` مرتب و قابل نصب منتشر کند.

**Architecture:** ریپو به‌صورت monorepo سبک چیده می‌شود: سورس Android در `android/`، اسکریپت‌های روتر در `openwrt/`، مستندات در `docs/` و APK آماده در `releases/`. فایل‌های حساس، کلید امضا و تنظیمات شخصی خارج از ریپو نگه داشته می‌شوند.

**Tech Stack:** Kotlin/Android Gradle، Shell/OpenWrt، LuCI/PassWall2، GitHub repository.

**Spec:** درخواست کاربر برای مرتب‌سازی آخرین نسخه برنامه‌ها و قراردادن آن‌ها در ریپوی جدید `google-modem`.

## Global Constraints

- از آخرین نسخه Android یعنی `ProxyMonitorAndroid v2.11` استفاده شود.
- از آخرین پنل روتر یعنی `install-proxy-monitor-v14.3.sh` استفاده شود.
- از آخرین API موبایل یعنی `install-proxy-monitor-mobile-api-v6-manual-refresh.sh` استفاده شود.
- اصلاح PassWall2 با `fix-passwall2-subscribe-set.sh` وارد شود.
- هیچ کلید امضا، رمز، Subscription URL یا تنظیم شخصی در ریپو commit نشود.
- ریپو private موجود `amirnourhan-max/google-modem` هدف انتشار است.

---

### Task 1: Recover final project files

**Files:**
- Materialize: `ProxyMonitorAndroid-v2.11-active-node-count-fix-source.zip`
- Materialize: `install-proxy-monitor-v14.3.sh`
- Materialize: `install-proxy-monitor-mobile-api-v6-manual-refresh.sh`
- Materialize: `fix-passwall2-subscribe-set.sh`

**Interfaces:**
- Consumes: final saved project artifacts.
- Produces: local source files ready for repository layout.

- [x] Resolve exact latest filenames.
- [x] Materialize selected files.
- [x] Extract Android source ZIP.
- [x] Verify expected top-level project files are present.

### Task 2: Create repository layout

**Files:**
- Create: `README.md`
- Create: `CHANGELOG.md`
- Create: `.gitignore`
- Create: `docs/installation-fa.md`
- Create: `docs/compatibility.md`
- Create: `docs/sources.md`
- Create: `docs/superpowers/plans/2026-09-03-google-modem-repository.md`
- Copy: `android/proxy-monitor/`
- Copy: `openwrt/proxy-monitor/install-proxy-monitor-v14.3.sh`
- Copy: `openwrt/mobile-api/install-proxy-monitor-mobile-api-v6-manual-refresh.sh`
- Copy: `openwrt/passwall2-fix/fix-passwall2-subscribe-set.sh`
- Copy: `releases/ProxyMonitorAndroid-v2.11.apk`

**Interfaces:**
- Consumes: materialized source files.
- Produces: final local monorepo tree.

- [x] Create root directories.
- [x] Copy Android source under `android/proxy-monitor/`.
- [x] Copy OpenWrt and PassWall2 scripts under `openwrt/`.
- [x] Add docs and root metadata.

### Task 3: Validate and scan

**Files:**
- Inspect: all tracked files under `google-modem/`

**Interfaces:**
- Consumes: local repository tree.
- Produces: verification result and list of tracked files.

- [ ] Run shell syntax checks on installer scripts.
- [ ] Inspect Android Gradle structure.
- [ ] Scan for obvious secrets and personal config values.
- [ ] Initialize local git repository and commit.

### Task 4: Publish to GitHub

**Files:**
- Publish: repository contents to `amirnourhan-max/google-modem`

**Interfaces:**
- Consumes: validated local git tree.
- Produces: GitHub commit on `main`.

- [ ] Confirm GitHub repository exists and user has push permission.
- [ ] Create blobs/tree/commit or use authenticated git push.
- [ ] Update `main` to new commit without force.
- [ ] Verify repository compare/status after publish.

