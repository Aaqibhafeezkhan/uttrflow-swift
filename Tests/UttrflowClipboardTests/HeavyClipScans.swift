// The parent suite that runs the multi-megabyte clip scans one at a time.

import Testing

/// Holds the CPU-heavy clip scans, serialized so together they take one cooperative thread, not the whole pool.
@Suite(.serialized)
enum HeavyClipScans {}
