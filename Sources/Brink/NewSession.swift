import AppKit
import Foundation

/// "New session…": run the user's launcher (a shell command such as `p`, or
/// `claude`) in a new window of the terminal they use.
enum NewSession {
    static let commandKey = "brinkNewSessionCommand"
    static let terminalKey = "brinkNewSessionTerminal"   // bundle id, "" = automatic

    static var command: String {
        get { UserDefaults.standard.string(forKey: commandKey)?.trimmingCharacters(in: .whitespaces) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: commandKey) }
    }
    static var terminal: String {
        get { UserDefaults.standard.string(forKey: terminalKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: terminalKey) }
    }

    static let terminals: [(bundleID: String, name: String)] = [
        ("com.mitchellh.ghostty", "Ghostty"), ("com.googlecode.iterm2", "iTerm2"), ("com.apple.Terminal", "Terminal"),
    ]
    static func installed() -> [(bundleID: String, name: String)] {
        terminals.filter { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.bundleID) != nil }
    }

    @MainActor static func launch() {
        let cmd = command.isEmpty ? "claude" : command
        let choice = terminal.isEmpty ? (installed().first?.bundleID ?? "com.apple.Terminal") : terminal
        let escaped = cmd.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let script: String
        switch choice {
        case "com.mitchellh.ghostty":
            script = """
            tell application "Ghostty"
                activate
                set w to new window
                delay 0.8
                set t to focused terminal of selected tab of front window
                input text "\(escaped)" to t
                send key "enter" to t
            end tell
            """
        case "com.googlecode.iterm2":
            script = """
            tell application "iTerm2"
                activate
                create window with default profile
                delay 0.5
                tell current session of current window to write text "\(escaped)"
            end tell
            """
        default:
            script = "tell application \"Terminal\"\nactivate\ndo script \"\(escaped)\"\nend tell"
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            p.arguments = ["-e", script]
            try? p.run()
        }
    }
}
