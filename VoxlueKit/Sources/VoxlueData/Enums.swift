import Foundation

/// 胶囊的收件人。
public enum Recipient: String, Codable, CaseIterable, Sendable {
    case me           // 自己
    case circle       // 声音圈
    case publicMap    // 公开（v1.1 落地）
}

/// 胶囊的显影状态机。
public enum CapsuleState: String, Codable, CaseIterable, Sendable {
    case buried       // 已埋下 · 潜伏
    case developing   // 显影中 · 灵动岛 + 霜化动效
    case developed    // 已显影 · 等你听
    case opened       // 已开启
}

/// 声音圈成员角色。
public enum CircleRole: String, Codable, CaseIterable, Sendable {
    case owner
    case member
}
