import SwiftUI
import HomeKit

/// Finds the robot vacuum among the Apple Home accessories.
///
/// Apple Home added Matter robot vacuums in iOS 18.4, but the public HomeKit
/// API does not (as far as we know) give them a dedicated service type. So we
/// pick by a saved choice, then by name, and let the person choose otherwise.
enum VacuumFinder {
    static let savedKey = "vacuumAccessoryID"
    private static let nameHints = ["deebot", "ecovacs", "vacuum", "robovac", "robot"]

    static func find(in store: HomeStore) -> HMAccessory? {
        if let saved = UserDefaults.standard.string(forKey: savedKey),
           let match = store.accessories.first(where: { $0.uniqueIdentifier.uuidString == saved }) {
            return match
        }
        return store.accessories.first { accessory in
            let haystack = "\(accessory.name) \(accessory.manufacturer ?? "") \(accessory.model ?? "")".lowercased()
            return nameHints.contains { haystack.contains($0) }
        }
    }
}

struct VacuumView: View {
    @EnvironmentObject private var store: HomeStore
    @AppStorage(VacuumFinder.savedKey) private var savedID = ""
    @State private var showPicker = false

    var body: some View {
        let vacuum = VacuumFinder.find(in: store)
        VStack(alignment: .leading, spacing: 18) {
            ScreenHeader(title: vacuum?.name ?? "Robot vacuum", subtitle: subtitle(vacuum)) {
                Button("Choose device") { showPicker = true }.buttonStyle(PillButtonStyle())
            }

            if let vacuum {
                HStack(alignment: .top, spacing: 16) {
                    VacuumControls(accessory: vacuum).frame(width: 340)
                    Card(title: "Device explorer · everything Apple Home exposes") {
                        DeviceExplorer(accessory: vacuum)
                    }
                }
            } else {
                EmptyState(icon: "circle.circle", title: "Vacuum not found",
                           message: "Tap Choose device and pick your Deebot X8. It needs to be added to Apple Home through Matter first.")
            }
        }
        .sheet(isPresented: $showPicker) {
            AccessoryPicker(selectedID: $savedID)
        }
    }

    private func subtitle(_ accessory: HMAccessory?) -> String {
        guard let accessory else { return "Not connected" }
        var parts = [accessory.isReachable ? "Connected" : "Not responding"]
        if let manufacturer = accessory.manufacturer { parts.append(manufacturer) }
        if let model = accessory.model { parts.append(model) }
        if accessory.isBridged { parts.append("via bridge") }
        return parts.joined(separator: " · ")
    }
}

/// Best-guess controls built from standard HomeKit characteristics.
/// The explorer next to it shows the full truth while we learn what the X8 exposes.
struct VacuumControls: View {
    @EnvironmentObject private var store: HomeStore
    let accessory: HMAccessory

    private var all: [HMCharacteristic] { accessory.services.flatMap(\.characteristics) }

    /// "Active" (start/stop) or, failing that, a writable power switch.
    private var runSwitch: HMCharacteristic? {
        all.first { $0.characteristicType == HMCharacteristicTypeActive && $0.isWritable }
            ?? all.first { $0.characteristicType == HMCharacteristicTypePowerState && $0.isWritable }
    }

    private var battery: HMCharacteristic? {
        all.first { $0.characteristicType == HMCharacteristicTypeBatteryLevel }
    }

    private var charging: HMCharacteristic? {
        all.first { $0.characteristicType == HMCharacteristicTypeChargingState }
    }

    var body: some View {
        VStack(spacing: 16) {
            Card(title: "Status") {
                VStack(alignment: .leading, spacing: 8) {
                    if let battery, let level = (battery.value as? NSNumber)?.intValue {
                        Label("Battery \(level)%", systemImage: "battery.75")
                    }
                    if let charging, let state = (charging.value as? NSNumber)?.intValue {
                        Label(state == 1 ? "Charging" : state == 2 ? "Not chargeable" : "Not charging",
                              systemImage: "bolt")
                    }
                    if let runSwitch {
                        Label(isRunning(runSwitch) ? "Cleaning" : "Idle or docked",
                              systemImage: isRunning(runSwitch) ? "play.circle" : "pause.circle")
                    }
                }
                .foregroundStyle(.white)
            }

            Card(title: "Control") {
                if let runSwitch {
                    HStack(spacing: 12) {
                        Button("Start") { write(runSwitch, true) }
                            .buttonStyle(PillButtonStyle(prominent: !isRunning(runSwitch)))
                        Button("Stop") { write(runSwitch, false) }
                            .buttonStyle(PillButtonStyle(prominent: isRunning(runSwitch)))
                    }
                    Text("Return to dock, mop/vacuum mode and rooms will be wired up once the explorer shows which controls the X8 exposes.")
                        .font(.caption).foregroundStyle(Theme.muted)
                } else {
                    Text("No standard start/stop control found. Check the explorer: any control Apple Home shares can be used from there, and we'll build proper buttons from what it shows.")
                        .font(.callout).foregroundStyle(Theme.muted)
                }
            }

            Card(title: "Rooms and schedules") {
                Text("For now, use the Ecovacs app for room cleaning and schedules.")
                    .font(.callout).foregroundStyle(Theme.muted)
            }
        }
    }

    private func isRunning(_ c: HMCharacteristic) -> Bool {
        (c.value as? NSNumber)?.boolValue ?? false
    }

    private func write(_ c: HMCharacteristic, _ on: Bool) {
        // Active uses 0/1 integers; PowerState uses a Bool.
        let value: Any = c.characteristicType == HMCharacteristicTypeActive ? (on ? 1 : 0) : on
        store.write(value, to: c, label: accessory.name)
    }
}

struct AccessoryPicker: View {
    @EnvironmentObject private var store: HomeStore
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedID: String

    var body: some View {
        NavigationStack {
            List(store.accessories, id: \.uniqueIdentifier) { accessory in
                Button {
                    selectedID = accessory.uniqueIdentifier.uuidString
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(accessory.name)
                            Text([accessory.room?.name, accessory.manufacturer, accessory.model]
                                    .compactMap { $0 }.joined(separator: " · "))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if accessory.uniqueIdentifier.uuidString == selectedID {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            .navigationTitle("Choose your vacuum")
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}
