import SwiftUI
import HomeKit

struct CamerasView: View {
    @EnvironmentObject private var store: HomeStore
    @State private var focusedID: UUID?

    var body: some View {
        let cams = store.cameras
        let focused = cams.first { $0.profile.uniqueIdentifier == focusedID } ?? cams.first

        VStack(alignment: .leading, spacing: 18) {
            ScreenHeader(title: "Cameras", subtitle: "\(cams.count) camera\(cams.count == 1 ? "" : "s") · live via Apple Home") {
                Button {
                    UIApplication.shared.open(URL(string: "com.apple.home://")!)
                } label: {
                    Label("Recordings in Home app", systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(PillButtonStyle())
            }

            if let focused {
                CameraTile(accessory: focused.accessory, profile: focused.profile, live: true, showControls: true)
                    .id(focused.profile.uniqueIdentifier) // restart stream when switching camera
                    .frame(maxHeight: .infinity)

                if cams.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(cams) { cam in
                                // Thumbnails use snapshots rather than live streams to save bandwidth.
                                CameraTile(accessory: cam.accessory, profile: cam.profile, live: false)
                                    .frame(width: 240, height: 140)
                                    .overlay(RoundedRectangle(cornerRadius: 16)
                                        .stroke(cam.profile.uniqueIdentifier == focused.profile.uniqueIdentifier ? Theme.accent : .clear, lineWidth: 2))
                                    .onTapGesture { focusedID = cam.profile.uniqueIdentifier }
                            }
                        }
                    }
                    .frame(height: 140)
                }
            } else {
                EmptyState(icon: "video.slash", title: "No cameras found",
                           message: "Your Aqara cameras need to be added to Apple Home (with HomeKit Secure Video or streaming enabled) to appear here.")
            }
        }
    }
}

/// A camera tile: live stream or latest snapshot, with name, LIVE badge and optional audio controls.
struct CameraTile: View {
    let accessory: HMAccessory
    let profile: HMCameraProfile
    var live: Bool
    var showControls = false

    @StateObject private var camera = CameraController()

    var body: some View {
        ZStack {
            Theme.card2
            if live {
                CameraStreamView(controller: camera)
            } else {
                CameraSnapshotView(controller: camera)
            }

            if let message = camera.statusMessage {
                VStack(spacing: 6) {
                    if camera.isStarting { ProgressView() }
                    Text(message).font(.caption).foregroundStyle(Theme.muted)
                }
            }

            VStack {
                HStack {
                    Spacer()
                    if live && camera.isStreaming {
                        Text("LIVE")
                            .font(.caption2.bold())
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Theme.red, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                Spacer()
                HStack(alignment: .bottom) {
                    Text(accessory.name)
                        .font(.subheadline.weight(.semibold))
                        .shadow(radius: 4)
                    Spacer()
                    if showControls && camera.isStreaming {
                        Button {
                            camera.toggleListening()
                        } label: {
                            Image(systemName: camera.audio == .muted ? "speaker.slash" : "speaker.wave.2")
                        }
                        .buttonStyle(PillButtonStyle())
                        Button {
                            camera.toggleTalk()
                        } label: {
                            Label("Talk", systemImage: camera.audio == .bidirectionalAudioAllowed ? "mic.fill" : "mic")
                        }
                        .buttonStyle(PillButtonStyle(prominent: camera.audio == .bidirectionalAudioAllowed))
                    }
                }
            }
            .padding(12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onAppear { camera.attach(profile, live: live) }
        .onDisappear { camera.detach() }
    }
}

/// Owns the HomeKit stream/snapshot controls for one camera.
final class CameraController: NSObject, ObservableObject {
    @Published var isStreaming = false
    @Published var isStarting = false
    @Published var statusMessage: String?
    @Published var audio: HMCameraAudioStreamSetting = .muted
    @Published private(set) var stream: HMCameraStream?
    @Published private(set) var snapshot: HMCameraSnapshot?

    private var profile: HMCameraProfile?

    func attach(_ profile: HMCameraProfile, live: Bool) {
        self.profile = profile
        if live {
            guard let control = profile.streamControl else {
                statusMessage = "This camera doesn't offer a live stream"
                return
            }
            control.delegate = self
            isStarting = true
            statusMessage = "Connecting…"
            control.startStream()
        } else {
            guard let control = profile.snapshotControl else { return }
            control.delegate = self
            snapshot = control.mostRecentSnapshot
            control.takeSnapshot()
        }
    }

    func detach() {
        profile?.streamControl?.stopStream()
        profile = nil
    }

    func toggleListening() {
        set(audio == .muted ? .incomingAudioAllowed : .muted)
    }

    func toggleTalk() {
        set(audio == .bidirectionalAudioAllowed ? .incomingAudioAllowed : .bidirectionalAudioAllowed)
    }

    private func set(_ setting: HMCameraAudioStreamSetting) {
        guard let stream else { return }
        stream.updateAudioStreamSetting(setting) { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    self?.statusMessage = "Audio: \(error.localizedDescription)"
                } else {
                    self?.audio = setting
                }
            }
        }
    }
}

extension CameraController: HMCameraStreamControlDelegate {
    func cameraStreamControlDidStartStream(_ cameraStreamControl: HMCameraStreamControl) {
        DispatchQueue.main.async {
            self.stream = cameraStreamControl.cameraStream
            self.isStreaming = true
            self.isStarting = false
            self.statusMessage = nil
            self.audio = .muted
            self.stream?.updateAudioStreamSetting(.muted) { _ in }
        }
    }

    func cameraStreamControl(_ cameraStreamControl: HMCameraStreamControl, didStopStreamWithError error: Error?) {
        DispatchQueue.main.async {
            self.isStreaming = false
            self.isStarting = false
            self.stream = nil
            self.statusMessage = error.map { "Stream stopped: \($0.localizedDescription)" }
        }
    }
}

extension CameraController: HMCameraSnapshotControlDelegate {
    func cameraSnapshotControl(_ cameraSnapshotControl: HMCameraSnapshotControl, didTake snapshot: HMCameraSnapshot?, error: Error?) {
        DispatchQueue.main.async {
            if let snapshot { self.snapshot = snapshot }
        }
    }
}

/// Wraps HomeKit's UIKit camera view for SwiftUI.
struct CameraStreamView: UIViewRepresentable {
    @ObservedObject var controller: CameraController

    func makeUIView(context: Context) -> HMCameraView {
        let view = HMCameraView()
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: HMCameraView, context: Context) {
        view.cameraSource = controller.stream
    }
}

struct CameraSnapshotView: UIViewRepresentable {
    @ObservedObject var controller: CameraController

    func makeUIView(context: Context) -> HMCameraView {
        let view = HMCameraView()
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: HMCameraView, context: Context) {
        view.cameraSource = controller.snapshot
    }
}
