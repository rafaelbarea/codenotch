import SwiftUI

/// Sizes are derived from cap heights measured in the design frame, so they
/// track `Design.scale` along with everything else.
enum Typography {
    /// The percent under each provider ring. Cap height 27px in the frame.
    static let percent = Font.system(size: Design.fontSize(capPixels: 27), weight: .semibold)

    /// "Claude Usage". Sized like the tasks card's title: 14pt at the medium
    /// card scale (the frame's 26px cap height read larger than the rest).
    static let cardTitle = Font.system(size: Design.fontSize(capPixels: cardTitleCapPixels), weight: .semibold)

    /// "Current session", "73% Used", "Resets in 51 min". 11.5pt at medium,
    /// the tasks card's row size.
    static let cardBody = Font.system(size: Design.fontSize(capPixels: cardBodyCapPixels), weight: .regular)

    /// Cap heights that land on Brink's 14pt and 11.5pt once the card is
    /// drawn at the medium card scale (`NotchViewModel.cardBase(for: 1)`).
    static let cardTitleCapPixels: CGFloat = 14 / NotchViewModel.cardBase(for: 1) * 0.714 / Design.scale
    static let cardBodyCapPixels: CGFloat = 11.5 / NotchViewModel.cardBase(for: 1) * 0.714 / Design.scale

    /// "2h 10m" under the percent: how long until that limit resets. Cap height 16px.
    static let resetLine = Font.system(size: Design.fontSize(capPixels: 16), weight: .medium)
}
