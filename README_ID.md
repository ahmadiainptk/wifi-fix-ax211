# wifi-fix-ax211

Auto-recovery untuk Intel Wi-Fi 6E AX211 (dan turunannya) yang sering drop / device menghilang di Linux.

> 🇬🇧 **English version?** See [README.md](README.md)

## 📋 Masalah

Device WiFi **Intel AX211** di Linux (khususnya kernel modern + iwlwifi driver) kadang mengalami:

- Device WiFi **menghilang random** dari `iw dev` / `ip link`
- `rfkill list` menunjukkan device masih ada tapi radio **off**
- NetworkManager tidak bisa reconnect
- Tidak ada notifikasi sama sekali — user cuma tahu saat buka browser dan tidak ada internet

Workaround: **reload driver iwlwifi + iwlmvm**, lalu tunggu interface muncul lagi. Tapi ini harus manual via terminal.

## ✨ Solusi

Repo ini menyediakan:

1. **`fix-wifi`** — script reload driver dengan retry otomatis
2. **NetworkManager dispatcher** — deteksi otomatis saat WiFi down, kirim notifikasi persistent dengan tombol "Perbaiki WiFi"

Behavior:
- WiFi down → tunggu 12s untuk NM auto-reconnect (silent kalau berhasil)
- Masih down → notifikasi **persistent** muncul (urgency=critical, gak auto-dismiss)
- Klik "Perbaiki WiFi" → jalankan `fix-wifi` → notifikasi hasil
- WiFi auto-reconnect saat notif tampil → otomatis dismiss notif + info

## 🖥️ Tested on

| Item | Detail |
|------|--------|
| **OS** | CachyOS (Arch-based) |
| **Kernel** | linux-cachyos (tested pada 6.x) |
| **Desktop** | Hyprland (Wayland) |
| **Shell** | bash 5.x |
| **Init** | systemd |
| **Network** | NetworkManager (nmcli) |
| **WiFi device** | Intel Wi-Fi 6E **AX211** (PCI `8086:51f0`, "Alder Lake-P PCH CNVi WiFi") |
| **Laptop** | ASUS (rfkill: `asus-wlan`) |
| **Notif daemon** | DankMaterialShell (`dms`) via D-Bus |

## 📦 Requirements

- `bash`, `sudo`, `iw`, `nmcli` (NetworkManager), `modprobe` (kmod), `gdbus` (glib2)
- Linux kernel dengan modul `iwlwifi` dan `iwlmvm`
- User dengan `sudo` privilege untuk `fix-wifi`
- D-Bus session bus aktif (untuk notifikasi)

## 🚀 Install

```bash
git clone https://github.com/ahmadiainptk/wifi-fix-ax211.git
cd wifi-fix-ax211
chmod +x install.sh uninstall.sh
sudo ./install.sh
```

Installer akan:
1. Copy `fix-wifi` ke `~/.local/bin/`
2. Set sudoers NOPASSWD untuk `fix-wifi`
3. Install dispatcher ke `/etc/NetworkManager/dispatcher.d/99-wifi-fix`
4. Patch user config otomatis

## 🧪 Test

Manual test WiFi recovery:
```bash
sudo fix-wifi
```

Test notifikasi:
```bash
# Lihat real-time log dispatcher
journalctl -t wifi-fix -t fix-wifi -f

# Trigger WiFi down
nmcli device disconnect wlan0   # ganti dengan interface lo
```

Tunggu 12-15 detik. Notifikasi persistent akan muncul.

## 🗑️ Uninstall

```bash
sudo ./uninstall.sh
```

## 🔧 Cara Kerja

### `fix-wifi` (manual recovery)

Loop sampai 10×:
1. `modprobe -r iwlmvm iwlwifi`
2. Tunggu 2 detik
3. `modprobe iwlwifi`
4. Cek `iw dev` untuk interface baru
5. Tunggu koneksi NetworkManager (max 15s)
6. Kalau connected → exit 0
7. Kalau interface gak muncul → retry

### Dispatcher (auto-detection)

Setiap NetworkManager event interface → dispatcher dijalankan:
- Filter: hanya `wlan*` dan event `down`
- **Cooldown 60s** per interface (cegah spam)
- **Smart-skip #1**: skip kalau ada wifi interface lain yang sudah connected (efek rename setelah driver reload)
- **Smart-skip #2**: tunggu 12s, kalau NM auto-reconnect berhasil → silent exit
- **Kirim notif persistent** (urgency=critical, timeout=0) dengan 1 action: `fix`
- **Monitor paralel**:
  - `gdbus monitor` untuk tangkap `ActionInvoked` signal
  - Polling `nmcli` setiap 3s untuk detect auto-reconnect
