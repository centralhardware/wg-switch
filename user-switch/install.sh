#!/bin/bash
# Installs the user → tunnel switcher as a root LaunchDaemon.
#   ./install.sh                       # default mapping: working=wg1, alex=wg0
#   ./install.sh working=wg1 alex=wg0  # custom mapping
#   ./install.sh --uninstall
set -euo pipefail
cd "$(dirname "$0")"
LABEL=me.centralhardware.wg-user-switch
PLIST=/Library/LaunchDaemons/$LABEL.plist

if [[ "${1:-}" == --uninstall ]]; then
  sudo launchctl bootout system "$PLIST" 2>/dev/null || true
  sudo rm -f "$PLIST" /usr/local/bin/wg-user-switch
  echo "Uninstalled (kept /usr/local/etc/wg-user-switch.conf)"; exit 0
fi

pairs=("$@"); [[ ${#pairs[@]} -eq 0 ]] && pairs=(working=wg1 alex=wg0)
sudo mkdir -p /usr/local/bin /usr/local/etc
printf '%s\n' "${pairs[@]}" | sudo tee /usr/local/etc/wg-user-switch.conf >/dev/null
sudo install -m 0755 -o root -g wheel wg-user-switch.sh /usr/local/bin/wg-user-switch
sudo install -m 0644 -o root -g wheel $LABEL.plist "$PLIST"
sudo launchctl bootout system "$PLIST" 2>/dev/null || true
sudo launchctl bootstrap system "$PLIST"
echo "Installed. Mapping:"; cat /usr/local/etc/wg-user-switch.conf
echo "Log: /var/log/wg-user-switch.log"
