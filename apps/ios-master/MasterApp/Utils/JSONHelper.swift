//
//  JSONHelper.swift
//  MasterApp
//
//  JSON 编解码辅助。
//

import Foundation

/// JSON 辅助工具
enum JSONHelper {

    /// 将 Encodable 对象编码为 JSON 字符串（调试用）
    static func encodeToString<T: Encodable>(_ value: T) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes, .sortedKeys]
        guard let data = try? encoder.encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// 将 JSON 字符串解码为指定类型
    static func decode<T: Decodable>(_ type: T.Type, from string: String) -> T? {
        guard let data = string.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    /// 解析 JSON 字符串为字典
    static func toDict(_ string: String) -> [String: Any]? {
        guard let data = string.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
