import Foundation

/// Buffer bytes until a whole line is available, preserving split UTF-8 and progress markers.
struct ScriptOutputDecoder {
    private var pending = Data()

    mutating func append(_ data: Data, finishing: Bool = false) -> String {
        pending.append(data)
        let end: Data.Index
        if finishing {
            end = pending.endIndex
        } else if let newline = pending.lastIndex(of: 10) {
            end = pending.index(after: newline)
        } else {
            return ""
        }
        let text = String(decoding: pending[..<end], as: UTF8.self)
        pending.removeSubrange(..<end)
        return text
    }
}
