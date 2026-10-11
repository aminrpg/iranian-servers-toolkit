<div align="center">

# 🇮🇷 جعبه‌ابزار سرورهای ایران

**یک اسکریپت تعاملی Bash که تغییر DNS و راه‌اندازی Docker را روی سرورهای ایرانی ساده می‌کند.**

وضعیت سیستم را ببینید، DNS را عوض کنید، Docker را نصب یا به‌روزرسانی کنید و آن را به یک میرور سریع ایرانی وصل کنید — همه از یک منوی ساده‌ی ترمینال، بدون ویرایش دستی فایل‌های پیکربندی.

**🌐 زبان‌ها:** [English](./README.md) · فارسی (همین صفحه)

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](./LICENSE)
![Platform](https://img.shields.io/badge/platform-Linux-blue.svg)
![Distros](https://img.shields.io/badge/distros-apt%20%7C%20dnf%20%7C%20yum%20%7C%20pacman%20%7C%20zypper-informational.svg)
![Language](https://img.shields.io/badge/made%20with-Bash-121011.svg?logo=gnu-bash&logoColor=white)
![Root](https://img.shields.io/badge/requires-root-red.svg)

</div>

---

<div dir="rtl">

## 📖 چرا این ابزار؟

کار با Docker روی سرورهای میزبانی‌شده در ایران دردسر دارد: Docker Hub اغلب در دسترس نیست و `docker pull` یا گیر می‌کند یا شکست می‌خورد. راه‌حل‌های معمول، تغییر DNS به یک ریزالور بدون تحریم و/یا اتصال Docker به یک میرور محلی است — اما انجام دستی این کارها یعنی ویرایش `/etc/resolv.conf` و `/etc/docker/daemon.json`، ری‌استارت سرویس‌ها و به‌خاطر سپردن چند ده آدرس IP.

این اسکریپت همه‌ی این‌ها را در یک منو جمع کرده است. یک گزینه را انتخاب کنید و ویرایش فایل‌ها، پشتیبان‌گیری و ری‌استارت سرویس‌ها خودکار انجام می‌شود.

## ✨ امکانات

- 📊 **داشبورد وضعیت** — سیستم‌عامل، پکیج‌منیجر، DNS فعلی، نسخه‌ی Docker و بیشتر را یکجا ببینید. هر پروکسی Docker یا رجیستری پکیجی که تغییر کرده باشد با رنگ متمایز مشخص می‌شود تا فوری بدانید چه چیزی از حالت پیش‌فرض عوض شده است.
- 🌐 **تغییر سریع DNS** — جابه‌جایی بین ۱۲ ریزالور محبوب (شکن، رادار، الکترو، بگذر، Google، Cloudflare و بیشتر).
- 💾 **پشتیبان‌گیری خودکار DNS** — پیش از هر تغییر، یک نسخه‌ی زمان‌دار از `/etc/resolv.conf` ذخیره می‌شود.
- ⏪ **بازگردانی از پشتیبان** — پشتیبان‌های ذخیره‌شده را مرور کنید و در یک مرحله به هرکدام برگردید.
- 🐧 **پشتیبانی چند-توزیعه** — تشخیص خودکار `apt`، `dnf`، `yum`، `pacman` یا `zypper`.
- 🐳 **نصب/به‌روزرسانی Docker با یک فرمان** — به‌روزرسانی پکیج‌ها، نصب پیش‌نیازها و اجرای اسکریپت رسمی Docker.
- 🪞 **میرورهای ایرانی رجیستری Docker** — دریافت ایمیج از ۱۵ میرور محلی، با گزینه‌ی حذف دوباره.
- ⚡ **انتخاب خودکار سریع‌ترین میرور** — بنچمارک همه‌ی میرورها با `ping` و انتخاب کم‌تأخیرترین.
- 🩺 **تست سلامت میرور** — بررسی تأخیر، دسترس‌پذیری HTTP و یک pull واقعی برای میرور تنظیم‌شده.
- 🧩 **نصب Docker Compose** — نصب یا به‌روزرسانی افزونه‌ی Compose در یک مرحله.
- 📦 **میرورهای رجیستری پکیج‌ها** — تنظیم **APT، DNF/YUM، Pacman، npm، Yarn، pip، Composer، Go، NuGet و Maven/Gradle** روی میرورهای سریع ایرانی (پیکربندی هر کاربر در خانه‌ی خودش قرار می‌گیرد، نه root).
- 🐙 **پروکسی گیت‌هاب** — عبور `git clone`/fetch از یک پروکسی گیت‌هاب ایرانی وقتی گیت‌هاب کند یا مسدود است (برگشت‌پذیر، با `insteadOf` گیت).
- 🧰 **جعبه‌ابزار راه‌اندازی سرور** — یکجا برای کارهای همیشگی هر VPS تازه‌ی ایرانی: Timezone تهران + NTP ایرانی، فایل Swap، سخت‌سازی SSH، فایروال، پکیج‌های پایه و به‌روزرسانی کامل سیستم.
- 🧪 **دکتر اتصال** — یک بررسی که Docker Hub، GitHub، npm، PyPI و Google را آزمایش می‌کند و بلاک‌های تحریمی `403` را مشخص می‌کند.
- 📡 **بنچمارک DNS** — پینگ همه‌ی ریزالورها، تست توانایی resolve کردن Docker Hub و پیشنهاد سریع‌ترین گزینه‌ی سالم.
- 🗂️ **زیرمنوهای مرتب** — دسته‌بندی تمیز (DNS، Docker، رجیستری پکیج‌ها، تشخیص) به‌جای یک فهرست بلند.
- 🔁 **ری‌استارت خودکار سرویس** — اعمال پیکربندی میرور و ری‌استارت دیمن Docker به‌صورت خودکار.
- 🛡️ **ایمن از پایه** — بدون root اجرا نمی‌شود، هر انتخاب منو را اعتبارسنجی می‌کند و پیش از هر تغییر پشتیبان می‌گیرد.

</div>

<div dir="rtl">

## 🚀 شروع سریع

</div>

```bash
# ۱. کلون کردن مخزن
git clone https://github.com/aminrpg/iranian-servers-toolkit.git
cd iranian-servers-toolkit

# ۲. اجرایی‌کردن اسکریپت
chmod +x start.sh

# ۳. اجرا با دسترسی root
sudo ./start.sh
```

<div dir="rtl">

> **نکته:** اسکریپت باید با دسترسی root (با `sudo`) اجرا شود، چون فایل‌های سیستمی (`/etc/resolv.conf`، `/etc/docker/daemon.json`، `/etc/apt/sources.list`) را ویرایش و سرویس Docker را ری‌استارت می‌کند. اگر با کاربر عادی اجرا شود بلافاصله خارج می‌شود.
>
> ابزارهای مخصوص هر کاربر (npm، Yarn، pip) در خانه‌ی **کاربر فراخوان** نوشته می‌شوند — که از طریق `$SUDO_USER` تشخیص داده می‌شود — تا پیکربندی‌ها متعلق به root در مسیر `/root` نباشند.

### اجرای مستقیم (یک خطی)

اگر فقط می‌خواهید بدون نگه‌داشتن مخزن اجرا کنید:

</div>

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/aminrpg/iranian-servers-toolkit/master/start.sh)"
```

<div dir="rtl">

## 🧭 ساختار منو

ابزار به یک منوی اصلی با زیرمنوهای دسته‌بندی‌شده تقسیم شده است:

</div>

```
===== Iranian Servers Toolkit =====
  1) Show Status
  2) DNS Tools
  3) Docker Tools
  4) Package Registries
  5) Server Setup
  6) Diagnostics
  0) Exit
