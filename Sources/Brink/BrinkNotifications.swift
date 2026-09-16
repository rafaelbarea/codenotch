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
    /// no card of its own (a focus block ending, a test): a card beside the
    /// notch with these words, and the chime. Returns false when the notch
    /// could not show it (hidden), so the caller can fall back to a banner.
    static var notchAlert: ((_ title: String, _ body: String, _ sound: String?) -> Bool)?

    /// The focus block's sound; empty plays nothing. Unset, it borrows the
    /// session's "finished" sound.
    static let focusSoundKey = "brinkFocusSoundName"
    static var focusSound: String? { UserDefaults.standard.string(forKey: focusSoundKey) }

    /// Without a delegate, macOS delivers an app's own notifications quietly
    /// to the list while that app is frontmost: the test sent from Settings,
    /// with the Settings window in front, never showed. The delegate asks for
    /// the banner and the sound whatever is in front.
    private final class Presenter: NSObject, UNUserNotificationCenterDelegate {
        func userNotificationCenter(_ center: UNUserNotificationCenter,
                                    willPresent notification: UNNotification,
                                    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
            completionHandler([.banner, .list, .sound])
        }
    }
    private static let presenter = Presenter()

    static func installPresenter() {
        UNUserNotificationCenter.current().delegate = presenter
    }

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
    /// for Codenotch there. On the notch channel, the peek and the chime.
    static func test() {
        guard usesMac else {
            DispatchQueue.main.async {
                _ = notchAlert?(L10n.t("Codenotch test"), L10n.t("This is what one looks like."), nil)
            }
            return
        }
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            Log.usage.info("notifications: authorization \(settings.authorizationStatus.rawValue, privacy: .public) alerts \(settings.alertSetting.rawValue, privacy: .public) style \(settings.alertStyle.rawValue, privacy: .public) centre \(settings.notificationCenterSetting.rawValue, privacy: .public) sound \(settings.soundSetting.rawValue, privacy: .public)")
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { ok, _ in
                    if ok { post(title: L10n.t("Codenotch test"), body: L10n.t("This is what one looks like.")) }
                }
            case .denied:
                DispatchQueue.main.async {
                    let id = Bundle.main.bundleIdentifier ?? "com.vinz.codenotch"
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(id)") {
                        NSWorkspace.shared.open(url)
                    }
                }
            default:
                post(title: L10n.t("Codenotch test"), body: L10n.t("This is what one looks like."))
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
    static func alert(title: String, body: String, sound: String? = nil) {
        if usesMac {
            post(title: title, body: body)
        } else {
            DispatchQueue.main.async {
                if notchAlert?(title, body, sound) != true { post(title: title, body: body) }
            }
        }
    }

    static func post(title: String, body: String, id: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let identifier = "brink|\(id ?? "")|\(Int(Date().timeIntervalSince1970))"
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil)) { error in
            if let error {
                Log.usage.error("notification not accepted: \(error.localizedDescription, privacy: .public)")
            } else {
                Log.usage.info("notification queued: \(title, privacy: .public)")
            }
        }
    }

    /// `defaults write com.vinz.codenotch brinkNotifyTestOnLaunch -bool true`
    /// sends one test a few seconds after launch and clears the flag: a way
    /// to exercise the path without a hand on the button.
    static func testOnLaunchIfAsked() {
        guard UserDefaults.standard.bool(forKey: "brinkNotifyTestOnLaunch") else { return }
        UserDefaults.standard.removeObject(forKey: "brinkNotifyTestOnLaunch")
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { test() }
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
            SettingsRow(title: L10n.t("Send a test"),
                        description: current == .mac
                            ? L10n.t("Opens System Settings when banners are off for Codenotch.")
                            : L10n.t("The notch opens for a moment, with the session sound.")) {
                Button(L10n.t("Send")) { BrinkNotifications.test() }
            }
        }
        .onChange(of: channel) { _, _ in BrinkNotifications.requestAuthorizationIfNeeded() }
    }
}
