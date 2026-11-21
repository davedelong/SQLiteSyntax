import SQLite3

/// A SQLite release, e.g. `3.35.0`.
///
/// Give one to `SyntaxBuilder` (or `sql(sqliteVersion:)`) to have building fail for syntax that release
/// can't parse. Get the running library's version with `SQLiteVersion.linked`.
public struct SQLiteVersion: Comparable, Hashable, Sendable, CustomStringConvertible {

    /// The SQLite this process links (`sqlite3_libversion_number()`): the release `sql()` builds for by default.
    public static let linked = SQLiteVersion(number: sqlite3_libversion_number())

    public var major: Int
    public var minor: Int
    public var patch: Int

    /// - Precondition: `major` is at least 0, and `minor` and `patch` are 0 through 999 (SQLite's version
    ///   number packs each into three digits, and comparisons use that number).
    public init(_ major: Int, _ minor: Int, _ patch: Int = 0) {
        precondition(major >= 0 && (0...999).contains(minor) && (0...999).contains(patch),
                     "SQLiteVersion \(major).\(minor).\(patch) is out of range: minor and patch must be 0 through 999")
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
    /// nil if it isn't two or three numbers, or a part is out of range.
    public init?(_ text: String) {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard (2...3).contains(parts.count), parts.allSatisfy({ $0 != nil && $0! >= 0 }),
              parts.dropFirst().allSatisfy({ $0! <= 999 }) else { return nil }
        self.init(parts[0]!, parts[1]!, parts.count == 3 ? parts[2]! : 0)
    }

    /// `major * 1000000 + minor * 1000 + patch`, as `sqlite3_libversion_number()` reports it.
    public var number: Int { major * 1_000_000 + minor * 1_000 + patch }

    public var description: String { "\(major).\(minor).\(patch)" }

    public static func < (a: SQLiteVersion, b: SQLiteVersion) -> Bool { a.number < b.number }
}
