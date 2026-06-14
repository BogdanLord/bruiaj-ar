import SwiftUI
import CoreLocation
import AVFoundation

// ---- benzi + analiză (oglindă simplificată a logicii de pe site) ----
struct ARBand: Identifiable { let id: String; let label: String }

let AR_BANDS: [ARBand] = [
    .init(id: "GPS_L1", label: "L1"),
    .init(id: "GPS_L2", label: "L2"),
    .init(id: "GPS_L5", label: "L5"),
    .init(id: "GLONASS_G1", label: "GLO"),
    .init(id: "GALILEO_E1", label: "GAL"),
    .init(id: "GSM_900", label: "GSM"),
    .init(id: "LTE_800", label: "LTE"),
    .init(id: "WIFI_24", label: "2.4"),
    .init(id: "WIFI_5", label: "5G"),
]

func bandEnergy(_ band: String, _ active: [Zone]) -> Double {
    active.filter { $0.band == band }.map { $0.intensity / 100.0 }.max() ?? 0
}

func defconLevel(_ active: [Zone]) -> Int {
    switch active.count {
    case 0: return 5
    case 1: return 4
    case 2...3: return 3
    case 4...5: return 2
    default: return 1
    }
}
func defconLabel(_ d: Int) -> String {
    [5: "VERDE", 4: "ALBASTRU", 3: "GALBEN", 2: "PORTOCALIU", 1: "ROȘU"][d] ?? "—"
}
func defconColor(_ d: Int) -> Color { d <= 2 ? Palette.red : (d == 3 ? Palette.amber : Palette.green) }

func currentZone(_ user: CLLocationCoordinate2D?, _ active: [Zone]) -> Zone? {
    guard let user = user else { return nil }
    let inside = active.filter {
        distanceMeters(user, CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)) <= $0.radiusKm * 1000
    }
    return inside.min {
        distanceMeters(user, CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)) <
        distanceMeters(user, CLLocationCoordinate2D(latitude: $1.latitude, longitude: $1.longitude))
    }
}

// =====================================================================
struct ContentView: View {
    @StateObject private var service = SupabaseService()
    @StateObject private var loc = LocationManager()
    @State private var selection = 2

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                ZonesListView(zones: service.zones, user: loc.coordinate)
                    .navigationTitle("Zone")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button { Task { await service.loadZones() } } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                    }
            }
            .tabItem { Label("Zone", systemImage: "list.bullet") }
            .tag(0)

            RadarScreen(service: service, loc: loc)
                .tabItem { Label("Radar", systemImage: "scope") }
                .tag(1)

            ARScreen(service: service, loc: loc)
                .tabItem { Label("AR", systemImage: "camera.viewfinder") }
                .tag(2)
        }
        .tint(Palette.cyan)
        .task {
            loc.start()
            await service.loadZones()
            service.startAutoRefresh(every: 5)   // verifică zone noi la 5s
        }
    }
}

struct RadarScreen: View {
    @ObservedObject var service: SupabaseService
    @ObservedObject var loc: LocationManager
    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            RadarView(zones: service.zones, user: loc.coordinate, heading: loc.heading)
            VStack { StatusHUD(service: service, loc: loc); Spacer() }
        }
    }
}

struct ARScreen: View {
    @ObservedObject var service: SupabaseService
    @ObservedObject var loc: LocationManager
    var body: some View {
        ZStack {
            ZoneARView(zones: service.zones, user: loc.coordinate)
                .ignoresSafeArea()
            VStack {
                StatusHUD(service: service, loc: loc)
                Spacer()
                Text("Îndreaptă camera spre podea/masă ca să apară harta")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Palette.txtDim)
                    .padding(8)
                    .background(Capsule().fill(.black.opacity(0.5)))
                    .padding(.bottom, 26)
            }
        }
    }
}

