import AppKit
import Darwin

struct AppMemory {
    let name: String
    let bytes: UInt64

    static func topThree() -> [AppMemory] {
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && !$0.isTerminated
        }
        var totals = [pid_t: UInt64]()

        // Take one process-list snapshot, only while the dropdown is open.
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(count) + 256)
        let bufferSize = Int32(pids.count * MemoryLayout<pid_t>.size)
        let actualCount = pids.withUnsafeMutableBytes {
            proc_listallpids($0.baseAddress, bufferSize)
        }
        guard actualCount > 0 else { return [] }

        for pid in pids.prefix(min(Int(actualCount), pids.count)) where pid > 0 {
            // Helpers living inside an app bundle count toward that app.
            // Prefer the longest bundle path if apps are nested inside others.
            // PROC_PIDPATHINFO_MAXSIZE is 4 * MAXPATHLEN in Apple's headers.
            var pathBuffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
            let pathLength = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
            let path = pathLength > 0 ? String(cString: pathBuffer) : ""
            let owner = apps.filter { app in
                app.processIdentifier == pid || app.bundleURL.map {
                    path.hasPrefix($0.path + "/")
                } == true
            }.max {
                ($0.bundleURL?.path.count ?? 0) < ($1.bundleURL?.path.count ?? 0)
            }
            guard let owner else { continue }

            var usage = rusage_info_v2()
            let result = withUnsafeMutablePointer(to: &usage) { pointer in
                pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                    proc_pid_rusage(pid, RUSAGE_INFO_V2, $0)
                }
            }
            // Physical footprint accounts for compressed memory too.
            // Skip inaccessible processes instead of inventing a value.
            if result == 0 {
                totals[owner.processIdentifier, default: 0] += usage.ri_phys_footprint
            }
        }

        return apps.compactMap { app -> AppMemory? in
            guard let bytes = totals[app.processIdentifier],
                  let name = app.localizedName else { return nil }
            return AppMemory(name: name, bytes: bytes)
        }
        .sorted { $0.bytes > $1.bytes }
        .prefix(3)
        .map { $0 }
    }
}