```

<div dir="rtl">

> برای خروج **`0`** را بزنید. اسکریپت یک پیام خداحافظی کوتاه (نام ابزار + سازنده) چاپ می‌کند و با وضعیت `0` (خروج موفق) بسته می‌شود.

### ۱ · نمایش وضعیت (Show Status)
یک داشبورد یک‌صفحه‌ای: سیستم‌عامل، پکیج‌منیجر، کرنل، DNSهای فعلی، تعداد پشتیبان‌های DNS و نسخه‌ی Docker. همچنین وضعیت **پروکسی Docker** و هر **رجیستری پکیجی** (npm، pip، Maven، Composer، Go، NuGet، پروکسی گیت‌هاب و پکیج‌منیجر سیستم) را نشان می‌دهد — هر موردی که از پیش‌فرض تغییر کرده باشد با برچسب `CHANGED` و رنگ متمایز مشخص می‌شود تا یک‌نگاهه ببینید چه چیزی عوض شده است. اگر چیزی تغییر نکرده باشد، همان را اعلام می‌کند.

### ۲ · ابزارهای DNS

| گزینه | کارکرد |
|--------|--------------|
| **Set DNS** | یک ارائه‌دهنده انتخاب کنید؛ `/etc/resolv.conf` پشتیبان‌گیری و بازنویسی می‌شود. |
| **Restore DNS Backup** | فهرست پشتیبان‌های `/etc/resolv.conf.bak.*` (با زمان) و بازگردانی هرکدام. |
| **DNS Benchmark** | پینگ همه‌ی ریزالورها، تست resolve شدن `registry-1.docker.io` و پیشنهاد سریع‌ترین. |

### ۳ · ابزارهای Docker

| گزینه | کارکرد |
|--------|--------------|
| **Install Docker** | به‌روزرسانی پکیج‌ها، نصب `curl` و سپس نصب Docker از `get.docker.com`. اگر نصب باشد رد می‌شود. |
| **Update Docker** | اجرای دوباره‌ی نصب‌کننده‌ی رسمی برای به‌روزرسانی Docker. |
| **Set Docker Proxy** | انتخاب میرور (یا انتخاب خودکار سریع‌ترین)، نوشتن `/etc/docker/daemon.json` و ری‌استارت Docker. |
| **Reset Docker Proxy** | حذف میرور از `daemon.json` (با پشتیبان‌گیری) و ری‌استارت Docker. |
| **Test Mirror Health** | گزارش تأخیر، دسترس‌پذیری HTTP و یک pull واقعی `hello-world` برای میرور تنظیم‌شده. |
| **Install Docker Compose** | نصب یا به‌روزرسانی `docker-compose-plugin`. |

### ۴ · رجیستری پکیج‌ها

| گزینه | کارکرد |
|--------|--------------|
| **Set APT Mirror** | بازنویسی `sources.list` به یک میرور ایرانی (ArvanCloud، IranServer، Pardisco، آرشیو Ubuntu IR) با پشتیبان‌گیری. |
| **Set DNF/YUM Mirror** | تغییر `baseurl` مخازن فدورا/راکی/CentOS به یک میرور ایرانی (ابتدا پشتیبان `/etc/yum.repos.d`). |
| **Set Pacman Mirror** | افزودن خط `Server` ایرانی به ابتدای `/etc/pacman.d/mirrorlist` در آرچ/منجارو با پشتیبان‌گیری. |
| **Set npm Registry** | تنظیم رجیستری npm روی یک میرور ایرانی (با `npm config` یا `~/.npmrc`). |
| **Set pip (PyPI) Mirror** | نوشتن `~/.config/pip/pip.conf` با `index-url` ایرانی و `trusted-host`. |
| **Set Yarn Registry** | تنظیم رجیستری Yarn روی یک میرور ایرانی (از همان فهرست npm). |
| **Set Composer Mirror** | اتصال مخزن Packagist در Composer (PHP) به یک میرور ایرانی (با `composer config -g`). |
| **Set Go Proxy (GOPROXY)** | تنظیم `GOPROXY` روی یک پروکسی ماژول ایرانی با `go env -w` (با حفظ `,direct`). |
| **Set NuGet Mirror** | افزودن یک source دات‌نت با نام `iran-mirror` از طریق `dotnet nuget add source`. |
| **Set Maven Mirror** | نوشتن یک `<mirror>` در `~/.m2/settings.xml` برای Maven/Gradle با پشتیبان‌گیری. |
| **Set GitHub Proxy** | عبور `git clone`/fetch از یک پروکسی گیت‌هاب ایرانی با `insteadOf` گیت (کاملاً برگشت‌پذیر). |

### ۵ · راه‌اندازی سرور (Server Setup)

کارهای رایج اولین اجرای یک سرور تازه. گزینه‌های پرخطرتر قبل از اعمال تأیید می‌گیرند و از هر فایلی که تغییر می‌دهند پشتیبان می‌سازند.

| گزینه | کارکرد |
|--------|--------------|
| **Set Timezone & NTP (Tehran)** | تنظیم منطقه‌ی زمانی روی `Asia/Tehran` و اتصال همگام‌سازی ساعت به سرورهای NTP ایرانی (`ntp.day.ir`، `ir.pool.ntp.org`). |
| **Create / Enable Swap** | ساخت فایل swap به اندازه‌ی دلخواه، فعال‌سازی آن و پایدارسازی در `/etc/fstab` (ابتدا پشتیبان fstab گرفته می‌شود). |
| **Harden SSH** | به‌صورت اختیاری: تغییر پورت SSH، افزودن کلید عمومی و غیرفعال‌کردن ورود با پسورد — همراه با هشدار قفل‌شدن، تست پیکربندی (`sshd -t`) و پشتیبان‌گیری/بازگردانی خودکار. |
| **Setup Firewall** | پیکربندی UFW (دبیان/اوبونتو) یا firewalld (خانواده‌ی RHEL) برای اجازه‌ی SSH/HTTP/HTTPS و فعال‌سازی آن؛ در نبود فایروال، نصب UFW را پیشنهاد می‌دهد. |
| **Install Base Packages** | نصب ابزارهای پرکاربرد: `curl wget git vim htop unzip ca-certificates nano net-tools`. |
| **Full System Update** | به‌روزرسانی فهرست پکیج‌ها و ارتقای همه‌ی پکیج‌های نصب‌شده با پکیج‌منیجر تشخیص‌داده‌شده. |

> ⚠️ گزینه‌های **Harden SSH** و **Setup Firewall** تنظیمات دسترسی از راه دور را تغییر می‌دهند. نشست SSH فعلی را باز نگه دارید و پیش از بستن آن یک اتصال **تازه** را تست کنید — و قبل از جابه‌جایی، پورت جدید SSH را در فایروال باز کنید.

### ۶ · تشخیص (Diagnostics)

| گزینه | کارکرد |
|--------|--------------|
| **Connectivity Doctor** | بررسی Docker Hub، GitHub، npm، PyPI، Google و `get.docker.com`؛ تشخیص بلاک `403` از عدم دسترسی. |
| **DNS Benchmark** | همان بنچمارک ریزالور که در ابزارهای DNS موجود است. |
| **Test Docker Mirror Health** | همان تست سلامت میرور که در ابزارهای Docker موجود است. |

</div>

<div dir="rtl">

## 🌐 ارائه‌دهندگان DNS پشتیبانی‌شده

ریزالورهای «هوشمند» ایرانی بسیاری از سرویس‌های توسعه‌دهندگان (Docker Hub، npm، Google و…) را باز می‌کنند. از منوی **Set DNS** هرکدام را انتخاب کنید:

</div>

| Provider | Nameservers |
|----------|-------------|
| Shecan | `178.22.122.100`, `185.51.200.2` |
| Shecan Pro | `178.22.122.101`, `185.51.200.1` |
| Radar | `10.202.10.10`, `10.202.10.11` |
| Electro | `78.157.42.100`, `78.157.42.101` |
| Begzar | `185.55.226.26`, `185.55.226.25` |
| DNSPro | `87.107.110.109`, `87.107.110.110` |
| 403 | `10.202.10.202`, `10.202.10.102` |
| XCR9 | `85.208.255.182`, `85.208.255.71` |
| Bertina | `193.186.32.32` |
| DynX | `10.70.95.150`, `10.70.95.162` |
| Google | `8.8.8.8`, `8.8.4.4` |
| Cloudflare | `1.1.1.1`, `1.0.0.1` |
| **Reset to Default** | بازگردانی `127.0.0.53` (systemd-resolved) |

<div dir="rtl">

> پیش از هر تغییر، فایل فعلی `/etc/resolv.conf` در مسیر `/etc/resolv.conf.bak.YYYYMMDD_HHMMSS` کپی می‌شود تا همیشه قابل بازگردانی باشد.

</div>

<div dir="rtl">

## 🪞 میرورهای رجیستری Docker پشتیبانی‌شده

وقتی Docker Hub کند یا مسدود است، این میرورهای ایرانی دریافت ایمیج را واسطه می‌کنند. یکی را از منوی **Set Docker Proxy** انتخاب کنید یا بگذارید اسکریپت همه را بنچمارک کند و سریع‌ترین را بردارد:

</div>

| Mirror | Mirror |
|--------|--------|
| `docker.kernel.ir` | `hub.mecan.ir` |
| `focker.ir` | `docker.nrp.co` |
| `registry.docker.ir` | `docker-mirror.liara.ir` |
| `docker.arvancloud.ir` | `ghcr-mirror.liara.ir` |
| `docker.haiocloud.com` | `mirrors.pardisco.co` |
| `docker.iranserver.com` | `mirror2.chabokan.net` |
| `docker.mobinhost.com` | `docker.abrha.net` |
| | `mirror-docker.runflare.com` |

<div dir="rtl">

⚡ **انتخاب خودکار سریع‌ترین میرور** — در منوی میرور گزینه‌ی `00` را بزنید. اسکریپت هر میرور را سه بار `ping` می‌کند، تأخیر هرکدام را گزارش می‌دهد و کم‌تأخیرترین را تنظیم می‌کند.

میرور انتخاب‌شده این‌گونه در `/etc/docker/daemon.json` نوشته می‌شود:

</div>

```json
{
  "registry-mirrors": ["https://docker.arvancloud.ir"]
}
```

<div dir="rtl">

سپس Docker به‌صورت خودکار با `systemctl restart docker` ری‌استارت می‌شود تا تغییر اعمال شود.

## 📦 میرورهای رجیستری پکیج پشتیبانی‌شده

در منوی **Package Registries**. هر گزینه پیش از تغییر پشتیبان می‌گیرد و هر فهرست یک گزینه‌ی **Reset to Official** برای بازگشت دارد.

| ابزار | میرورهای ارائه‌شده | فایل تغییریافته |
|------|-----------------|----------------|
| **APT** | ArvanCloud، IranServer، Pardisco، آرشیو Ubuntu IR | `/etc/apt/sources.list` (یا `ubuntu.sources`) |
| **DNF/YUM** | ArvanCloud، IUT، Zero-One Cloud | `/etc/yum.repos.d/*.repo` |
| **Pacman** | ArvanCloud، IUT، Zero-One Cloud | `/etc/pacman.d/mirrorlist` |
| **npm** | Runflare، Kargadan | `npm config` / `~/.npmrc` |
| **Yarn** | Runflare، Kargadan | `yarn config` |
| **pip** | Runflare، Kargadan، ArvanCloud | `~/.config/pip/pip.conf` |
| **Composer** | Liara، Kargadan | `composer config -g` |
| **Go** | Liara، Kargadan | `go env -w GOPROXY` |
| **NuGet** | Kargadan، Pardisco | source دات‌نت با نام `iran-mirror` |
| **Maven/Gradle** | Myket، Kargadan | `~/.m2/settings.xml` |
| **GitHub** | IranGit، theazizi | گیت `url.<proxy>.insteadOf` (پیکربندی کاربر) |

> نام میزبان میرورها از پروژه‌ی جامعه‌محور [Mirava](https://github.com/MiravaOrg/Mirava) گرفته شده است. اگر ابزار مربوط (`composer`، `go`، `dotnet` و…) نصب نباشد یا سیستم توزیع متناظر نباشد، آن گزینه به‌آرامی رد می‌شود. برای تغییر یا افزودن میرور، آرایه‌های بالای `start.sh` را ویرایش کنید — به [راهنمای مشارکت](./CONTRIBUTING.fa.md) نگاه کنید.

## 🩺 تشخیص

- **دکتر اتصال** — به هر نقطه‌ی کلیدی یک `curl` با تایم‌اوت کوتاه می‌زند و نتیجه را دسته‌بندی می‌کند: `OK`، `reachable (401)`، `HTTP 403 (likely sanction block)` یا `unreachable / blocked`.
- **بنچمارک DNS** — سرور اصلی هر ریزالور را پینگ می‌کند و با `nslookup`/`dig` بررسی می‌کند که آیا `registry-1.docker.io` را resolve می‌کند، سپس سریع‌ترین گزینه‌ی سالم را پیشنهاد می‌دهد.
- **تست سلامت میرور** — بررسی می‌کند میروری که از قبل تنظیم کرده‌اید واقعاً سرتاسر کار می‌کند (تأخیر + HTTP + یک pull واقعی).

</div>

<div dir="rtl">

## ✅ پیش‌نیازها

- یک توزیع لینوکس با یکی از این پکیج‌منیجرها: **apt** (دبیان/اوبونتو)، **dnf**/**yum** (فدورا/RHEL/CentOS)، **pacman** (آرچ) یا **zypper** (openSUSE).
- وجود `systemd` (`systemctl`) برای مرحله‌ی ری‌استارت سرویس Docker.
- دسترسی **root** (`sudo`).
- در دسترس بودن `curl`، `ping` و `awk` (اسکریپت در صورت نبود `curl` آن را خودکار نصب می‌کند).
- **Bash نسخه‌ی ۴٫۳ به بالا** (برای انتخابگر رجیستری‌ها). روی همه‌ی سرورهای مدرن لینوکس استاندارد است.
- **اختیاری:** `jq` (ریست تمیزتر پراکسی Docker)، `nslookup` یا `dig` (تست resolve در بنچمارک DNS) و ابزار مربوط به هر رجیستری (`npm`، `yarn`، `pip`، `composer`، `go`، `dotnet`، `mvn`). اسکریپت هر گزینه‌ای که ابزارش نصب نباشد را رد می‌کند.

