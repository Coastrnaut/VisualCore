// ProcessMemory — feature 192 T-U06-026 (UA-F06; FR-U06-033). The memory footprint of the app's process, read
// through the public Mach interface `task_info`. It is the figure the system uses to judge an app's memory use.
// The value is a measurement for the performance record; nothing is decided by it at run time.
import Darwin
import Foundation

/// Reads the memory footprint of the current process.
public enum ProcessMemory {
    /// The footprint of the process in bytes, or nil when the system does not give it.
    public static func footprint() -> Int? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let bytes = info.phys_footprint
        guard bytes > 0, bytes <= UInt64(Int.max) else { return nil }
        return Int(bytes)
    }
}
