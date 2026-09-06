import SwiftUI

enum AppTheme {
    static let background = Color(uiColor: .systemGroupedBackground)
    static let panel = Color.white
    static let softPanel = Color(uiColor: .secondarySystemGroupedBackground)
    static let ink = Color(red: 0.08, green: 0.13, blue: 0.10)
    static let muted = Color(red: 0.38, green: 0.44, blue: 0.40)
    static let green = Color(red: 0.12, green: 0.37, blue: 0.26)
    static let greenSoft = Color(red: 0.90, green: 0.95, blue: 0.91)
    static let warning = Color(red: 0.95, green: 0.57, blue: 0.22)
    static let danger = Color(red: 0.75, green: 0.22, blue: 0.14)
}

extension View {
    func panelCard() -> some View {
        self
            .padding(14)
            .background(AppTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

func timeText(_ ms: Int) -> String {
    let total = ms / 1000
    return String(format: "%02d:%02d", total / 60, total % 60)
}
