import SwiftUI
import HomeKit

struct DashboardView: View {
    @EnvironmentObject private var store: HomeStore
    var go: (Screen) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 16) {
                    ClockCard()
                    Card(title: "Weather") {
                        Text("Coming next: WeatherKit forecast for your location.")
                            .foregroundStyle(Theme.muted)
                    }
                }
                .frame(width: 330)

                VStack(spacing: 16) {
                    cameraCard
                    roomsCard
                    vacuumCard
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Header with greeting and scenes

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting).font(.largeTitle.bold())
                Text(summary).foregroundStyle(Theme.muted)
            }
            Spacer()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(store.scenes.prefix(6), id: \.uniqueIdentifier) { scene in
                        Button(scene.name) { store.execute(scene) }
                            .buttonStyle(PillButtonStyle())
                    }
                }
            }
            .frame(maxWidth: 560)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var summary: String {
        let on = store.lights.filter(\.isOn).count
        let date = Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide))
        return "\(date) · \(on) light\(on == 1 ? "" : "s") on"
    }

    // MARK: Cameras

    @ViewBuilder private var cameraCard: some View {
        let cams = store.cameras.prefix(2)
        Card(title: "Cameras") {
            if cams.isEmpty {
                Text("No cameras shared by Apple Home.").foregroundStyle(Theme.muted)
            } else {
                HStack(spacing: 14) {
                    ForEach(Array(cams)) { cam in
                        CameraTile(accessory: cam.accessory, profile: cam.profile, live: true)
                            .frame(height: 150)
                            .onTapGesture { go(.cameras) }
                    }
                }
            }
        }
    }

    // MARK: Rooms

    private var roomsCard: some View {
        Card(title: "Rooms") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(store.rooms, id: \.uniqueIdentifier) { room in
                    let lights = store.lights(in: room)
                    let on = lights.filter(\.isOn)
                    Button {
                        if on.isEmpty {
                            lights.forEach { store.setPower($0, on: true) }
                        } else {
                            store.turnOff(room: room)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: on.isEmpty ? "lightbulb" : "lightbulb.fill")
                                .frame(width: 40, height: 40)
                                .background(on.isEmpty ? Theme.card : Theme.accent.opacity(0.18),
                                            in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(on.isEmpty ? Theme.muted : Theme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(room.name).lineLimit(1)
                                Text(roomStatus(lights: lights, on: on))
                                    .font(.caption).foregroundStyle(Theme.muted)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .background(on.isEmpty ? Theme.card2 : Theme.accentDim,
                                    in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func roomStatus(lights: [HomeStore.Light], on: [HomeStore.Light]) -> String {
        if lights.isEmpty { return "No lights" }
        if on.isEmpty { return "Off" }
        let avg = on.map(\.brightnessPercent).reduce(0, +) / Double(on.count)
        return "\(on.count) on · \(Int(avg))%"
    }

    // MARK: Vacuum

    private var vacuumCard: some View {
        Card {
            HStack(spacing: 16) {
                Image(systemName: "circle.circle")
                    .font(.title)
                    .frame(width: 54, height: 54)
                    .background(Color.blue.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 2) {
                    Text(VacuumFinder.find(in: store)?.name ?? "Robot vacuum")
                    Text("Open the Vacuum screen to control it").font(.caption).foregroundStyle(Theme.muted)
                }
                Spacer()
                Button("Vacuum") { go(.vacuum) }.buttonStyle(PillButtonStyle(prominent: true))
            }
        }
    }
}

struct ClockCard: View {
    var body: some View {
        Card {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(alignment: .leading, spacing: 8) {
                    Text(context.date.formatted(.dateTime.hour().minute()))
                        .font(.system(size: 76, weight: .thin))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(context.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .foregroundStyle(Theme.muted)
                }
            }
        }
    }
}
