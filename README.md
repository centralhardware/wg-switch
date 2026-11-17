# WGSwitch

A macOS menu-bar app plus a desktop/Notification Center widget that switches between the
`wg-quick` profiles in `/etc/wireguard/*.conf`. Only one tunnel is up at a time: picking a
profile brings every active tunnel down first. Picking the active profile turns it off.

## Setup

```sh
brew install wireguard-tools xcodegen
./scripts/install-sudoers.sh      # passwordless sudo for wg-quick up/down only
xcodegen generate && open WGSwitch.xcodeproj
```

In Xcode, choose your team under *Signing & Capabilities* for both targets. The widget and the
app share state through an app group, and macOS only loads the widget from a signed build.
Then Run, move the app to /Applications, and add the **WireGuard** widget from the desktop's
"Edit Widgets".

## How it works

- The app runs `sudo -n wg-quick up|down <name>` and reads `/var/run/wireguard/*.name` to see
  which tunnel is up. It polls every 10 s, so it also notices changes made in the terminal.
- The sandboxed widget can't read `/etc/wireguard`, so the app publishes the profile list and
  the active tunnel to the app group. Tapping a row opens `wgswitch://toggle/<name>`, and the
  app (an agent with no Dock icon) performs the switch.

CI (`.github/workflows/build.yml`) produces an unsigned build. That's fine for checking that
the code compiles, but the widget only shows up in a build signed with your team.
