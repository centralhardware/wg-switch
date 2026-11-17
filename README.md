# WGSwitch

A macOS 26 menu-bar app plus Control Center tiles that switch between the
`wg-quick` profiles in `/etc/wireguard/*.conf`. Only one tunnel is up at a time: picking a
profile brings every active tunnel down first. Picking the active profile turns it off.

## Install

Download `WGSwitch.dmg` from the latest [release](https://github.com/centralhardware/wg-switch/releases/latest)
and drag the app to Applications. Then:

```sh
brew install wireguard-tools
curl -fsSL https://raw.githubusercontent.com/centralhardware/wg-switch/main/scripts/install-sudoers.sh | bash
```

The build is ad-hoc signed, so the first launch needs right-click → Open.

## Build from source

```sh
brew install wireguard-tools xcodegen
./scripts/install-sudoers.sh      # passwordless sudo for wg-quick up/down only
xcodegen generate && open WGSwitch.xcodeproj
```

In Xcode, choose your team under *Signing & Capabilities* for both targets. The tiles and the
app share state through the `me.centralhardware.wgswitch.shared` preferences domain, so an
ad-hoc build works too.
Then Run, move the app to /Applications, open Control Center → Edit Controls, add a
**WireGuard Profile** tile and pick a profile. Add one tile per profile.

## How it works

- The app runs `sudo -n wg-quick up|down <name>` and reads `/var/run/wireguard/*.name` to see
  which tunnel is up. It polls every 10 s, so it also notices changes made in the terminal.
- The sandboxed Control Center extension can't read `/etc/wireguard` or run sudo. The app
  publishes the profile list and the active tunnel to a shared preferences domain (the extension has a sandbox exception for it;
  app groups would need a provisioning profile). A tile tap writes the
  request there and posts a Darwin notification; the app performs the switch and reloads all
  tiles, so only one ever shows On. The app must be running (add it to Login Items).

Releases: push a `v*` tag and `.github/workflows/release.yml` builds the DMG and attaches it.
