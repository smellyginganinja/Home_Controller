import SwiftUI
import HomeKit

enum Screen: String, CaseIterable, Identifiable {
    case home, lights, cameras, vacuum, settings
    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .lights: "Lights"
        case .cameras: "Cameras"
        case .vacuum: "Vacuum"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .home: "house"
        case .lights: "lightbulb"
        case .cameras: "video"
        case .vacuum: "circle.circle"
        case .settings: "slider.horizontal.3"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var store: HomeStore
    @State private var screen: Screen = .home

    var body: some View {
        HStack(spacing: 0) {
            rail
            Divider().overlay(Color.white.opacity(0.06))
            Group {
                if !store.hasLoaded {
                    ProgressView("Connecting to Apple Home…").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.home == nil {
                    EmptyState(icon: "house.slash",
                               title: "No home found",
                               message: "Allow Home access in Settings › Privacy & Security › HomeKit, and make sure this iPad is signed in to the same Apple Account as your Home app.")
                } else {
                    detail
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Theme.background.ignoresSafeArea())
        .alert("Something went wrong",
               isPresented: Binding(get: { store.lastError != nil }, set: { if !$0 { store.lastError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.lastError ?? "")
        }
    }

    private var rail: some View {
        VStack(spacing: 8) {
            ForEach(Screen.allCases) { item in
                Button {
                    screen = item
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.icon).font(.title3)
                        Text(item.title).font(.caption2)
                    }
                    .frame(width: 66, height: 62)
                    .foregroundStyle(screen == item ? Theme.accent : Theme.muted)
                    .background(screen == item ? Theme.card2 : .clear,
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.top, 24)
        .frame(width: 92)
        .background(Theme.rail.ignoresSafeArea())
    }

    @ViewBuilder private var detail: some View {
        switch screen {
        case .home: DashboardView(go: { screen = $0 })
        case .lights: LightsView()
        case .cameras: CamerasView()
        case .vacuum: VacuumView()
        case .settings: SettingsView()
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: HomeStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ScreenHeader(title: "Settings", subtitle: "Prototype build")
            Card(title: "Home") {
                ForEach(store.homes, id: \.uniqueIdentifier) { home in
                    Button {
                        store.selectHome(home)
                    } label: {
                        HStack {
                            Text(home.name)
                            Spacer()
                            if home.uniqueIdentifier == store.home?.uniqueIdentifier {
                                Image(systemName: "checkmark").foregroundStyle(Theme.accent)
                            }
                        }
                        .padding(14)
                        .background(Theme.card2, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            Card(title: "What Apple Home shares with this app") {
                let s = store
                Text("\(s.accessories.count) accessories · \(s.lights.count) lights · \(s.cameras.count) cameras · \(s.scenes.count) scenes · \(s.rooms.count) rooms")
                    .foregroundStyle(Theme.muted)
            }
            Card(title: "Wall mount tips") {
                Text("The screen stays awake while this app is open. To lock the iPad to this app, turn on Settings › Accessibility › Guided Access, open the app and triple-click the top button.")
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
        }
    }
}
