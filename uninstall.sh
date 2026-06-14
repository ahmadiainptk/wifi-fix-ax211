#!/bin/bash
# uninstall.sh - Hapus semua komponen wifi-fix-ax211
# Usage: sudo ./uninstall.sh

set -e

if [ "$EUID" -ne 0 ]; then
    echo "❌ Jalankan dengan sudo: sudo ./uninstall.sh"
    exit 1
fi

SUDO_USER="${SUDO_USER:-$(logname 2>/dev/null || echo $USER)}"
USER_HOME=$(getent passwd "$SUDO_USER" 2>/dev/null | cut -d: -f6)

echo "🗑️  Removing wifi-fix-ax211 components..."

# Hapus dispatcher
rm -f /etc/NetworkManager/dispatcher.d/99-wifi-fix
echo "  ✓ /etc/NetworkManager/dispatcher.d/99-wifi-fix"

# Hapus sudoers
rm -f /etc/sudoers.d/99-fix-wifi
echo "  ✓ /etc/sudoers.d/99-fix-wifi"

# Hapus main script (opsional, comment jika mau keep)
if [ -n "$USER_HOME" ] && [ -f "$USER_HOME/.local/bin/fix-wifi" ]; then
    rm -f "$USER_HOME/.local/bin/fix-wifi"
    echo "  ✓ $USER_HOME/.local/bin/fix-wifi"
fi

# Hapus lockfiles
rm -f /tmp/wifi-fix-lock.* /tmp/wifi-fix-skip-check /tmp/wifi-fix-poll-* /tmp/wifi-fix-action-*
echo "  ✓ /tmp/wifi-fix-* lockfiles"

echo ""
echo "✅ Uninstall selesai."
echo "ℹ️  NetworkManager akan scan dispatcher.d/ lagi otomatis."
echo "ℹ️  Reboot atau restart NM untuk clear cache dispatcher."
