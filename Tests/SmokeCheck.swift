import Foundation

// A live sanity check, not an accuracy benchmark against Activity Monitor.
@main
struct SmokeCheck {
    static func main() {
        let stats = MemoryStats.read()
        guard let used = stats.usedBytes,
              let cached = stats.cachedBytes,
              let swap = stats.swapBytes else {
            fatalError("Could not read system memory counters")
        }
        let physical = ProcessInfo.processInfo.physicalMemory
        precondition(used > 0 && used <= physical, "Used RAM outside physical capacity")
        precondition(cached <= physical, "Cached RAM outside physical capacity")
        precondition(gigabytes(nil) == "—")
        precondition(gigabytes(1_073_741_824) == "1.00")
        precondition(gigabytes(0) == "0.00")

        print("RAM: \(gigabytes(used)) / \(gigabytes(physical)) GB")
        print("Cached: \(gigabytes(cached)) GB")
        print("Swap: \(gigabytes(swap)) GB")
        print("Pressure: \(stats.pressure.rawValue)")
        let apps = AppMemory.topThree()
        precondition(apps.count <= 3)
        for (first, second) in zip(apps, apps.dropFirst()) {
            precondition(first.bytes >= second.bytes)
        }
        for app in apps {
            print("App + bundled helpers: \(app.name): \(gigabytes(app.bytes)) GB")
        }
        print("Live sanity checks passed.")
    }
}
