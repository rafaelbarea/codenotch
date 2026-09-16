import SwiftUI

/// "What used it" on the hover card: the projects that consumed this
/// account's allowance in the current week (or credit cycle), each with its
/// share and the money that share is worth. The full picker lives in the
/// Activity window; the card keeps to one range so it never grows past what
/// `NotchLayout.cardHeight` reserved for it.
struct BrinkCostSection: View {
    @ObservedObject var model: CostModel

    static let maxRows = 5

    /// How many lines the card must reserve — read by the height math, so it
    /// has to agree with what `body` draws.
    @MainActor static func rowCount(for snapshot: ProviderSnapshot) -> Int {
        guard let m = CostModels.model(for: snapshot.id), m.state == .ready else { return 0 }
        return min(m.rows.count, maxRows)
    }

    private var rows: [ProjectCost] { Array(model.rows.prefix(Self.maxRows)) }
    private var title: String {
        model.creditBacked ? L10n.t("This cycle") : (model.quotaBacked ? L10n.t("This week") : L10n.t("This month"))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NotchLayout.sessionRowGap) {
            Text(title)
                .font(Typography.cardBody)
                .foregroundStyle(Palette.textPrimary)
                .padding(.top, NotchLayout.blockSpacing)
            ForEach(rows) { row in
                HStack(spacing: Design.px(12)) {
                    Text(row.displayName)
                        .font(Typography.cardBody)
                        .foregroundStyle(row.isUnexplained ? Palette.textSecondary : Palette.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: Design.px(8))
                    Text(Percent.text(for: row.pct / 100) + "%")
                        .font(Typography.cardBody)
                        .foregroundStyle(Palette.textSecondary)
                        .monospacedDigit()
                    if let cost = row.cost {
                        Text(MoneyFormat.string(cost, currency: PriceTable.shared.currency))
                            .font(Typography.cardBody)
                            .foregroundStyle(Palette.textSecondary)
                            .monospacedDigit()
                            .frame(minWidth: Design.px(70), alignment: .trailing)
                    }
                }
            }
        }
        .onAppear {
            // The card has one range: the allowance window when the account has
            // one, else the month.
            if model.quotaBacked { if model.range != .weekly { model.range = .weekly } }
            else if model.range != .month { model.range = .month }
        }
    }
}
