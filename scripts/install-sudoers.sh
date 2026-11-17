#!/bin/bash
# Lets the current user run wg-quick / list /etc/wireguard without a password,
# so WGSwitch can call `sudo -n`. Nothing else is granted.
set -euo pipefail
USER_NAME="${SUDO_USER:-$USER}"
BREW="$(brew --prefix 2>/dev/null || echo /opt/homebrew)"
FILE=/etc/sudoers.d/wgswitch
TMP="$(mktemp)"
cat > "$TMP" <<RULES
Cmnd_Alias WGSWITCH = $BREW/bin/wg-quick up *, $BREW/bin/wg-quick down *, /bin/ls /etc/wireguard
# wg-quick needs Homebrew's bash 4+ and wireguard-go on PATH
Defaults!WGSWITCH secure_path="$BREW/bin:/usr/bin:/bin:/usr/sbin:/sbin"
$USER_NAME ALL=(root) NOPASSWD: WGSWITCH
RULES
sudo visudo -cf "$TMP"
sudo install -m 0440 -o root -g wheel "$TMP" "$FILE"
rm -f "$TMP"
echo "Installed $FILE for $USER_NAME"
