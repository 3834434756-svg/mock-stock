import Foundation

/// 腾讯搜索接口返回的并不是真正的 UTF-8 中文，而是 `\u817e\u8baf` 这样的
/// **字面转义序列**（纯 ASCII）。必须手工还原，否则界面上会显示成一串乱码。
///
/// 注意：这跟行情接口的 GBK 编码是两回事，别混用。
enum UnicodeEscape {
    static func decode(_ s: String) -> String {
        guard s.contains("\\u") else { return s }

        var out = String()
        out.reserveCapacity(s.count)
        var i = s.startIndex

        while i < s.endIndex {
            if s[i] == "\\", s.index(after: i) < s.endIndex, s[s.index(after: i)] == "u" {
                let hexStart = s.index(i, offsetBy: 2)
                if let hexEnd = s.index(hexStart, offsetBy: 4, limitedBy: s.endIndex) {
                    let hex = String(s[hexStart..<hexEnd])
                    if let code = UInt32(hex, radix: 16), let scalar = Unicode.Scalar(code) {
                        out.unicodeScalars.append(scalar)
                        i = hexEnd
                        continue
                    }
                }
            }
            out.append(s[i])
            i = s.index(after: i)
        }
        return out
    }
}