> نصب‌کننده‌ی رسمی `get.docker.com` از توزیع‌های اصلی بالا پشتیبانی می‌کند. روی توزیع پشتیبانی‌نشده، اسکریپت اطلاع می‌دهد و نصب را رد می‌کند.

## 🩺 عیب‌یابی

- **«Please run this script as root»** — دوباره با `sudo ./start.sh` اجرا کنید.
- **تغییر DNS اعمال نماند** — برخی سیستم‌ها `/etc/resolv.conf` را با `systemd-resolved` یا NetworkManager مدیریت می‌کنند و ممکن است بازنویسی کنند. در صورت نیاز از `/etc/resolv.conf.bak.*` بازگردانی کنید.
- **Docker بعد از تنظیم میرور ری‌استارت نشد** — دستی `sudo systemctl restart docker` را اجرا و با `sudo journalctl -u docker` خطاها را بررسی کنید.
- **همه‌ی میرورها در انتخاب خودکار تایم‌اوت می‌دهند** — شبکه‌ی شما ممکن است ICMP (`ping`) را مسدود کند؛ میرور را دستی انتخاب کنید.

## 🤝 مشارکت

مشارکت‌ها بسیار استقبال می‌شوند — یک ریزالور DNS تازه، یک میرور سریع‌تر، رفع باگ یا بهبود مستندات. راهنمای کامل در **[CONTRIBUTING.fa.md](./CONTRIBUTING.fa.md)** آمده است.

