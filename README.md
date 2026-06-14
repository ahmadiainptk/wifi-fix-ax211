# wifi-fix-ax211

Auto-recovery for Intel Wi-Fi 6E AX211 (and similar) that frequently drops / device disappears on Linux.

> 🇮🇩 **Bahasa Indonesia?** Lihat [README_ID.md](README_ID.md)

## 📋 The Problem

**Intel AX211** WiFi devices on Linux (especially with modern kernels + iwlwifi driver) sometimes experience:

- WiFi device **randomly disappears** from `iw dev` / `ip link`
- `rfkill list` shows the device is still there, but the radio is **off**
- NetworkManager cannot reconnect
- No notification at all — user only realizes when opening a browser with no internet

Workaround: **reload the iwlwifi + iwlmvm drivers**, then wait for the interface to come back. But this has to be done manually via terminal.

## ✨ The Solution

This repo provides:

1. **`fix-wifi`** — driver reload script with automatic retry
2. **NetworkManager dispatcher** — automatic detection when WiFi goes down, sends a persistent notification with "Perbaiki WiFi" button

Behavior:
- WiFi goes down → wait 12s for NM auto-reconnect (silent if successful)
- Still down → **persistent** notification appears (urgency=critical, won't auto-dismiss)
- Click "Perbaiki WiFi" → runs `fix-wifi` → result notification
- WiFi auto-reconnects while notification is up → auto-dismiss notification + info

## 🖥️ Tested on

| Item | Detail |
|------|--------|
| **OS** | CachyOS (Arch-based) |
| **Kernel** | linux-cachyos (tested on 6.x) |
| **Desktop** | Hyprland (Wayland) |
| **Shell** | bash 5.x |
| **Init** | systemd |
| **Network** | NetworkManager (nmcli) |
| **WiFi device** | Intel Wi-Fi 6E **AX211** (PCI `8086:51f0`, "Alder Lake-P PCH CNVi WiFi") |
| **Laptop** | ASUS (rfkill: `asus-wlan`) |
| **Notif daemon** | DankMaterialShell (`dms`) via D-Bus |

## 📦 Requirements

- `bash`, `sudo`, `iw`, `nmcli` (NetworkManager), `modprobe` (kmod), `gdbus` (glib2)
- Linux kernel with `iwlwifi` and `iwlmvm` modules
- User with `sudo` privilege for `fix-wifi`
- Active D-Bus session bus (for notifications)

## 🚀 Install

```bash
git clone https://github.com/ahmadiainptk/wifi-fix-ax211.git
cd wifi-fix-ax211
chmod +x install.sh uninstall.sh
sudo ./install.sh
```

The installer will:
1. Copy `fix-wifi` to `~/.local/bin/`
2. Set sudoers NOPASSWD for `fix-wifi`
3. Install dispatcher to `/etc/NetworkManager/dispatcher.d/99-wifi-fix`
4. Auto-patch user config

## 🧪 Test

Manual WiFi recovery test:
```bash
sudo fix-wifi
```

Notification test:
```bash
# Watch real-time dispatcher log
journalctl -t wifi-fix -t fix-wifi -f

# Trigger WiFi down
nmcli device disconnect wlan0   # replace with your interface
```

Wait 12-15 seconds. Persistent notification will appear.

## 🗑️ Uninstall

```bash
sudo ./uninstall.sh
```

## 🔧 How It Works

### `fix-wifi` (manual recovery)

Loop up to 10×:
1. `modprobe -r iwlmvm iwlwifi`
2. Wait 2 seconds
3. `modprobe iwlwifi`
4. Check `iw dev` for new interface
5. Wait for NetworkManager connection (max 15s)
6. If connected → exit 0
7. If interface doesn't appear → retry

### Dispatcher (auto-detection)

Every NetworkManager interface event → dispatcher runs:
- Filter: only `wlan*` and `down` event
- **Cooldown 60s** per interface (prevents spam)
- **Smart-skip #1**: skip if another wifi interface is already connected (rename effect after driver reload)
- **Smart-skip #2**: wait 12s, if NM auto-reconnect succeeds → silent exit
- **Send persistent notification** (urgency=critical, timeout=0) with 1 action: `fix`
- **Parallel monitoring**:
  - `gdbus monitor` to catch `ActionInvoked` signal
  - `nmcli` polling every 3s to detect auto-reconnect
- Whichever fires first → dispatch

## 📁 Repo Structure

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

## 🛠️ Optional Configuration Tweaks

The repo also includes recommended NetworkManager + modprobe tweaks that complement the dispatcher:

### `etc/NetworkManager/conf.d/wifi_backend.conf`
Use **iwd** instead of default wpa_supplicant as the WiFi backend. iwd is often more stable for Intel AX-series chips.
- Requires: `sudo pacman -S iwd && sudo systemctl enable --now iwd`
- `wifi.backend=iwd`

### `etc/NetworkManager/conf.d/disable-powersave.conf`
Disable NetworkManager-level WiFi power saving.
- `wifi.powersave=2` (2 = disabled)

### `etc/modprobe.d/iwlwifi.conf`
Disable kernel-level iwlwifi power save + U-APSD (often cause drop on Intel AX).
- `options iwlwifi power_save=0 uapsd_disable=1`

All three are installed automatically by `install.sh`. They address the **root cause** (aggressive power management), while the dispatcher handles **workarounds** when it still drops.

## 🔍 Troubleshooting

**Notification doesn't appear**
- Check: `journalctl -t wifi-fix -t fix-wifi -n 20`
- Make sure your notif daemon supports standard D-Bus (`dunst`, `mako`, `dms`, `gnome-shell`, `kde`)
- Manual test: `gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications --method org.freedesktop.Notifications.Notify "Test" "" "Test" "Body" "[]" "{}" 5000`

**Dispatcher doesn't fire**
- Make sure file is at `/etc/NetworkManager/dispatcher.d/` (root, not subfolder)
- Mode must be 755 executable
- Test: `nmcli device disconnect wlan0; sleep 15; journalctl -t wifi-fix -n 5`

**fix-wifi can't reload**
- Need sudo privilege for `modprobe`
- Check if `iwlmvm` and `iwlwifi` are blacklisted: `cat /etc/modprobe.d/blacklist.conf`
- Manual test: `sudo modprobe -r iwlmvm iwlwifi; sleep 2; sudo modprobe iwlwifi`

**Notification has no action buttons**
- Some notif daemons (especially minimal ones like `dunst` with custom rules) might hide actions
- dms: should work out of the box
- dunst: needs `summary_format` and `urgency = critical` configured

## 🤝 Contributing

PRs welcome! If you have other WiFi devices that also drop randomly (not just AX211), feel free to generalize the script to support multiple devices. Mention the PCI ID + driver name in the issue.

## 📜 License

MIT License — see [LICENSE](LICENSE).

## ⚠️ Disclaimer

This script is only a workaround for a driver/hardware bug. The root cause might be:
- Outdated iwlwifi firmware (`iwlwifi-ty-a0-gf-a0-*.ucode`)
- Aggressive power management (`iwlmvm.power_scheme`)
- BIOS/UEFI WiFi power saving
- Kernel regression

Try these first:
```bash
# Disable power saving for iwlmvm
echo "options iwlmvm power_scheme=1" | sudo tee /etc/modprobe.d/iwlmvm.conf
# Update firmware to latest
sudo pacman -S linux-firmware
```

If it still drops after firmware + power management patches, then use this script as a band-aid.

## 👤 Author

**ahmadiainptk** — IT Admin at IAIN Pontianak
- GitHub: [@ahmadiainptk](https://github.com/ahmadiainptk)
- Email: ahmad.iainptk@gmail.com
