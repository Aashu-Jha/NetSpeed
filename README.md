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

Build from source. You need the Xcode Command Line Tools (`xcode-select --install`):

```bash
git clone https://github.com/Aashu-Jha/NetSpeed.git
cd NetSpeed
./build.sh --install
```

This compiles `NetSpeed.app`, copies it to `/Applications` and launches it.

To build without installing, run `./build.sh`. The app is written to `build/NetSpeed.app`.

## How it works

Once a second, NetSpeed reads per-interface byte counters through `sysctl(NET_RT_IFLIST2)` and adds up the change since the previous reading. Each interface is tracked separately, because some macOS versions report counters truncated to 32 bits that roll back to zero every 4 GB.

## Uninstall

Click the menu bar item, turn off **Launch at Login**, choose **Quit**, then delete `/Applications/NetSpeed.app`.

## License

MIT
