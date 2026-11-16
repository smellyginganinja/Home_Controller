import SwiftUI
import HomeKit

struct LightsView: View {
    @EnvironmentObject private var store: HomeStore
    @State private var selectedID: UUID?

    private var selected: HomeStore.Light? {
        store.lights.first { $0.id == selectedID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            let lights = store.lights
            ScreenHeader(title: "Lights", subtitle: "\(lights.filter(\.isOn).count) of \(lights.count) on") {
                Button("All off") { store.turnOffAllLights() }.buttonStyle(PillButtonStyle())
            }

            if lights.isEmpty {
                EmptyState(icon: "lightbulb.slash", title: "No lights found",
                           message: "Apple Home didn't share any lights with this app.")
            } else {
                HStack(alignment: .top, spacing: 16) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(store.rooms, id: \.uniqueIdentifier) { room in
                                let roomLights = store.lights(in: room)
                                if !roomLights.isEmpty {
                                    Card(title: room.name) {
                                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                                            ForEach(roomLights) { light in
                                                LightTile(light: light, isSelected: light.id == selectedID)
                                                    .onTapGesture { selectedID = light.id }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    if let selected {
                        LightDetail(light: selected).frame(width: 320)
                    }
                }
            }
        }
    }
}

struct LightTile: View {
    @EnvironmentObject private var store: HomeStore
    let light: HomeStore.Light
    var isSelected = false
    @State private var draft: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: light.isOn ? "lightbulb.fill" : "lightbulb")
                    .frame(width: 40, height: 40)
                    .background(light.isOn ? Theme.accent.opacity(0.18) : Theme.card,
                                in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(light.isOn ? Theme.accent : Theme.muted)
                VStack(alignment: .leading, spacing: 2) {
                    Text(light.name).lineLimit(1)
                    Text(status).font(.caption).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
                Toggle("", isOn: Binding(get: { light.isOn }, set: { store.setPower(light, on: $0) }))
                    .labelsHidden()
                    .tint(Theme.green)
                    .disabled(!light.isReachable)
            }
            if light.brightness != nil {
                // Only send to the light when the finger lifts, so we don't flood it with writes.
                Slider(value: Binding(get: { draft ?? light.brightnessPercent }, set: { draft = $0 }),
                       in: 0...100, step: 5,
                       onEditingChanged: { editing in
                    if !editing, let value = draft {
                        store.setBrightness(light, percent: value)
                        draft = nil
                    }
                })
                .tint(Theme.accent)
                .disabled(!light.isReachable)
            }
        }
        .padding(14)
        .background(light.isOn ? Theme.accentDim : Theme.card2, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(isSelected ? Theme.accent : .clear, lineWidth: 2))
    }

    private var status: String {
        if !light.isReachable { return "Not responding" }
        if !light.isOn { return "Off" }
        return light.brightness == nil ? "On" : "\(Int(light.brightnessPercent))%"
    }
}

struct LightDetail: View {
    @EnvironmentObject private var store: HomeStore
    let light: HomeStore.Light

    private let presets: [(name: String, hue: Double, sat: Double)] = [
        ("Red", 0, 85), ("Amber", 35, 90), ("Green", 140, 70), ("Blue", 215, 75), ("Purple", 265, 60)
    ]

    var body: some View {
        Card(title: light.name) {
            VStack(spacing: 18) {
                if light.brightness != nil {
                    BrightnessColumn(percent: light.brightnessPercent) { store.setBrightness(light, percent: $0) }
                        .frame(height: 300)
                }
                if light.colorTemperature != nil {
                    VStack(alignment: .leading, spacing: 6) {
                        LinearGradient(colors: [Color(red: 1, green: 0.7, blue: 0.36), Color(red: 1, green: 0.95, blue: 0.88), Color(red: 0.81, green: 0.89, blue: 1)],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(height: 22).clipShape(Capsule())
                        HStack {
                            Button("Warm") { store.setColorTemperature(light, mireds: 450) }
                            Spacer()
                            Button("Neutral") { store.setColorTemperature(light, mireds: 300) }
                            Spacer()
                            Button("Cool") { store.setColorTemperature(light, mireds: 160) }
                        }
                        .font(.callout)
                    }
                }
                if light.hue != nil {
                    HStack(spacing: 12) {
                        ForEach(presets.indices, id: \.self) { index in
                            let p = presets[index]
                            Button {
                                store.setColor(light, hue: p.hue, saturation: p.sat)
                            } label: {
                                Circle()
                                    .fill(Color(hue: p.hue / 360, saturation: p.sat / 100, brightness: 1))
                                    .frame(width: 36, height: 36)
                            }
                            .accessibilityLabel(p.name)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

/// Tall drag-to-set brightness control, like the one in Control Centre.
struct BrightnessColumn: View {
    let percent: Double
    let onCommit: (Double) -> Void
    @State private var dragValue: Double?

    var body: some View {
        GeometryReader { geo in
            let value = dragValue ?? percent
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 34).fill(Theme.card2)
                Rectangle()
                    .fill(LinearGradient(colors: [Color(red: 1, green: 0.82, blue: 0.48), Theme.accent], startPoint: .top, endPoint: .bottom))
                    .frame(height: geo.size.height * value / 100)
                Text("\(Int(value))%")
                    .font(.title2.weight(.semibold))
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 16)
            }
            .clipShape(RoundedRectangle(cornerRadius: 34))
            .frame(width: 120)
            .frame(maxWidth: .infinity)
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { g in
                    dragValue = min(100, max(0, (1 - g.location.y / geo.size.height) * 100)).rounded()
                }
                .onEnded { _ in
                    if let v = dragValue { onCommit(v) }
                    dragValue = nil
                })
        }
    }
}
