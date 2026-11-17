#!/bin/bash
# Keeps the wg-quick tunnel matching the macOS user in front (fast user switching).
# Runs as root from the LaunchDaemon me.centralhardware.wg-user-switch every few seconds.
#
# Mapping: one "user=profile" pair per line in /usr/local/etc/wg-user-switch.conf, e.g.
#   working=wg1
#   alex=wg0
# A user with no line (or the login window) leaves the tunnels alone.
set -u
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
CONF=/usr/local/etc/wg-user-switch.conf
RUN=/var/run/wireguard

user=$(stat -f %Su /dev/console)
[[ -z "$user" || "$user" == root || "$user" == loginwindow ]] && exit 0

want=$(awk -F= -v u="$user" '$1==u {print $2; exit}' "$CONF" 2>/dev/null)
[[ -z "$want" ]] && exit 0

active=()
for f in "$RUN"/*.name; do [[ -e "$f" ]] && active+=("$(basename "$f" .name)"); done

# Already exactly the wanted tunnel → nothing to do.
[[ ${#active[@]} -eq 1 && "${active[0]}" == "$want" ]] && exit 0

for p in "${active[@]}"; do
  [[ "$p" != "$want" ]] && { echo "$(date '+%F %T') $user: down $p"; wg-quick down "$p"; }
done
[[ -e "$RUN/$want.name" ]] || { echo "$(date '+%F %T') $user: up $want"; wg-quick up "$want"; }
