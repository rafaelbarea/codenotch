import SwiftUI

/// Settings → Brink: how each account is paid, where tasks come from, the
/// focus block length, and what "New session…" runs.
struct BrinkSettingsPane: View {
    @ObservedObject var accounts: CostAccountStore = .shared
    @ObservedObject var prices: PriceTable = .shared
    @ObservedObject var catalog: PlanCatalog = .shared
    @ObservedObject var todos: TodoStore = .shared
    @ObservedObject var focus: FocusStore = .shared
    @State private var command = NewSession.command
    @State private var terminal = NewSession.terminal
    @State private var accountCommand = NewSession.accountCommand


    var body: some View {
        SettingsPage {
            SettingsGroup(title: L10n.t("Market data"),
                          footer: L10n.t("Refreshed once a day, no account needed: exchange rate from open.er-api.com, per-token prices from OpenRouter. Plans live in plans.json, editable.")) {
                SettingsRow(title: L10n.t("Exchange rate")) {
                    Text(prices.rateKnown ? L10n.t("1 USD = \(MoneyFormat.string(prices.rate, currency: prices.currency))") : L10n.t("Not fetched yet"))
                        .foregroundStyle(.secondary)
                }
                SettingsRow(title: L10n.t("Per-token prices")) {
                    Text(L10n.t("\(prices.prices.count) models")).foregroundStyle(.secondary)
                }
                SettingsRow(title: L10n.t("Plan catalog")) {
                    HStack(spacing: 8) {
                        Text(L10n.t("\(catalog.plans.count) plans")).foregroundStyle(.secondary)
                        Button(L10n.t("Open catalog")) { NSWorkspace.shared.activateFileViewerSelecting([PlanCatalog.fileURL]) }
                    }
                }
                SettingsRow(title: L10n.t("Refresh now")) {
                    Button(L10n.t("Refresh")) { prices.refreshIfDue(force: true); catalog.refreshIfDue(force: true) }
                }
            }
            SettingsGroup(title: L10n.t("Tasks"),
                          footer: L10n.t("Switch the Tasks ring on in Accounts. Things 3 needs the Automation permission; Reminders asks for access to your reminders.")) {
                SettingsRow(title: L10n.t("Source")) {
                    Picker("", selection: Binding(get: { todos.source }, set: { todos.source = $0 })) {
                        ForEach(TaskSource.allCases.filter { $0.isAvailable }) { Text($0.title).tag($0) }
                    }.labelsHidden().pickerStyle(.menu).fixedSize()
                }
                SettingsRow(title: L10n.t("Third tab")) {
                    Picker("", selection: Binding(get: { todos.customList }, set: { todos.customList = $0 })) {
                        ForEach(todos.source.builtinLists + todos.lists, id: \.self) { Text($0).tag($0) }
                    }.labelsHidden().pickerStyle(.menu).fixedSize()
                }
                SettingsRow(title: L10n.t("Focus block")) {
                    Picker("", selection: Binding(get: { focus.targetMinutes }, set: { focus.targetMinutes = $0 })) {
                        ForEach([15, 25, 30, 45, 50, 60, 90], id: \.self) { Text(L10n.t("\($0) min")).tag($0) }
                    }.labelsHidden().pickerStyle(.menu).fixedSize()
                }
            }
            SettingsGroup(title: L10n.t("New session"),
                          footer: L10n.t("Runs in a new terminal window from the menu's New session… (⌘N). Put your own launcher here, e.g. a shell function that picks the project and the account.")) {
                SettingsRow(title: L10n.t("Terminal")) {
                    Picker("", selection: $terminal) {
                        Text(L10n.t("Automatic")).tag("")
                        ForEach(NewSession.installed(), id: \.bundleID) { Text($0.name).tag($0.bundleID) }
                    }.labelsHidden().pickerStyle(.menu).fixedSize().onChange(of: terminal) { _, v in NewSession.terminal = v }
                }
                SettingsRow(title: L10n.t("Command")) {
                    TextField("", text: $command, prompt: Text("claude"))
                        .textFieldStyle(.roundedBorder).frame(width: 220)
                        .onChange(of: command) { _, v in NewSession.command = v }
                }
                SettingsRow(title: L10n.t("Double-click on a ring"),
                            description: L10n.t("Runs with the ring's account already chosen. {cmd} is that account's CLI (claude, or env CLAUDE_CONFIG_DIR=… claude), {id} its id, {dir} its config directory, {provider} claude or codex. Empty runs {cmd}.")) {
                    TextField("", text: $accountCommand, prompt: Text("{cmd}"))
                        .textFieldStyle(.roundedBorder).frame(width: 220)
                        .onChange(of: accountCommand) { _, v in NewSession.accountCommand = v }
                }
            }
        }
    }

}
