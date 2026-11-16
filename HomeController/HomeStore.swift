import Foundation
import HomeKit

/// Single source of truth for everything we read from Apple Home.
///
/// HomeKit objects (homes, accessories, characteristics) are live: their
/// `value` properties change when we read or get notified. Views read those
/// values directly and re-render whenever `revision` is bumped.
final class HomeStore: NSObject, ObservableObject {
    @Published private(set) var homes: [HMHome] = []
    @Published var selectedHomeID: UUID?
    @Published private(set) var authorizationStatus: HMHomeManagerAuthorizationStatus = []
    @Published private(set) var hasLoaded = false
    /// Bumped whenever any characteristic value or accessory state changes.
    @Published private(set) var revision = 0
    @Published var lastError: String?

    private let manager = HMHomeManager()

    override init() {
        super.init()
        manager.delegate = self
    }

    // MARK: - Current home

    var home: HMHome? {
        if let id = selectedHomeID, let match = homes.first(where: { $0.uniqueIdentifier == id }) {
            return match
        }
        return homes.first
    }

    var accessories: [HMAccessory] { home?.accessories ?? [] }

    /// Rooms that contain at least one accessory, plus "Default Room" if it is used.
    var rooms: [HMRoom] {
        guard let home else { return [] }
        var all = home.rooms
        all.append(home.roomForEntireHome())
        return all.filter { room in accessories.contains { $0.room?.uniqueIdentifier == room.uniqueIdentifier } }
    }

    /// User-visible scenes (excludes the hidden ones that automations create).
    var scenes: [HMActionSet] {
        (home?.actionSets ?? [])
            .filter { $0.actionSetType != HMActionSetTypeTriggerOwned }
            .sorted { $0.name < $1.name }
    }

    // MARK: - Lights

    struct Light: Identifiable {
        let service: HMService
        var id: UUID { service.uniqueIdentifier }
        var accessory: HMAccessory? { service.accessory }
        var name: String { service.name }
        var power: HMCharacteristic? { service.characteristic(HMCharacteristicTypePowerState) }
        var brightness: HMCharacteristic? { service.characteristic(HMCharacteristicTypeBrightness) }
        var hue: HMCharacteristic? { service.characteristic(HMCharacteristicTypeHue) }
        var saturation: HMCharacteristic? { service.characteristic(HMCharacteristicTypeSaturation) }
        var colorTemperature: HMCharacteristic? { service.characteristic(HMCharacteristicTypeColorTemperature) }
        var isOn: Bool { (power?.value as? Bool) ?? ((power?.value as? NSNumber)?.boolValue ?? false) }
        var brightnessPercent: Double { (brightness?.value as? NSNumber)?.doubleValue ?? (isOn ? 100 : 0) }
        var isReachable: Bool { accessory?.isReachable ?? false }
    }

    var lights: [Light] {
        accessories
            .flatMap { $0.services }
            .filter { $0.serviceType == HMServiceTypeLightbulb }
            .map(Light.init)
    }

    func lights(in room: HMRoom) -> [Light] {
        lights.filter { $0.accessory?.room?.uniqueIdentifier == room.uniqueIdentifier }
    }

    // MARK: - Cameras

    struct Camera: Identifiable {
        let accessory: HMAccessory
        let profile: HMCameraProfile
        var id: UUID { profile.uniqueIdentifier }
    }

    var cameras: [Camera] {
        accessories.flatMap { accessory in
            (accessory.cameraProfiles ?? []).map { Camera(accessory: accessory, profile: $0) }
        }
    }

    // MARK: - Actions

    func execute(_ scene: HMActionSet) {
        home?.executeActionSet(scene) { [weak self] error in
            self?.report(error, "Couldn't run \(scene.name)")
        }
    }

    func setPower(_ light: Light, on: Bool) {
        guard let power = light.power else { return }
        write(on, to: power, label: light.name)
    }

