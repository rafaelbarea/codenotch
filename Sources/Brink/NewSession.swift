import AppKit
import Foundation

/// "New session…": run the user's launcher (a shell command such as `p`, or
/// `claude`) in a new window of the terminal they use.
enum NewSession {
    static let commandKey = "brinkNewSessionCommand"
    static let terminalKey = "brinkNewSessionTerminal"   // bundle id, "" = automatic
    /// What a double click on a ring runs, with the account already chosen.
    /// `{cmd}` is the CLI on that account (`claude`, or `env CLAUDE_CONFIG_DIR=… claude`),
    /// `{id}` the account id, `{dir}` its config directory, `{provider}` claude or codex.
    /// Empty runs `{cmd}` itself.
    static let accountCommandKey = "brinkNewSessionAccountCommand"

    static var accountCommand: String {
        get { UserDefaults.standard.string(forKey: accountCommandKey)?.trimmingCharacters(in: .whitespaces) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: accountCommandKey) }
    }

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

    @MainActor static func launch() { launch(account: nil) }

    /// With an account: the terminal opens on that login (its config
    /// directory exported the way the CLI reads it) before the launcher runs.
    @MainActor static func launch(account: CostAccount?) {
        var cmd = command.isEmpty ? "claude" : command
        if let account {
            // The CLI on that login, spelled the way a shell launcher expects
            // (accounts.json uses the same form): the default directory is
            // the bare command, any other is exported in front of it.
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            let dir = account.configDirectory.path
            let codex = account.provider == "codex"
            let bare = codex ? "codex" : "claude"
            let cli = dir == "\(home)/\(codex ? ".codex" : ".claude")"
                ? bare : "env \(codex ? "CODEX_HOME" : "CLAUDE_CONFIG_DIR")=\(dir) \(bare)"
            let template = accountCommand
            cmd = template.isEmpty ? cli : template
                .replacingOccurrences(of: "{cmd}", with: cli)
                .replacingOccurrences(of: "{id}", with: account.id)
                .replacingOccurrences(of: "{dir}", with: dir)
                .replacingOccurrences(of: "{provider}", with: account.provider)
        }
        run(cmd)
    }

    /// Run a command in a new window of the chosen terminal.
    @MainActor static func run(_ cmd: String) {
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
