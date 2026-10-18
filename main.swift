import AppKit
import ServiceManagement

// Reports bytes in/out since the previous call across physical interfaces (Wi-Fi,
// Ethernet, cellular tether) via NET_RT_IFLIST2. Excludes loopback and virtual tunnels
// (utun/ipsec) so VPN traffic isn't double-counted. Deltas are tracked per interface
// because the kernel may hand back counters truncated to 32 bits, which wrap every 4 GB.
final class NetCounter {
    private var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
    private var buf = [UInt8](repeating: 0, count: 16 * 1024)
    private var name = [CChar](repeating: 0, count: Int(IF_NAMESIZE))
    private var prev: [UInt16: (rx: UInt64, tx: UInt64)] = [:]

    func delta() -> (rx: UInt64, tx: UInt64) {
        var len = 0
        guard sysctl(&mib, 6, nil, &len, nil, 0) == 0 else { return (0, 0) }
        if len > buf.count { buf = [UInt8](repeating: 0, count: len * 2) }
        guard sysctl(&mib, 6, &buf, &len, nil, 0) == 0 else { return (0, 0) }

        var rx: UInt64 = 0, tx: UInt64 = 0
        buf.withUnsafeBytes { raw in
            var off = 0
            while off + MemoryLayout<if_msghdr>.size <= len {
                let hdr = raw.loadUnaligned(fromByteOffset: off, as: if_msghdr.self)
                if hdr.ifm_msglen == 0 { break }
                if Int32(hdr.ifm_type) == RTM_IFINFO2 {
                    let m = raw.loadUnaligned(fromByteOffset: off, as: if_msghdr2.self)
                    if m.ifm_flags & IFF_LOOPBACK == 0, isPhysical(index: m.ifm_index) {
                        let cur = (rx: m.ifm_data.ifi_ibytes, tx: m.ifm_data.ifi_obytes)
                        if let p = prev[m.ifm_index] {
                            rx &+= diff(cur.rx, p.rx)
                            tx &+= diff(cur.tx, p.tx)
                        }
                        prev[m.ifm_index] = cur
                    }
                }
                off += Int(hdr.ifm_msglen)
            }
        }
        return (rx, tx)
    }

    private func diff(_ cur: UInt64, _ old: UInt64) -> UInt64 {
        if cur >= old { return cur - old }
        if old <= UInt64(UInt32.max) { return cur &+ (1 << 32) &- old } // 32-bit wrap
        return 0 // counter reset
    }

    private func isPhysical(index: UInt16) -> Bool {
        guard if_indextoname(UInt32(index), &name) != nil else { return false }
        // en* = Wi-Fi/Ethernet/USB tether, pdp_ip* = cellular
        return (name[0] == 0x65 && name[1] == 0x6E) || strncmp(name, "pdp_ip", 6) == 0
    }
}

// Two-line label drawn directly; no per-tick allocation beyond the strings.
final class SpeedView: NSView {
    var up = "0 KB/s", down = "0 KB/s"
    private let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium),
    ]

    override func draw(_ dirtyRect: NSRect) {
        var a = attrs
        a[.foregroundColor] = NSColor.labelColor
        let h = bounds.height / 2
        ("↑ " + up as NSString).draw(at: NSPoint(x: 2, y: h - 1), withAttributes: a)
        ("↓ " + down as NSString).draw(at: NSPoint(x: 2, y: -1), withAttributes: a)
    }

    // Let clicks fall through to the status bar button.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: 64)
    private let view = SpeedView()
    private let counter = NetCounter()
    private var lastTime: UInt64 = 0
    private var timer: Timer?

    func applicationDidFinishLaunching(_ note: Notification) {
        guard let button = item.button else { return }
        view.frame = button.bounds
        view.autoresizingMask = [.width, .height]
        button.addSubview(view)

        let menu = NSMenu()
        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin(_:)), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu

        _ = counter.delta()
        lastTime = DispatchTime.now().uptimeNanoseconds
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        t.tolerance = 0.2
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        let now = DispatchTime.now().uptimeNanoseconds
        let d = counter.delta()
        let dt = Double(now - lastTime) / 1e9
        let rx = Double(d.rx) / dt, tx = Double(d.tx) / dt
        lastTime = now
        view.down = format(rx)
        view.up = format(tx)
        view.needsDisplay = true
    }

    private func format(_ bps: Double) -> String {
        switch bps {
        case ..<1_000: return "0 KB/s"
        case ..<1_000_000: return String(format: "%.0f KB/s", bps / 1_000)
        case ..<10_000_000: return String(format: "%.1f MB/s", bps / 1_000_000)
        case ..<1_000_000_000: return String(format: "%.0f MB/s", bps / 1_000_000)
        default: return String(format: "%.1f GB/s", bps / 1_000_000_000)
        }
    }

    @objc private func toggleLogin(_ sender: NSMenuItem) {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("NetSpeed: launch-at-login failed: \(error)")
        }
        sender.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
