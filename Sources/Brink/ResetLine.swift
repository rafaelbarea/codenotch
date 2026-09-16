import Foundation

/// The short countdown under a ring's percent: "38m", "2h 10m", "3d 4h".
enum BrinkResetLine {
    static func text(until resetsAt: Date, now: Date = Date()) -> String {
        let seconds = resetsAt.timeIntervalSince(now)
        guard seconds > 0 else { return L10n.t("Resetting…") }
        let minutes = max(1, Int((seconds / 60).rounded()))
        let hours = minutes / 60
        let days = hours / 24
        if days > 0 { return "\(days)d \(hours % 24)h" }
        if hours > 0 { return "\(hours)h \(minutes % 60)m" }
        return "\(minutes)m"
    }
}
