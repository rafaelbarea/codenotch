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

    private var currencyName: String { Locale.current.localizedString(forCurrencyCode: prices.currency) ?? prices.currency }

    var body: some View {
        Form {
            Section(L10n.t("Plans")) {
                ForEach(accounts.accounts) { a in
                    let auto = a.monthlyLocal(rate: prices.rate)
                    LabeledContent {
                        HStack(spacing: 8) {
                            if a.billing == .subscription {
                                TextField("", value: Binding(get: { a.monthlyPrice == 0 ? nil : a.monthlyPrice },
                                                             set: { accounts.setMonthlyPrice(a.id, $0 ?? 0) }),
                                          format: .number, prompt: Text(auto > 0 ? MoneyFormat.string(auto, currency: prices.currency) : "—"))
                                    .frame(width: 100).multilineTextAlignment(.trailing)
                            }
                            Picker("", selection: Binding(get: { a.billing }, set: { accounts.setBilling(a.id, $0) })) {
                                ForEach(CostAccount.Billing.allCases) { Text($0.title).tag($0) }
                            }.labelsHidden().frame(width: 170)
                        }
                    } label: {
                        // The name is yours to change: it is what the notch,
                        // the cards and the shell launcher call this login.
                        TextField("", text: Binding(get: { a.name }, set: { accounts.setName(a.id, $0) }),
                                  prompt: Text(accounts.defaultName(a.id)))
                            .textFieldStyle(.plain)
                    }
                    Text(planDetail(a)).font(.caption).foregroundStyle(.secondary)
                }
                Text(L10n.t("Detected from each login once a day. A week of the plan costs the price ÷ 4.35; a project that used 4% of the weekly allowance spent 4% of that. Amounts in \(currencyName), your Mac's currency. Type the amount you actually pay to override the list price."))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Section(L10n.t("Market data")) {
                LabeledContent(L10n.t("Exchange rate"), value: prices.rateKnown ? L10n.t("1 USD = \(MoneyFormat.string(prices.rate, currency: prices.currency))") : L10n.t("Not fetched yet"))
                LabeledContent(L10n.t("Per-token prices"), value: L10n.t("\(prices.prices.count) models"))
                LabeledContent(L10n.t("Plan catalog"), value: L10n.t("\(catalog.plans.count) plans"))
                HStack {
                    Button(L10n.t("Refresh now")) { prices.refreshIfDue(force: true); catalog.refreshIfDue(force: true) }
                    Button(L10n.t("Open catalog")) { NSWorkspace.shared.activateFileViewerSelecting([PlanCatalog.fileURL]) }
                }
                Text(L10n.t("Refreshed once a day, no account needed: exchange rate from open.er-api.com, per-token prices from OpenRouter. Plans live in plans.json, editable."))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Section(L10n.t("Tasks")) {
                Picker(L10n.t("Source"), selection: Binding(get: { todos.source }, set: { todos.source = $0 })) {
                    ForEach(TaskSource.allCases.filter { $0.isAvailable }) { Text($0.title).tag($0) }
                }.pickerStyle(.menu)
                Picker(L10n.t("Third tab"), selection: Binding(get: { todos.customList }, set: { todos.customList = $0 })) {
                    ForEach(todos.source.builtinLists + todos.lists, id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.menu)
                Picker(L10n.t("Focus block"), selection: Binding(get: { focus.targetMinutes }, set: { focus.targetMinutes = $0 })) {
                    ForEach([15, 25, 30, 45, 50, 60, 90], id: \.self) { Text(L10n.t("\($0) min")).tag($0) }
                }.pickerStyle(.menu)
                Text(L10n.t("Switch the Tasks ring on in Accounts. Things 3 needs the Automation permission; Reminders asks for access to your reminders."))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Section(L10n.t("New session")) {
                Picker(L10n.t("Terminal"), selection: $terminal) {
                    Text(L10n.t("Automatic")).tag("")
                    ForEach(NewSession.installed(), id: \.bundleID) { Text($0.name).tag($0.bundleID) }
                }.pickerStyle(.menu).onChange(of: terminal) { _, v in NewSession.terminal = v }
                TextField(L10n.t("Command"), text: $command, prompt: Text("claude"))
                    .onChange(of: command) { _, v in NewSession.command = v }
                Text(L10n.t("Runs in a new terminal window from the menu's New session… (⌘N). Put your own launcher here, e.g. a shell function that picks the project and the account."))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                TextField(L10n.t("Double-click on a ring"), text: $accountCommand, prompt: Text("{cmd}"))
                    .onChange(of: accountCommand) { _, v in NewSession.accountCommand = v }
                Text(L10n.t("Runs with the ring's account already chosen. {cmd} is that account's CLI (claude, or env CLAUDE_CONFIG_DIR=… claude), {id} its id, {dir} its config directory, {provider} claude or codex. Empty runs {cmd}."))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
    }

    private func planDetail(_ a: CostAccount) -> String {
        guard let tier = a.planTier else { return L10n.t("Plan not detected yet") }
        let name = catalog.name(for: tier)
        if let local = catalog.monthly(for: tier, currency: prices.currency, rate: prices.rate) {
            return L10n.t("\(name) · \(MoneyFormat.string(local, currency: prices.currency))/month (catalog)")
        }
        return L10n.t("\(name) · price unknown, set it here")
    }
}
