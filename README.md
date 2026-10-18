# NetSpeed

A tiny, native macOS menu bar app that shows your real-time upload and download speed.

```
↑ 1.2 MB/s
↓ 8.4 MB/s
```

- **Lightweight**: about 15–18 MB of memory (an empty menu bar app costs about 11 MB on its own) and roughly 0% CPU when idle
- **Single file**: about 150 lines of Swift with no dependencies, no Xcode project and no Dock icon
- **Accurate**: counts only physical interfaces (Wi-Fi, Ethernet, cellular tethering). Loopback and VPN tunnels are excluded, so VPN traffic isn't counted twice
- **Launch at Login** toggle and **Quit** are in the click menu

Requires macOS 13 or later.

## Install

### Download

1. Download `NetSpeed-vX.Y.Z.zip` from the [latest release](https://github.com/Aashu-Jha/NetSpeed/releases/latest). It is a universal app that runs on Apple silicon and Intel Macs.
2. Unzip it and move `NetSpeed.app` to `/Applications`.
3. Open it (see below for the first launch).

**First launch and Gatekeeper:** NetSpeed is ad-hoc signed and not notarized by Apple, so macOS blocks it the first time with a warning that it "cannot be opened" or "cannot verify the developer". To allow it, use either option:

- In Finder, right-click (or Control-click) `NetSpeed.app`, choose **Open**, then click **Open** in the dialog. On newer macOS versions, if there is no **Open** button, try to open the app once, then go to **System Settings → Privacy & Security** and click **Open Anyway**.
- Or remove the quarantine flag in Terminal:

  ```bash
  xattr -dr com.apple.quarantine /Applications/NetSpeed.app
  ```

You only need to do this once. If you prefer not to bypass Gatekeeper, build from source instead.

### Build from source

You need the Xcode Command Line Tools (`xcode-select --install`):

```bash
git clone https://github.com/Aashu-Jha/NetSpeed.git
cd NetSpeed
./build.sh --install
```

This compiles `NetSpeed.app`, copies it to `/Applications` and launches it.

To build without installing, run `./build.sh`. The app is written to `build/NetSpeed.app`. Add `--universal` to build for both Apple silicon and Intel.

## Releasing

Push a version tag (for example `git tag v1.1.0 && git push origin v1.1.0`). The [Release workflow](.github/workflows/release.yml) builds a universal app, zips it and attaches it to a new GitHub release.

## How it works

Once a second, NetSpeed reads per-interface byte counters through `sysctl(NET_RT_IFLIST2)` and adds up the change since the previous reading. Each interface is tracked separately, because some macOS versions report counters truncated to 32 bits that roll back to zero every 4 GB.

## Uninstall

Click the menu bar item, turn off **Launch at Login**, choose **Quit**, then delete `/Applications/NetSpeed.app`.

## License

MIT
