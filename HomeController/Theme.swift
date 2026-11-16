import SwiftUI

/// Colours and shared building blocks matching the mockups (dark, amber accent).
enum Theme {
    static let background = Color(red: 0.06, green: 0.07, blue: 0.08)
    static let rail = Color(red: 0.04, green: 0.05, blue: 0.06)
    static let card = Color(red: 0.10, green: 0.11, blue: 0.14)
    static let card2 = Color(red: 0.14, green: 0.15, blue: 0.19)
    static let muted = Color(red: 0.55, green: 0.57, blue: 0.64)
    static let accent = Color(red: 1.0, green: 0.71, blue: 0.28)
    static let accentDim = Color(red: 0.17, green: 0.15, blue: 0.09)
    static let green = Color(red: 0.31, green: 0.82, blue: 0.55)
    static let red = Color(red: 1.0, green: 0.42, blue: 0.42)
}

struct Card<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title.uppercased())
                    .font(.caption.weight(.medium))
                    .tracking(1)
                    .foregroundStyle(Theme.muted)
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct PillButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(prominent ? .semibold : .regular))
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .foregroundStyle(prominent ? Color.black : Color.white)
            .background(prominent ? Theme.accent : Theme.card2,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct ScreenHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.largeTitle.bold())
                if let subtitle {
                    Text(subtitle).foregroundStyle(Theme.muted)
                }
            }
            Spacer()
            HStack(spacing: 12) { trailing }
        }
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 44)).foregroundStyle(Theme.muted)
            Text(title).font(.title3.weight(.semibold))
            Text(message).foregroundStyle(Theme.muted).multilineTextAlignment(.center).frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
