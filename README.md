# ipad-as-a-display

Turn an iPad into the practical main display for a Mac mini that has no always-connected monitor.

This project is the minimal sharable version of the setup we validated on a real Mac mini:

- BetterDisplay provides a hidden display anchor so the Mac stays usable without HDMI.
- SidecarLauncher reconnects the iPad over Sidecar.
- A LaunchAgent checks periodically and recovers the iPad display when the connection drops.

## License

This project is open source under the MIT License. See [LICENSE](./LICENSE).

## Support

This project stays open source.

If it saves you time and you would like to support continued maintenance, you can "请我一杯咖啡" ("buy me a coffee").

This is a donation, not a purchase. Donations are optional and are not required to use the project.

Suggested amount: RMB 9.9.

WeChat donation QR code:

<img src="./docs/wechat-donate-9.9.jpg" alt="WeChat donation QR code" width="320" />

## What This Is For

Use this if you want:

- a Mac mini that can boot without a physical monitor
- an iPad connected over USB-C to become the usable screen
- automatic recovery after the iPad locks or Sidecar drops

## Current Assumptions

This project assumes:

- macOS on a Mac mini
- BetterDisplay is already installed
- the iPad and Mac use the same Apple Account
- automatic login is enabled on the Mac
- first-time setup is done while a normal monitor is still attached
- the iPad can be unlocked and trusted over USB-C during setup

## Files

- `install.sh`: first-time setup and LaunchAgent install
- `test.sh`: run one recovery cycle and show status
- `doctor.sh`: print current health and logs
- `uninstall.sh`: remove the installed service

## First-Time Setup

1. Attach a normal monitor to the Mac.
2. Connect the iPad over USB-C.
3. Unlock the iPad and trust the Mac if asked.
4. Make sure BetterDisplay is installed.
5. Run:

```zsh
chmod +x install.sh test.sh doctor.sh uninstall.sh
./install.sh
```

The installer will:

- download `SidecarLauncher`
- list reachable iPads
- let you choose which iPad to use
- ask whether the iPad should always become the main display
- install the `ipad-as-a-display` LaunchAgent

## Test Once Before You Share It

After install, run:

```zsh
./test.sh
```

Then manually verify:

1. The iPad shows the macOS desktop.
2. Lock and unlock the iPad once.
3. If your target setup is headless, unplug HDMI once and confirm the iPad returns on its own.

## Status And Logs

To inspect the current setup:

```zsh
./doctor.sh
```

Installed paths:

- LaunchAgent: `~/Library/LaunchAgents/local.ipad-as-a-display.plist`
- Config: `~/Library/Application Support/ipad-as-a-display/config.env`
- Service script: `~/Library/Application Support/ipad-as-a-display/ipad-as-a-display.sh`
- Log: `/tmp/ipad-as-a-display.log`
- Error log: `/tmp/ipad-as-a-display.err`

## Uninstall

```zsh
./uninstall.sh
```

## Notes

- The launch interval supports `15` or `30` seconds.
- The default should stay at `15` seconds unless you prefer slower recovery.
- BetterDisplay is treated as an implementation detail. The expected user outcome is simple: the iPad becomes the usable screen.
- `SidecarLauncher` uses private APIs, so macOS updates may break this setup.

## Acknowledgements

- This project uses [Ocasio-J/SidecarLauncher](https://github.com/Ocasio-J/SidecarLauncher) to trigger Sidecar connections from the command line.
- `SidecarLauncher` is open source and licensed under the MIT License.
- See [THIRD_PARTY_NOTICES.md](./THIRD_PARTY_NOTICES.md) for third-party licensing notes.
