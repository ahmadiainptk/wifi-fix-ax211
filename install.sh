#!/bin/bash
# install.sh - Installer untuk wifi-fix-ax211
# Usage: ./install.sh

set -e

if [ "$EUID" -ne 0 ]; then
    echo "❌ Jalankan dengan sudo: sudo ./install.sh"
    exit 1
fi

# Detect user yang akan dikontrol notifnya
SUDO_USER="${SUDO_USER:-$(logname 2>/dev/null || echo $USER)}"
if [ "$SUDO_USER" = "root" ] || [ -z "$SUDO_USER" ]; then
    echo "❌ Tidak bisa detect user. Jalankan via: sudo -u <user> sudo ./install.sh"
    exit 1
fi

USER_UID=$(id -u "$SUDO_USER")
USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)

echo "🔧 Installing for user: $SUDO_USER (uid=$USER_UID, home=$USER_HOME)"

# === 1. Install fix-wifi script ===
echo "📦 Installing fix-wifi to /home/$SUDO_USER/.local/bin/..."
install -d -m 755 -o "$SUDO_USER" -g "$SUDO_USER" "/home/$SUDO_USER/.local/bin"
install -m 755 -o "$SUDO_USER" -g "$SUDO_USER" scripts/fix-wifi "/home/$SUDO_USER/.local/bin/fix-wifi"

# === 2. Sudoers: NOPASSWD untuk fix-wifi ===
echo "🔐 Configuring sudoers..."
cat > /etc/sudoers.d/99-fix-wifi <<EOF
# Allow passwordless fix-wifi for $SUDO_USER
$SUDO_USER ALL=(ALL) NOPASSWD: $USER_HOME/.local/bin/fix-wifi
EOF
chmod 440 /etc/sudoers.d/99-fix-wifi

# === 3. NM dispatcher script ===
echo "📡 Installing NM dispatcher..."
install -d -m 755 /etc/NetworkManager/dispatcher.d
install -m 755 -o root -g root etc/99-wifi-fix /etc/NetworkManager/dispatcher.d/99-wifi-fix

# Patch USER_NAME dan USER_UID di dispatcher (default: baha, 1000)
sed -i "s/^USER_NAME=.*/USER_NAME=\"$SUDO_USER\"/" /etc/NetworkManager/dispatcher.d/99-wifi-fix
sed -i "s|^USER_UID=.*|USER_UID=$USER_UID|" /etc/NetworkManager/dispatcher.d/99-wifi-fix
chmod 755 /etc/NetworkManager/dispatcher.d/99-wifi-fix

# === 4. Verifikasi ===
echo ""
echo "✅ Install selesai. Verifikasi:"
echo "  - /home/$SUDO_USER/.local/bin/fix-wifi: $(ls -la /home/$SUDO_USER/.local/bin/fix-wifi | awk '{print $1}')"
echo "  - /etc/sudoers.d/99-fix-wifi: $(ls -la /etc/sudoers.d/99-fix-wifi | awk '{print $1}')"
echo "  - /etc/NetworkManager/dispatcher.d/99-wifi-fix: $(ls -la /etc/NetworkManager/dispatcher.d/99-wifi-fix | awk '{print $1}')"
echo ""
echo "🧪 Test manual: sudo fix-wifi"
echo "📋 Logs: journalctl -t wifi-fix -t fix-wifi -f"