- Whichever fires first → dispatch

## 📁 Struktur Repo

```
wifi-fix-ax211/
├── README.md           (English)
├── README_ID.md        (Bahasa Indonesia)
├── LICENSE
├── install.sh          # Installer
├── uninstall.sh        # Uninstaller
├── scripts/
│   └── fix-wifi        # Main reload script
├── etc/
│   ├── 99-wifi-fix                  # NM dispatcher
│   ├── NetworkManager/
│   │   └── conf.d/                  # NM tweaks (iwd backend, no powersave)
│   └── modprobe.d/                  # iwlwifi kernel module tweaks
└── assets/             # Screenshots, logo
```

## 🛠️ Konfigurasi Tambahan (Opsional)

Repo ini juga menyertakan tweak NetworkManager + modprobe yang melengkapi dispatcher:

### `etc/NetworkManager/conf.d/wifi_backend.conf`
Pakai **iwd** sebagai backend WiFi (default-nya wpa_supplicant). iwd sering lebih stabil untuk chip Intel AX-series.
- Butuh: `sudo pacman -S iwd && sudo systemctl enable --now iwd`
- `wifi.backend=iwd`

### `etc/NetworkManager/conf.d/disable-powersave.conf`
Disable WiFi power saving di level NetworkManager.
- `wifi.powersave=2` (2 = disabled)

### `etc/modprobe.d/iwlwifi.conf`
Disable kernel-level iwlwifi power save + U-APSD (sering bikin drop di Intel AX).
- `options iwlwifi power_save=0 uapsd_disable=1`

Ketiganya di-install otomatis oleh `install.sh`. Mereka mengatasi **root cause** (power management agresif), sedangkan dispatcher handle **workaround** kalau masih drop.

## 🔍 Troubleshooting

**Notifikasi gak muncul**
- Cek: `journalctl -t wifi-fix -t fix-wifi -n 20`
- Pastikan notif daemon support D-Bus standard (`dunst`, `mako`, `dms`, `gnome-shell`, `kde`)
- Test manual: `gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications --method org.freedesktop.Notifications.Notify "Test" "" "Test" "Body" "[]" "{}" 5000`

**Dispatcher gak fire**
- Pastikan file di `/etc/NetworkManager/dispatcher.d/` (root, bukan subfolder)
- Mode harus 755 executable
- Test: `nmcli device disconnect wlan0; sleep 15; journalctl -t wifi-fix -n 5`

**fix-wifi gak bisa reload**
- Perlu sudo privilege untuk `modprobe`
- Cek apakah `iwlmvm` dan `iwlwifi` di-blacklist: `cat /etc/modprobe.d/blacklist.conf`
- Test manual: `sudo modprobe -r iwlmvm iwlwifi; sleep 2; sudo modprobe iwlwifi`

**Notifikasi gak ada tombol aksi**
- Beberapa notif daemon (terutama yang minimal seperti `dunst` dengan rule custom) bisa hide actions
- dms: harusnya jalan out of the box
- dunst: perlu konfigurasi `summary_format` dan `urgency = critical`

## 🤝 Contributing

PR welcome! Kalau lo punya device WiFi lain yang juga drop random (bukan cuma AX211), bisa generalize script untuk support multiple device. Kasih tahu PCI ID + driver name di issue.

## 📜 License

MIT License — lihat [LICENSE](LICENSE).

## ⚠️ Disclaimer

Script ini hanya workaround untuk bug driver/hardware. Penyebab root mungkin:
- Firmware iwlwifi outdated (`iwlwifi-ty-a0-gf-a0-*.ucode`)
- Power management aggressive (`iwlmvm.power_scheme`)
- BIOS/UEFI WiFi power saving
- Kernel regression

Coba dulu:
```bash
# Disable power saving untuk iwlmvm
echo "options iwlmvm power_scheme=1" | sudo tee /etc/modprobe.d/iwlmvm.conf
# Update firmware ke terbaru
sudo pacman -S linux-firmware
```

Kalau masih drop setelah patch firmware + power management, baru pakai script ini sebagai band-aid.

## 👤 Author

**ahmadiainptk** — IT Admin di IAIN Pontianak
- GitHub: [@ahmadiainptk](https://github.com/ahmadiainptk)
- Email: ahmad.iainptk@gmail.com
