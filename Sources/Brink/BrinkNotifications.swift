import AppKit
import SwiftUI
import UserNotifications

/// One choice for every notification the app makes: a banner in the Mac's
/// Notification Center, or the notch alone (its peek, its cards and its
/// sounds). Which events notify at all is decided per event, in the same
/// pane, as before.
enum BrinkNotifications {
    enum Channel: String, CaseIterable, Identifiable {
        case notch, mac
        var id: String { rawValue }
        var title: String {
            switch self {
            case .notch: return L10n.t("In the notch")
            case .mac:   return L10n.t("Mac notifications")
            }
        }
        var explanation: String {
            switch self {
            case .notch: return L10n.t("The notch opens for a moment or shows a card, with the sound you chose. Nothing reaches Notification Center.")
            case .mac:   return L10n.t("A banner in Notification Center, which reaches you on another display or with the notch hidden. The notch stays quiet; sounds still play.")
            }
        }
    }

    static let channelKey = "brinkNotificationChannel"
    static let focusKey = "brinkNotifyFocus"

    static var channel: Channel {
        Channel(rawValue: UserDefaults.standard.string(forKey: channelKey) ?? "") ?? .mac
    }
    static var usesMac: Bool { channel == .mac }
    /// Whether focus blocks notify at all (the per-event switch).
    static var focus: Bool { UserDefaults.standard.object(forKey: focusKey) as? Bool ?? true }

    /// Set by the app: what "notify in the notch" does for an event that has
    /// no card of its own (a focus block ending): the peek, and the chime.
    static var notchAlert: (() -> Void)?

    /// Asked once, at launch, so the first banner is not also the first
    /// permission dialog.
    static func requestAuthorizationIfNeeded() {
        guard usesMac else { return }
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
        post(title: blocked ? L10n.t("\(name) is waiting on you") : L10n.t("\(name) finished"),
             body: blocked ? L10n.t("The agent stopped to ask you something.") : L10n.t("The agent's turn is done."),
             id: "session|\(name)")
    }

    /// An event with no notch card of its own: a banner on the Mac channel,
    /// the notch's peek and chime otherwise.
    static func alert(title: String, body: String) {
        if usesMac {
            post(title: title, body: body)
        } else {
            DispatchQueue.main.async { notchAlert?() }
        }
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

/// The channel, as the first group of Settings → Notifications.
struct BrinkNotificationsSection: View {
    @AppStorage(BrinkNotifications.channelKey) private var channel = BrinkNotifications.Channel.mac.rawValue

    private var current: BrinkNotifications.Channel { .init(rawValue: channel) ?? .mac }

    var body: some View {
        SettingsGroup(title: L10n.t("Where to notify"), footer: current.explanation) {
            SettingsRow(title: L10n.t("Channel"),
                        description: L10n.t("One choice for every notification. Which events notify is decided below.")) {
                Picker("", selection: $channel) {
                    ForEach(BrinkNotifications.Channel.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .labelsHidden().pickerStyle(.segmented).fixedSize()
            }
            if current == .mac {
                SettingsRow(title: L10n.t("Send a test"), description: L10n.t("Opens System Settings when banners are off for Codenotch.")) {
                    Button(L10n.t("Send")) { BrinkNotifications.test() }
                }
            }
        }
        .onChange(of: channel) { _, _ in BrinkNotifications.requestAuthorizationIfNeeded() }
    }
}

/// The focus block's own switch, beside the other events.
struct BrinkFocusNotificationGroup: View {
    @AppStorage(BrinkNotifications.focusKey) private var focus = true

    var body: some View {
        SettingsGroup(title: L10n.t("When a focus block ends")) {
            SettingsToggleRow(title: L10n.t("Notify"),
                              description: L10n.t("When the block reaches its target, and again every hour a block runs past two."),
                              isOn: $focus)
        }
    }
}
