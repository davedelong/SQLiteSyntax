/// A SQLite release, e.g. `3.35.0`.
///
/// Give one to `SyntaxBuilder` (or `sql(sqliteVersion:)`) to have building fail for syntax that release
/// can't parse. Get the running library's version with `SQLiteVersion(number: sqlite3_libversion_number())`.
public struct SQLiteVersion: Comparable, Hashable, Sendable, CustomStringConvertible {
    public var major: Int
    public var minor: Int
    public var patch: Int

    public init(_ major: Int, _ minor: Int, _ patch: Int = 0) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    /// From SQLite's integer form, `major * 1000000 + minor * 1000 + patch`
    /// (`sqlite3_libversion_number()`, `SQLITE_VERSION_NUMBER`), e.g. `3035000`.
    public init<N: BinaryInteger>(number: N) {
        let n = Int(number)
        self.init(n / 1_000_000, n / 1_000 % 1_000, n % 1_000)
    }

    /// From text such as `3.35.0` (`sqlite3_libversion()`, `SELECT sqlite_version()`); a missing patch is 0.
    public init?(_ text: String) {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard (2...3).contains(parts.count), parts.allSatisfy({ $0 != nil && $0! >= 0 }) else { return nil }
        self.init(parts[0]!, parts[1]!, parts.count == 3 ? parts[2]! : 0)
    }

    /// `major * 1000000 + minor * 1000 + patch`, as `sqlite3_libversion_number()` reports it.
    public var number: Int { major * 1_000_000 + minor * 1_000 + patch }

    public var description: String { "\(major).\(minor).\(patch)" }

    public static func < (a: SQLiteVersion, b: SQLiteVersion) -> Bool { a.number < b.number }
}
