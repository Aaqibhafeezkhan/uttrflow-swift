// This Mac in one line for the Diagnostics tab: macOS version, chip and memory.

import Darwin
import Foundation

/// Reads this Mac's macOS version, chip and memory once, for the Diagnostics tab and its report.
enum MachineDescription {
    /// "26.1 · Apple M3 · 16 GB", or as much of it as the system answers.
    static let current: String? = {
        let info = ProcessInfo.processInfo
        let version = info.operatingSystemVersion
        let system =
            version.patchVersion == 0
            ? "\(version.majorVersion).\(version.minorVersion)"
            : "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        let memory = "\(info.physicalMemory / 1_073_741_824) GB"
        return [system, chip, memory].compactMap(\.self).joined(separator: " · ")
    }()

    /// The processor's marketing name, such as "Apple M3".
    private static var chip: String? {
        var size = 0
        guard sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0) == 0, size > 1 else {
            return nil
        }
        var bytes = [CChar](repeating: 0, count: size)
        guard sysctlbyname("machdep.cpu.brand_string", &bytes, &size, nil, 0) == 0 else { return nil }
        return String(decoding: bytes.prefix { $0 != 0 }.map(UInt8.init(bitPattern:)), as: UTF8.self)
    }
}
