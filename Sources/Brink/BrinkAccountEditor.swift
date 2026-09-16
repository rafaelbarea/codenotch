import SwiftUI

/// The pencil on an account's row in Settings → Accounts, and the popover it
/// opens: the login's nickname, how it is billed, what it costs, and the
/// plan detected for it. Nothing for rows that are not a Claude or Codex
/// login on this Mac.
struct BrinkAccountEditButton: View {
    let providerID: String
    @ObservedObject private var accounts = CostAccountStore.shared
    @State private var editing = false

    var body: some View {
        if accounts.account(providerID) != nil {
            SettingsIconButton(systemName: "pencil", help: L10n.t("Name, plan and price for this login")) {
                editing.toggle()
            }
            .popover(isPresented: $editing, arrowEdge: .bottom) {
                BrinkAccountEditor(providerID: providerID)
            }
        }
    }
}

struct BrinkAccountEditor: View {
    let providerID: String
    @ObservedObject private var accounts = CostAccountStore.shared
    @ObservedObject private var prices = PriceTable.shared
    @ObservedObject private var catalog = PlanCatalog.shared
    @State private var name = ""

    private var currencyName: String { Locale.current.localizedString(forCurrencyCode: prices.currency) ?? prices.currency }

    var body: some View {
        if let a = accounts.account(providerID) {
            let auto = a.monthlyLocal(rate: prices.rate)
            VStack(alignment: .leading, spacing: 12) {
                Text(accounts.defaultName(providerID)).font(.headline)
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                    GridRow {
                        Text(L10n.t("Name")).foregroundStyle(.secondary)
                        TextField("", text: $name, prompt: Text(accounts.defaultName(providerID)))
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { accounts.setName(providerID, name) }
                            .onChange(of: name) { _, v in accounts.setName(providerID, v) }
                    }
                    GridRow {
                        Text(L10n.t("Billing")).foregroundStyle(.secondary)
                        Picker("", selection: Binding(get: { a.billing }, set: { accounts.setBilling(providerID, $0) })) {
                            ForEach(CostAccount.Billing.allCases) { Text($0.title).tag($0) }
                        }.labelsHidden()
                    }
                    if a.billing == .subscription {
                        GridRow {
                            Text(L10n.t("Monthly price")).foregroundStyle(.secondary)
                            TextField("", value: Binding(get: { a.monthlyPrice == 0 ? nil : a.monthlyPrice },
                                                         set: { accounts.setMonthlyPrice(providerID, $0 ?? 0) }),
                                      format: .number,
                                      prompt: Text(auto > 0 ? MoneyFormat.string(auto, currency: prices.currency) : "—"))
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                        }
                        GridRow {
                            Text(L10n.t("Plan")).foregroundStyle(.secondary)
                            Text(planDetail(a)).font(.callout)
                        }
                    }
                }
                Text(L10n.t("Detected from each login once a day. A week of the plan costs the price ÷ 4.35; a project that used 4% of the weekly allowance spent 4% of that. Amounts in \(currencyName), your Mac's currency. Type the amount you actually pay to override the list price."))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Text(L10n.t("The name is what the notch, the cards and a shell launcher call this login. Empty goes back to the default."))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(width: 380)
            .onAppear { name = a.name == accounts.defaultName(providerID) ? "" : a.name }
        }
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
