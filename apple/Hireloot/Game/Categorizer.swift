import Foundation

/// Keyword categorizer (same rules as categorizer.js). Only ever *suggests* a category;
/// the player has to tap the chip to apply it.
enum Categorizer {
    private static let rules: [(String, [String])] = [
        ("network", ["networking", "coffee", "咖啡", "校友", "alumni", "内推", "referral", "linkedin", "领英",
                     "联系", "发消息", "私信", "聚会", "meetup", "认识", "加微信", "约饭", "约聊", "人脉", "mentor", "导师", "活动", "career fair", "招聘会"]),
        ("apply", ["投递", "投简历", "申请", "apply", "application", "网申", "海投", "投了", "submit", "职位", "jd", "job"]),
        ("resume", ["简历", "resume", "cv", "cover letter", "求职信", "作品集", "portfolio", "个人主页", "自我介绍信"]),
        ("prep", ["面试准备", "准备面试", "刷题", "leetcode", "力扣", "八股", "模拟面试", "mock", "行为面", "behavioral", "bq",
                  "system design", "系统设计", "复习", "背", "练习", "算法题", "star", "面经", "case"]),
        ("project", ["项目", "project", "代码", "code", "coding", "github", "开发", "实现", "部署", "deploy", "demo", "feature",
                     "bug", "重构", "kaggle", "论文", "paper", "模型", "训练", "side project", "app", "网站", "api"])
    ]

    static func suggest(_ text: String) -> String? {
        let t = text.lowercased()
        var best: String?, bestScore = 0
        for (key, words) in rules {
            var s = 0
            // JS counts string length in UTF-16 units; for these words that equals Character count
            for w in words where t.contains(w) { s += w.count >= 3 ? 2 : 1 }
            if s > bestScore { best = key; bestScore = s }
        }
        return best
    }
}
