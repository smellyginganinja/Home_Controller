# Home Controller

A wall-mounted iPad dashboard for Apple Home: lights, cameras, robot vacuum, and (coming next) Spotify, weather, timers and alarms.

Built natively in SwiftUI on Apple's HomeKit framework, so it uses the same homes, rooms, scenes and devices you already have in the Home app. No extra hub or server needed.

## What's in this prototype

| Screen | What works |
|---|---|
| **Home** | Big clock and date, your Apple Home scenes as one-tap buttons, room tiles (tap to turn a room's lights on/off), two live camera tiles, vacuum shortcut |
| **Lights** | Every light grouped by room: on/off, brightness, and for supported bulbs warm/cool and colour presets |
| **Cameras** | Live stream of your Aqara cameras via HomeKit, with listen and two-way talk; snapshot thumbnails to switch cameras |
| **Vacuum** | Finds your Deebot X8, shows battery/charging, Start/Stop if Apple Home exposes it, and a **device explorer** listing every control Apple Home shares |
| **Settings** | Pick which home to show, counts of what Apple Home shares, wall-mount tips |

The device explorer is there on purpose: Apple doesn't document how Matter robot vacuums appear to third-party apps. Open it once, tap **Copy details**, and paste the result into the project chat. We'll use that to build proper dock, mode and room controls.

## Run it on your iPad

You need a Mac with **Xcode 16 or newer**, and an iPad on **iPadOS 18 or newer** signed in to the same Apple Account as your Home app.

1. **Get the code.** In Terminal:
   ```sh
   git clone https://github.com/smellyginganinja/Home_Controller.git
   cd Home_Controller
   git checkout prototype/homekit-shell   # until the pull request is merged
   open HomeController.xcodeproj
   ```
2. **Sign the app.** In Xcode, click the blue **HomeController** project at the top of the left sidebar → **HomeController** target → **Signing & Capabilities**.
   - Tick **Automatically manage signing**.
   - **Team:** choose your Apple Account (add it under Xcode › Settings › Accounts if it isn't listed).
   - If Xcode says the bundle identifier is taken, change `com.smellyginganinja.HomeController` to anything unique, e.g. `com.yourname.homecontroller`.
   - You should see **HomeKit** listed under capabilities. If Xcode says HomeKit needs a paid Apple Developer membership, enrol at developer.apple.com (US$99/yr). We'll need it later for WeatherKit anyway.
3. **Prepare the iPad.**
   - Connect it to the Mac with a USB-C cable (or put both on the same Wi-Fi after the first cable connection), unlock it and tap **Trust**.
   - Turn on **Developer Mode**: Settings › Privacy & Security › Developer Mode → On. The iPad restarts; confirm when asked.
4. **Run.** At the top of Xcode, pick your iPad as the run destination and press **▶ Run** (⌘R).
   - First time only: if the iPad says "Untrusted Developer", go to Settings › General › VPN & Device Management, tap your Apple Account, then **Trust**. Press Run again.
5. **Allow Home access** when the app asks. If you tap Don't Allow by mistake: Settings › Privacy & Security › HomeKit → Home → On.

With a free Apple Account the app stops opening after 7 days; just press Run again from Xcode. With a paid developer account it lasts a year.

### Wall-mount tips

- The app keeps the screen awake while it's open.
- To lock the iPad to this app: Settings › Accessibility › Guided Access → On, open the app, triple-click the top button, tap Start.
- Keep it on power. If your iPad offers it, turn on Settings › Battery › Charging › 80% limit to protect the battery.

## Project layout

```
HomeController.xcodeproj    Xcode project (files in HomeController/ are picked up automatically)
Config/                     Info.plist privacy messages, HomeKit entitlement
HomeController/
  HomeControllerApp.swift   App entry point
  HomeStore.swift           Talks to Apple Home: homes, rooms, scenes, lights, cameras, live updates
  ContentView.swift         Sidebar navigation and Settings
  DashboardView.swift       Home screen (clock, scenes, rooms, cameras, vacuum)
  LightsView.swift          Lights grid and detail panel
  CamerasView.swift         Live camera streams and snapshots
  VacuumView.swift          Robot vacuum status and controls
  DeviceExplorer.swift      Shows every service/characteristic an accessory exposes
  Theme.swift               Colours and shared UI pieces
```

## Roadmap

- Spotify now-playing and controls (Spotify Web API)
- Weather (WeatherKit)
- Timers and alarms that ring even when the app is closed (AlarmKit, iPadOS 26)
- Night-time idle mode: dim big clock
- Proper Deebot controls once we know what Apple Home exposes
