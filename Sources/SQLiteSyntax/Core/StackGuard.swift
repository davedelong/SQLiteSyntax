#if canImport(Darwin)
import Darwin
#endif

/// Stops parsing and building before deeply nested SQL overflows the thread's stack.
///
/// Both are recursive, so how deep they can go depends on the thread's stack size (512 KB on Swift's
/// cooperative threads, 8 MB on the main thread) and on the build (debug frames are much larger). A
/// fixed nesting limit would either reject SQL that SQLite accepts or still crash on small stacks, so
/// they stop when less than `reserve` bytes of the current thread's stack remain.
enum StackGuard {
    /// Stack to keep free, for the frames between two checks and for unwinding after the error.
    static let reserve = 128 * 1024

    /// Whether the current thread's stack has more than `reserve` bytes left.
    static var hasRoom: Bool {
        #if canImport(Darwin)
        let thread = pthread_self()
        let top = UInt(bitPattern: pthread_get_stackaddr_np(thread))   // the stack grows down from here
        let limit = top - UInt(pthread_get_stacksize_np(thread)) + UInt(reserve)
        var marker: UInt8 = 0
        return withUnsafeMutablePointer(to: &marker) { UInt(bitPattern: $0) } > limit
        #else
        return true
        #endif
    }
}
