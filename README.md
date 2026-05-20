# Black-Tools

ابزار مدیریت تعاملی سرور لینوکس — بدون نیاز به حفظ کردن دستورات، فقط منو انتخاب کن.

دو نسخه:

| | black-tools | black-tools PRO |
|---|---|---|
| فایل | `black-tools.sh` | `install_pro.sh` |
| دستور | `black-tools` | `black-tools-pro` |
| تمرکز | ابزارهای پایه | ابزارهای پیشرفته + نصب‌کننده |

---

## ⚡ نصب سریع — black-tools PRO

### روش ۱ — Copy & Paste (بدون نیاز به هیچ چیز)

لینک زیر رو باز کن، همه محتوا رو کپی کن (`Ctrl+A` → `Ctrl+C`)، داخل ترمینال paste کن و Enter بزن:

```
https://raw.githubusercontent.com/saeederamy/black-tools/main/install-pro.sh
```

### روش ۲ — با curl

```bash
curl -fsSL https://raw.githubusercontent.com/saeederamy/black-tools/main/install_pro.sh | sudo bash -s -- --install
```

### روش ۳ — با wget

```bash
wget -qO- https://raw.githubusercontent.com/saeederamy/black-tools/main/install_pro.sh | sudo bash -s -- --install
```

بعد از نصب، از هر جا اجرا کن:

```bash
black-tools-pro
```

---

## ⚡ نصب سریع — black-tools (نسخه پایه)

```bash
sudo curl -fsSL https://raw.githubusercontent.com/saeederamy/black-tools/main/black-tools.sh -o /usr/local/bin/black-tools && sudo chmod +x /usr/local/bin/black-tools
```

بعد از نصب:

```bash
black-tools
```

---

## ✨ امکانات — black-tools PRO

| بخش | توضیح |
|---|---|
| **مانیتورینگ** | اطلاعات سیستم، پروسس‌ها، htop/top، auto-diagnostics (CPU، RAM، دیسک، سرویس‌های fail شده، OOM، DNS) |
| **لاگ‌ها** | journalctl، auth log، dmesg، boot log، خطاها، live-follow |
| **SSH پیشرفته** | تغییر پورت، root login، اضافه کردن کلید، **تولید SSH key** (Ed25519/RSA/ECDSA)، نمایش کلیدها، ssh-copy-id |
| **کاربران** | لیست، ایجاد، حذف، قفل/آنلاک، تغییر پسورد |
| **فایروال کامل** | UFW / iptables / nftables / firewalld — باز/بستن پورت، block IP، rate-limit، ذخیره rules |
| **شبکه پیشرفته** | **IP استاتیک**، اساین IPv4/IPv6، حذف IP، تغییر DNS، **IP Forwarding**، routing |
| **Cron Manager** | لیست، اضافه (راهنما)، حذف، ویرایش، لاگ‌های cron |
| **لینک دانلود موقت** | Python HTTP server با timeout خودکار و URL عمومی |
| **tmux** | مدیریت session‌ها، attach، kill، راهنمای کلیدها |
| **Docker** | container/image/volume/network، compose، prune، exec |
| **نصب‌کننده نرم‌افزار** | Nginx، MySQL، MariaDB، PostgreSQL، MongoDB، Redis، Python، Node.js، Docker |
| **ریپوهای اختصاصی** | 3x-ui (paqctl)، Madmail، StormDNS |
| **سرویس‌ها** | systemd — start/stop/enable/disable/logs |
| **دیسک** | مصرف، بزرگ‌ترین فایل‌ها، پاک‌سازی cache و /tmp |
| **امنیت** | Fail2ban، ورودهای ناموفق، hardening، unattended-upgrades |
| **تنظیمات** | hostname، timezone، swap |
| **پکیج‌ها** | update/upgrade، نصب، حذف، جستجو |
| **بکاپ** | فشرده‌سازی هر دایرکتوری |

---

## ✨ امکانات — black-tools (نسخه پایه)

| بخش | توضیح |
|---|---|
| **مانیتورینگ** | اطلاعات سیستم، پروسس‌ها، htop/top، auto-diagnostics |
| **SSH** | تغییر پورت، root login، اضافه کردن کلید، غیرفعال کردن password auth |
| **کاربران** | لیست، ایجاد، حذف، قفل/آنلاک، تغییر پسورد |
| **فایروال** | UFW / firewalld / iptables — باز/بستن پورت |
| **پورت‌ها** | لیست listeners، بررسی پورت خاص |
| **پروسس‌ها** | kill به PID / نام / پورت |
| **سرویس‌ها** | systemd — کنترل کامل |
| **دیسک** | مصرف، پاک‌سازی، جستجو |
| **شبکه** | اینترفیس‌ها، DNS، ping، traceroute |
| **تنظیمات** | hostname، timezone، DNS، swap |
| **امنیت** | Fail2ban، auditing، hardening |
| **پکیج‌ها** | update، نصب، حذف، جستجو |
| **بکاپ** | tar.gz از هر دایرکتوری |

---

## 🖥️ سیستم‌های پشتیبانی‌شده

Ubuntu · Debian · Mint · Pop!_OS · Kali · CentOS · RHEL · Rocky · AlmaLinux · Fedora · Arch · Manjaro · openSUSE · Alpine

Package manager به صورت خودکار تشخیص داده می‌شه (`apt` / `dnf` / `yum` / `pacman` / `zypper` / `apk`).

---

## 🛡️ نکات ایمنی

- قبل از هر ویرایش config، یه backup با timestamp ساخته می‌شه
- تغییرات SSH با `sshd -t` تست می‌شن — اگه خطا داشت، backup بازگردانده می‌شه
- تمام عملیات‌ها در `/var/log/black-tools-pro.log` لاگ می‌شن
- اقدامات مخرب قبل از اجرا تأیید می‌خوان

---

## 🗑️ حذف

```bash
# PRO
sudo black-tools-pro --uninstall

# پایه
sudo black-tools --uninstall
```

---

## 📋 پیش‌نیازها

- Bash 4+
- دسترسی sudo یا root
- ابزارهای استاندارد: `ss`/`netstat`، `systemctl`، package manager
- اختیاری: `htop`، `curl`، `python3` (برای لینک دانلود موقت)

---

## ⚠️ سلب مسئولیت

این ابزار تنظیمات سیستم رو تغییر می‌ده. قبل از هر تغییر در SSH، فایروال یا بوت، از دسترسی console اطمینان حاصل کن.

---

## 📜 License

MIT
