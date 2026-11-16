import SwiftUI
import HomeKit

/// Lists every service and characteristic of an accessory, with live values and
/// controls for anything writable. Used to discover what Apple Home exposes for
/// devices without a dedicated HomeKit type (like Matter robot vacuums).
struct DeviceExplorer: View {
    @EnvironmentObject private var store: HomeStore
    let accessory: HMAccessory

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(accessory.services, id: \.uniqueIdentifier) { service in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(service.localizedDescription.isEmpty ? service.name : service.localizedDescription)
                            .font(.headline)
                        Text(service.serviceType).font(.caption2.monospaced()).foregroundStyle(Theme.muted)
                        ForEach(service.characteristics, id: \.uniqueIdentifier) { c in
                            CharacteristicRow(characteristic: c, label: accessory.name)
                        }
                    }
                    .padding(12)
                    .background(Theme.card2, in: RoundedRectangle(cornerRadius: 14))
                }
                Button("Copy details") {
                    UIPasteboard.general.string = report()
                }
                .buttonStyle(PillButtonStyle())
                Text("Paste the copied details into the project chat so we can build proper controls.")
                    .font(.caption).foregroundStyle(Theme.muted)
            }
        }
    }

    /// Plain-text dump of the accessory, handy to share while we work out the X8's controls.
    private func report() -> String {
        var lines = ["\(accessory.name) · \(accessory.manufacturer ?? "?") \(accessory.model ?? "?") · firmware \(accessory.firmwareVersion ?? "?")"]
        for service in accessory.services {
            lines.append("")
            lines.append("SERVICE \(service.localizedDescription) [\(service.serviceType)]")
            for c in service.characteristics {
                let m = c.metadata
                var meta: [String] = []
                if let f = m?.format { meta.append("format=\(f)") }
                if let lo = m?.minimumValue { meta.append("min=\(lo)") }
                if let hi = m?.maximumValue { meta.append("max=\(hi)") }
                if let valid = m?.validValues { meta.append("valid=\(valid.map(\.stringValue).joined(separator: ","))") }
                lines.append("  \(c.localizedDescription) [\(c.characteristicType)] value=\(String(describing: c.value ?? "nil")) \(c.isWritable ? "writable" : "read-only") \(meta.joined(separator: " "))")
            }
        }
        return lines.joined(separator: "\n")
    }
}

struct CharacteristicRow: View {
    @EnvironmentObject private var store: HomeStore
    let characteristic: HMCharacteristic
    let label: String

    private var format: String? { characteristic.metadata?.format }
    private var number: Double? { (characteristic.value as? NSNumber)?.doubleValue }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(characteristic.localizedDescription.isEmpty ? "Unnamed" : characteristic.localizedDescription)
                Text(valueText).font(.caption).foregroundStyle(Theme.muted).lineLimit(2)
            }
            Spacer()
            if characteristic.isWritable { control } else {
                Button { store.read(characteristic) } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless)
            }
        }
        .font(.callout)
    }

    private var valueText: String {
        guard let value = characteristic.value else { return "No value" }
        if let valid = characteristic.metadata?.validValues, !valid.isEmpty, let n = number {
            return "\(Int(n)) (options: \(valid.map(\.stringValue).joined(separator: ", ")))"
        }
        return "\(value)"
    }

    @ViewBuilder private var control: some View {
        if format == HMCharacteristicMetadataFormatBool {
            Toggle("", isOn: Binding(get: { (number ?? 0) != 0 },
                                     set: { store.write($0, to: characteristic, label: label) }))
                .labelsHidden().tint(Theme.green)
        } else if let valid = characteristic.metadata?.validValues, !valid.isEmpty {
            Menu(number.map { "\(Int($0))" } ?? "Set") {
                ForEach(valid, id: \.self) { option in
                    Button("\(option.intValue)") { store.write(option.intValue, to: characteristic, label: label) }
                }
            }
        } else if let lo = characteristic.metadata?.minimumValue?.doubleValue,
                  let hi = characteristic.metadata?.maximumValue?.doubleValue, hi > lo, hi - lo <= 1000 {
            let step = characteristic.metadata?.stepValue?.doubleValue ?? 1
            Stepper(value: Binding(get: { number ?? lo },
                                   set: { store.write(isInteger ? Int($0) as Any : $0 as Any, to: characteristic, label: label) }),
                    in: lo...hi, step: max(step, 1)) { EmptyView() }
                .labelsHidden()
        } else if characteristic.characteristicType == HMCharacteristicTypeActive {
            Toggle("", isOn: Binding(get: { (number ?? 0) != 0 },
                                     set: { store.write($0 ? 1 : 0, to: characteristic, label: label) }))
                .labelsHidden().tint(Theme.green)
        } else {
            Text("writable").font(.caption2).foregroundStyle(Theme.accent)
        }
    }

    private var isInteger: Bool {
        guard let format else { return true }
        return format != HMCharacteristicMetadataFormatFloat
    }
}

extension HMCharacteristic {
    var isWritable: Bool { properties.contains(HMCharacteristicPropertyWritable) }
}
