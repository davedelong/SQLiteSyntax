#if canImport(Darwin)
import Darwin
#endif

import Foundation

/// Get information on how much stack space is left.
///
/// Both parsing and building are recursive, so how deep they can go depends on the thread's stack size.
/// (512 KB on Swift's cooperative threads, 8 MB on the main thread) and on the build (debug frames are much larger).
/// A fixed nesting limit would either reject SQL that SQLite accepts or still crash on small stacks, so
/// they stop when fewer than `reserveBytes` bytes of the current thread's stack remain.
extension Thread {

    private static let reserveBytes = 128 * 1024

    var remainingStackSpace: UInt {
        #if canImport(Darwin)
        let thread = pthread_self()
        let top = UInt(bitPattern: pthread_get_stackaddr_np(thread))
        let end = top - UInt(self.stackSize)

        var currentStackSpot: UInt8 = 0
        return withUnsafeMutablePointer(to: &currentStackSpot) {
            return UInt(bitPattern: $0) - end
        }
        #else
        return 0
        #endif
    }

    var hasRemainingStackSpace: Bool {
        return remainingStackSpace >= Self.reserveBytes
    }

}
