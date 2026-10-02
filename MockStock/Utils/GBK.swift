import Foundation

/// 腾讯行情接口返回 GBK 编码，需转成 UTF-8 才能正确显示中文
enum GBK {
    /// GB18030 编码（兼容 GBK / GB2312）
    static let encoding = String.Encoding(rawValue: 0x80000632)

    static func decode(_ data: Data) -> String {
        if let s = String(data: data, encoding: encoding) {
            return s
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
