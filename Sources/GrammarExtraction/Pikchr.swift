import CPikchr
import Foundation

public enum Pikchr {

    public struct RenderError: Error, CustomStringConvertible {
        public var message: String
        public var description: String { message }
    }

    /// The version of the vendored Pikchr renderer.
    public static var version: String { String(cString: pikchr_version()) }

    /// Renders Pikchr source text to SVG markup.
    public static func svg(from source: String) throws(RenderError) -> String {
        var width: Int32 = 0
        var height: Int32 = 0
        guard let raw = pikchr(source, nil, UInt32(PIKCHR_PLAINTEXT_ERRORS), &width, &height) else {
            throw RenderError(message: "pikchr returned no output")
        }
        defer { free(raw) }
        let output = String(cString: raw)
        if width < 0 { throw RenderError(message: output) }
        return output
    }
}