باگ‌ها و درخواست امکانات را از طریق [issue tracker](https://github.com/aminrpg/iranian-servers-toolkit/issues) گزارش کنید.

## 🙏 قدردانی

- نام میزبان میرورهای رجیستری پکیج و APT از پروژه‌ی جامعه‌محور [**Mirava**](https://github.com/MiravaOrg/Mirava) گرفته شده است.
- نصب Docker از اسکریپت رسمی [get.docker.com](https://get.docker.com) استفاده می‌کند.

## 📜 مجوز

تحت **مجوز MIT** منتشر شده — رایگان برای استفاده‌ی شخصی و تجاری. متن کامل در [`LICENSE`](./LICENSE).

## 👤 سازنده

ساخته‌شده با ❤️ توسط **امین سپهری**

- 📍 موقعیت: تهران، ایران
- 🌐 وب‌سایت: [AminSepehri.com](http://AminSepehri.com)

## 📬 ارتباط

| پلتفرم | لینک |
|----------|------|
| 🐙 GitHub | [@aminrpg](https://github.com/aminrpg) |
| 🐦 X / Twitter | [@AMIN_RPG](https://twitter.com/AMIN_RPG) |
| 🌐 وب‌سایت | [AminSepehri.com](http://AminSepehri.com) |

</div>

---

<div align="center">

⭐ **اگر این ابزار دردسرتان را کم کرد، به مخزن یک ستاره بدهید!** ⭐

</div>
