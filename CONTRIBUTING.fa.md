<div dir="rtl">

# مشارکت در جعبه‌ابزار سرورهای ایران

مشارکت‌ها بسیار استقبال می‌شوند — یک ریزالور DNS تازه، یک میرور سریع‌تر، رفع باگ یا بهبود مستندات. ممنون که به بهتر شدن این ابزار کمک می‌کنید.

> 🌐 راهنما به انگلیسی: [CONTRIBUTING.md](./CONTRIBUTING.md)

## راه‌های مشارکت

- افزودن یک ارائه‌دهنده‌ی DNS، میرور رجیستری Docker یا میرور رجیستری پکیج.
- رفع باگ یا بهبود مدیریت خطا در [`start.sh`](./start.sh).
- بهبود مستندات (انگلیسی یا فارسی).
- گزارش باگ یا درخواست امکانات از طریق [issue tracker](https://github.com/aminrpg/iranian-servers-toolkit/issues).

</div>

<div dir="rtl">

## ۱. فورک و کلون

</div>

```bash
# ابتدا در GitHub فورک کنید، سپس:
git clone https://github.com/<your-username>/iranian-servers-toolkit.git
cd iranian-servers-toolkit
git checkout -b my-feature
```

<div dir="rtl">

## ۲. تغییر خود را اعمال کنید

کل پروژه یک فایل است: [`start.sh`](./start.sh). رایج‌ترین مشارکت‌ها افزودن یک ارائه‌دهنده‌ی DNS یا یک میرور است.

**افزودن ارائه‌دهنده‌ی DNS** — آن را هم به فهرست `dns_options` و هم به نگاشت `dns_servers` اضافه کنید:

</div>

```bash
# ۱) افزودن نام نمایشی به فهرست گزینه‌ها
dns_options=( ... "YourProvider" "Reset to Default")

# ۲) افزودن نیم‌سرورها به آرایه‌ی انجمنی
declare -A dns_servers=(
    ...
    ["YourProvider"]="1.2.3.4 5.6.7.8"
)
```

<div dir="rtl">

**افزودن میرور رجیستری Docker** — نام میزبان را (بدون `https://`) به آرایه‌ی `registry_proxies` اضافه کنید:

</div>

```bash
registry_proxies=(
    ...
    "mirror.example.ir"
)
```

<div dir="rtl">

**افزودن میرور رجیستری پکیج** — یک نام نمایشی به فهرست گزینه‌های مربوط و URL/host آن را به نگاشت مربوط (نزدیک بالای اسکریپت) اضافه کنید:

</div>

```bash
# APT (فقط host)
apt_mirror_options=( ... "YourMirror" "Reset to Official")
declare -A apt_mirror_hosts=( ... ["YourMirror"]="mirror.example.ir" )

# npm / Yarn (URL کامل)
npm_registry_options=( ... "YourMirror" "Reset to Official")
declare -A npm_registry_urls=( ... ["YourMirror"]="https://npm.example.ir/" )

# pip (URL کامل index که به /simple ختم می‌شود)
pip_index_options=( ... "YourMirror" "Reset to Official")
declare -A pip_index_urls=( ... ["YourMirror"]="https://pypi.example.ir/simple" )

# Composer / Go / NuGet / Maven (URL کامل) — همان الگوی فهرست گزینه + نگاشت:
#   composer_options / composer_urls
#   go_proxy_options / go_proxy_urls
#   nuget_options    / nuget_urls         (URL ایندکس v3 که به /index.json ختم می‌شود)
#   maven_options    / maven_urls         (URL پایه‌ی مخزن)

# پکیج‌منیجرهای سیستمی غیر از apt + پروکسی گیت‌هاب:
#   dnf_mirror_options    / dnf_mirror_hosts     (فقط host؛ فدورا/راکی/CentOS)
#   pacman_mirror_options / pacman_mirror_urls   (URL کامل Server= با $repo/$arch)
#   github_proxy_options  / github_proxy_urls    (پیشوند پروکسی که به /https://github.com/ ختم می‌شود)
```

<div dir="rtl">

> میرورهایی را ترجیح دهید که داخل ایران میزبانی می‌شوند و بدون VPN در دسترس‌اند. منبع خوبی برای گزینه‌ها فهرست [Mirava](https://github.com/MiravaOrg/Mirava) است.

## ۳. تست کنید

پیش از باز کردن PR مطمئن شوید اسکریپت اجرا می‌شود و تغییر شما نمایش داده و اعمال می‌شود:

</div>

```bash
# بررسی سینتکس (سریع، بدون نیاز به root)
bash -n start.sh

# بررسی مشکلات شل (نصب با: apt-get install shellcheck)
shellcheck start.sh

# اجرا و بررسی دستی نمایش و اعمال درست گزینه‌ی جدید
sudo ./start.sh
```

<div dir="rtl">

لطفاً این موارد را بررسی کنید:

- اسکریپت بدون خطای سینتکس اجرا می‌شود (`bash -n start.sh`).
- گزینه‌ی جدید در زیرمنوی درست ظاهر و درست اعمال می‌شود.
- هر گزینه‌ی جدید کلیدی متناظر در **هر دو** فهرست گزینه و نگاشت دارد (مثلاً `dns_options` + `dns_servers`، یا `apt_mirror_options` + `apt_mirror_hosts`).

## ۴. کامیت و باز کردن Pull Request

</div>

```bash
git add start.sh
git commit -m "Add YourProvider DNS"
git push origin my-feature
```

<div dir="rtl">

سپس در GitHub یک Pull Request با توضیح کوتاه از آنچه افزوده‌اید و دلیل آن باز کنید (مثلاً لینکی که در دسترس و قابل‌اعتماد بودن میرور/ریزالور را نشان دهد).

## راهنمای مشارکت

- **Bash سازگار با POSIX بنویسید** و با سبک موجود هماهنگ باشید (تورفتگی، کوتیشن، هِلپرهای `${COLOR}...${NC}`).
- **هر PR یک تغییر منطقی** تا بازبینی آسان باشد.
- **فقط ریزالورها/میرورهای عمومی و قابل‌اعتماد** را اضافه کنید — این ابزار DNS و پیکربندی Docker سیستم را تغییر می‌دهد، پس پایداری مهم است.
- **گزارش باگ و درخواست امکانات** از طریق [issue tracker](https://github.com/aminrpg/iranian-servers-toolkit/issues)؛ سیستم‌عامل، گزینه‌ی منو و خروجی خطا را ذکر کنید.

## منشور رفتار

محترمانه و سازنده باشید. همه اینجاییم تا کار با سرورهای ایرانی کم‌دردسرتر شود.

</div>
