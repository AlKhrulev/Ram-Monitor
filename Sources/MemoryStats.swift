import Foundation
import Darwin

// One snapshot of system-wide memory. A missing value means the OS read failed.
struct MemoryStats {
    let usedBytes: UInt64?
    let cachedBytes: UInt64?
    let swapBytes: UInt64?
    let pressure: Pressure

    enum Pressure: String {
        case normal = "Normal"
        case warning = "Warning"
        case critical = "Critical"
        case unknown = "Unavailable"
    }

    static func read() -> MemoryStats {
        var vm = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        let result = withUnsafeMutablePointer(to: &vm) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }

        let pageSize = UInt64(getpagesize())
        // Purgeable pages are reclaimable, so don't include them in used RAM.
        let appPages = UInt64(vm.internal_page_count) - min(
            UInt64(vm.internal_page_count), UInt64(vm.purgeable_count)
        )
        let usedPages = appPages + UInt64(vm.wire_count) + UInt64(vm.compressor_page_count)
        let cachedPages = UInt64(vm.external_page_count) + UInt64(vm.purgeable_count)

        var swap = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        let swapResult = sysctlbyname("vm.swapusage", &swap, &swapSize, nil, 0)

        // Read the current OS pressure level, not a percentage of occupied RAM.
        // If this counter is unavailable on a macOS version, don't guess.
        var level: Int32 = 0
        var levelSize = MemoryLayout<Int32>.size
        let pressureResult = sysctlbyname(
            "kern.memorystatus_vm_pressure_level", &level, &levelSize, nil, 0
        )
        let pressure: Pressure
        switch pressureResult == 0 ? level : 0 {
        case 1: pressure = .normal
        case 2: pressure = .warning
        case 4: pressure = .critical
        default: pressure = .unknown
        }

        return MemoryStats(
            usedBytes: result == KERN_SUCCESS ? usedPages * pageSize : nil,
            cachedBytes: result == KERN_SUCCESS ? cachedPages * pageSize : nil,
            swapBytes: swapResult == 0 ? swap.xsu_used : nil,
            pressure: pressure
        )
    }
}

// Binary units (1,073,741,824 bytes), labeled GB like Activity Monitor.
func gigabytes(_ bytes: UInt64?) -> String {
    guard let bytes else { return "—" }
    return String(format: "%.2f", Double(bytes) / 1_073_741_824)
}
