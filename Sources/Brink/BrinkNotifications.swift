import AppKit
import SwiftUI
import UserNotifications

/// System notifications, the way Brink sent them: a banner in Notification
/// Center when a session finishes or waits on you, when a limit is reached
/// or resets, and when a focus block ends. The notch's own peek, cards and
/// sounds stay as they are; this is the layer that reaches you on another
/// screen or with the notch hidden.
enum BrinkNotifications {
    static let sessionsKey = "brinkNotifySessions"
    static let limitsKey = "brinkNotifyLimits"
    static let focusKey = "brinkNotifyFocus"

    static var sessions: Bool { UserDefaults.standard.object(forKey: sessionsKey) as? Bool ?? true }
    static var limits: Bool { UserDefaults.standard.object(forKey: limitsKey) as? Bool ?? true }
    static var focus: Bool { UserDefaults.standard.object(forKey: focusKey) as? Bool ?? true }

    /// Asked once, at launch, so the first banner is not also the first
    /// permission dialog.
    static func requestAuthorizationIfNeeded() {
        guard sessions || limits || focus else { return }
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    /// A banner, or the System Settings pane when banners are switched off
    /// for Codenotch there.
    static func test() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { ok, _ in
                    if ok { post(title: L10n.t("Codenotch notifications are on"), body: L10n.t("This is what one looks like.")) }
                }
            case .denied:
                DispatchQueue.main.async {
                    let id = Bundle.main.bundleIdentifier ?? "com.vinz.codenotch"
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(id)") {
                        NSWorkspace.shared.open(url)
                    }
                }
            default:
                post(title: L10n.t("Codenotch notifications are on"), body: L10n.t("This is what one looks like."))
            }
        }
    }

    static func sessionEnded(name: String, blocked: Bool) {
        guard sessions else { return }
        post(title: blocked ? L10n.t("\(name) is waiting on you") : L10n.t("\(name) finished"),
             body: blocked ? L10n.t("The agent stopped to ask you something.") : L10n.t("The agent's turn is done."),
             id: "session|\(name)")
    }

    static func post(title: String, body: String, id: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let identifier = "brink|\(id ?? "")|\(Int(Date().timeIntervalSince1970))"
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil))
    }
}

/// The switches, as a section of Settings → Notifications.
struct BrinkNotificationsSection: View {
    @AppStorage(BrinkNotifications.sessionsKey) private var sessions = true
    @AppStorage(BrinkNotifications.limitsKey) private var limits = true
    @AppStorage(BrinkNotifications.focusKey) private var focus = true

    var body: some View {
        Section(L10n.t("System notifications")) {
            Toggle(L10n.t("Session finished or waiting on you"), isOn: $sessions)
            Toggle(L10n.t("Limit reached and limit reset"), isOn: $limits)
            Toggle(L10n.t("Focus block done, long focus"), isOn: $focus)
            HStack {
                Text(L10n.t("Banners in Notification Center, on top of the notch's own peek, cards and sounds: they reach you on another display or with the notch hidden."))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button(L10n.t("Send a test")) { BrinkNotifications.test() }
            }
        }
        .onChange(of: sessions) { _, _ in BrinkNotifications.requestAuthorizationIfNeeded() }
        .onChange(of: limits) { _, _ in BrinkNotifications.requestAuthorizationIfNeeded() }
        .onChange(of: focus) { _, _ in BrinkNotifications.requestAuthorizationIfNeeded() }
    }
}