    func setBrightness(_ light: Light, percent: Double) {
        guard let brightness = light.brightness else { return }
        write(Int(percent.rounded()), to: brightness, label: light.name)
    }

    func setColor(_ light: Light, hue: Double, saturation: Double) {
        if let h = light.hue { write(hue, to: h, label: light.name) }
        if let s = light.saturation { write(saturation, to: s, label: light.name) }
    }

    /// Mireds: ~140 (cool) to ~500 (warm). Clamped to the device's own range.
    func setColorTemperature(_ light: Light, mireds: Double) {
        guard let ct = light.colorTemperature else { return }
        let lo = ct.metadata?.minimumValue?.doubleValue ?? 140
        let hi = ct.metadata?.maximumValue?.doubleValue ?? 500
        write(Int(min(max(mireds, lo), hi)), to: ct, label: light.name)
    }

    func turnOff(room: HMRoom) {
        for light in lights(in: room) where light.isOn { setPower(light, on: false) }
    }

    func turnOffAllLights() {
        for light in lights where light.isOn { setPower(light, on: false) }
    }

    func write(_ value: Any, to characteristic: HMCharacteristic, label: String) {
        characteristic.writeValue(value) { [weak self] error in
            self?.report(error, "Couldn't update \(label)")
            self?.bump()
        }
        bump() // optimistic redraw
    }

    func read(_ characteristic: HMCharacteristic) {
        characteristic.readValue { [weak self] _ in self?.bump() }
    }

    // MARK: - Live updates

    private func observeAll() {
        for accessory in accessories {
            accessory.delegate = self
            for service in accessory.services {
                for characteristic in service.characteristics {
                    if characteristic.properties.contains(HMCharacteristicPropertyReadable) {
                        characteristic.readValue { [weak self] _ in self?.bump() }
                    }
                    if characteristic.properties.contains(HMCharacteristicPropertySupportsEventNotification) {
                        characteristic.enableNotification(true) { _ in }
                    }
                }
            }
        }
    }

    private func bump() {
        DispatchQueue.main.async { self.revision &+= 1 }
    }

    private func report(_ error: Error?, _ message: String) {
        guard let error else { return }
        DispatchQueue.main.async { self.lastError = "\(message): \(error.localizedDescription)" }
    }

    func selectHome(_ home: HMHome) {
        selectedHomeID = home.uniqueIdentifier
        observeAll()
    }
}

extension HomeStore: HMHomeManagerDelegate {
    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        DispatchQueue.main.async {
            self.homes = manager.homes
            self.hasLoaded = true
            for home in manager.homes { home.delegate = self }
            self.observeAll()
            self.bump()
        }
    }

    func homeManager(_ manager: HMHomeManager, didUpdate status: HMHomeManagerAuthorizationStatus) {
        DispatchQueue.main.async { self.authorizationStatus = status }
    }
}

extension HomeStore: HMHomeDelegate {
    func home(_ home: HMHome, didAdd accessory: HMAccessory) { homeManagerDidUpdateHomes(manager) }
    func home(_ home: HMHome, didRemove accessory: HMAccessory) { homeManagerDidUpdateHomes(manager) }
    func home(_ home: HMHome, didUpdate room: HMRoom, for accessory: HMAccessory) { bump() }
    func home(_ home: HMHome, didAdd actionSet: HMActionSet) { bump() }
    func home(_ home: HMHome, didRemove actionSet: HMActionSet) { bump() }
}

extension HomeStore: HMAccessoryDelegate {
    func accessory(_ accessory: HMAccessory, service: HMService, didUpdateValueFor characteristic: HMCharacteristic) {
        bump()
    }

    func accessoryDidUpdateReachability(_ accessory: HMAccessory) { bump() }
}

extension HMService {
    func characteristic(_ type: String) -> HMCharacteristic? {
        characteristics.first { $0.characteristicType == type }
    }
}