// ---- indicator LIVE (secunde de la ultima sincronizare) ----
struct LivePill: View {
    let lastSync: Date?
    var body: some View {
        TimelineView(.animation) { tl in
            let now = tl.date
            let secs = lastSync.map { max(0, Int(now.timeIntervalSince($0))) } ?? -1
            let blink = 0.45 + 0.55 * sin(now.timeIntervalSinceReferenceDate * 3)
            HStack(spacing: 5) {
                Circle().fill(Palette.green).frame(width: 7, height: 7)
                    .shadow(color: Palette.green, radius: 3).opacity(blink)
                Text(secs >= 0 ? "LIVE · \(secs)s" : "LIVE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Palette.green)
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(Palette.green.opacity(0.10)))
            .overlay(Capsule().stroke(Palette.green.opacity(0.35), lineWidth: 1))
        }
    }
}

// ---- HUD cu toate informațiile ----
struct StatusHUD: View {
    @ObservedObject var service: SupabaseService
    @ObservedObject var loc: LocationManager

    private var cameraGranted: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    private func pill(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(color)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.12)))
            .overlay(Capsule().stroke(color.opacity(0.4), lineWidth: 1))
    }

    var body: some View {
        let active = service.activeZones
        let d = defconLevel(active)
        let cur = currentZone(loc.coordinate, active)

        VStack(alignment: .leading, spacing: 8) {
            if !cameraGranted || !loc.authorized {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(permissionText)
                }
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(Palette.amber)
            }

            HStack(spacing: 8) {
                Text("BRUIAJ AR")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundColor(Palette.cyan)
                pill("DEFCON \(d)·\(defconLabel(d))", defconColor(d))
                Spacer()
                LivePill(lastSync: service.lastSync)
                if service.isLoading { ProgressView().scaleEffect(0.7).tint(Palette.cyan) }
                Button { Task { await service.loadZones() } } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .bold)).foregroundColor(Palette.txt)
                }
            }

            Group {
                if let z = cur {
                    Text("⚠︎ EȘTI ÎN BRUIAJ: \(z.name) · \(z.jammerLabel) · \(z.band) · \(Int(z.intensity))%")
                        .foregroundColor(Palette.red)
                } else if loc.coordinate == nil {
                    Text("Se așteaptă semnal GPS…").foregroundColor(Palette.amber)
                } else {
                    Text("În afara zonelor de bruiaj active.").foregroundColor(Palette.green)
                }
            }
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Text("SPECTRU GNSS/RF")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Palette.txtDim)
                Spacer()
                Text("\(active.count) ZONE ACTIVE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(active.isEmpty ? Palette.txtDim : Palette.red)
            }
            SpectrumStrip(active: active)

            if let e = service.errorText {
                Text(e)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Palette.amber)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(.black.opacity(0.55)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.cyan.opacity(0.22), lineWidth: 1))
        .padding(.horizontal, 10)
        .padding(.top, 8)
    }

    private var permissionText: String {
        if !cameraGranted && !loc.authorized { return "Acordă acces la CAMERĂ și LOCAȚIE (Setări › Bruiaj AR)." }
        if !cameraGranted { return "Acordă acces la CAMERĂ (Setări › Bruiaj AR)." }
        return "Acordă acces la LOCAȚIE (Setări › Bruiaj AR)."
    }
}

struct SpectrumStrip: View {
    let active: [Zone]
    var body: some View {
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(AR_BANDS) { b in
                let e = bandEnergy(b.id, active)
                VStack(spacing: 3) {
                    ZStack(alignment: .bottom) {
                        Capsule().fill(Palette.cyan.opacity(0.10)).frame(width: 9, height: 32)
                        Capsule()
                            .fill(LinearGradient(
                                colors: e > 0 ? [Palette.red, Palette.amber] : [Palette.cyan.opacity(0.5), Palette.cyan.opacity(0.22)],
                                startPoint: .bottom, endPoint: .top))
                            .frame(width: 9, height: max(5, CGFloat(6 + e * 26)))
                            .shadow(color: e > 0 ? Palette.red.opacity(0.7) : .clear, radius: 4)
                    }
                    Text(b.label)
                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                        .foregroundColor(Palette.txtDim)
                }
            }
            Spacer()
        }
        .frame(height: 46, alignment: .bottom)
    }
}