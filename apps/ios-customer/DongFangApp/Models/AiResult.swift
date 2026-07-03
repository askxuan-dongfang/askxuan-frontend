//
//  AiResult.swift
//  DongFangApp
//
//  AI 问事结果模型（用于对话中 AI 解析的卜卦/命理结果展示）。
//

import Foundation

/// AI 问事结果
struct AiResult: Codable, Identifiable, Hashable {
    let id: String
    /// 问事主题
    let topic: String
    /// 问题类型：运势/姻缘/事业/健康/学业
    let category: String
    /// AI 解析结论
    let summary: String
    /// 详细解读
    let detail: String
    /// 建议
    let advice: String
    /// 吉凶：吉/中吉/小吉/平/凶
    let fortune: String
    /// 生成时间
    let createdAt: String

    var fortuneColor: String {
        switch fortune {
        case "吉":   return "stateSuccess"
        case "中吉": return "accentDefault"
        case "小吉": return "brandLight"
        case "平":   return "textSecondary"
        default:     return "stateWarning"
        }
    }
}

extension AiResult {
    static let mock: AiResult = AiResult(
        id: "AI001",
        topic: "近期运势",
        category: "运势",
        summary: "近半月运势上扬，贵人相助，宜把握机遇。",
        detail: "卦象显示「地天泰」，天地交泰，万物通达。近期有贵人出现，事业与人际均有起色。财帛宫有吉星高照，可有意外之财，但需注意不可贪多。健康方面总体平稳，注意作息。",
        advice: "宜：祈福、会友、签约。忌：远行、口舌之争。",
        fortune: "中吉",
        createdAt: "2026-07-01 10:00:00"
    )
}
