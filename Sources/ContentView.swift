import SwiftUI

struct ContentView: View {
    @StateObject private var service = SupabaseService()
    @StateObject private var loc = LocationManager()
    @State private var selection = 2   // pornește direct pe AR

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                ZonesListView(zones: service.zones, user: loc.coordinate)
                    .navigationTitle("Zone")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
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
            VStack {
                HUDBar(service: service, loc: loc)
                Spacer()
            }
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
                HUDBar(service: service, loc: loc)
                Spacer()
                if loc.coordinate == nil {
                    Text("Se așteaptă semnal GPS…")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(Palette.amber)
                        .padding(8)
                        .background(.black.opacity(0.5))
                        .padding(.bottom, 28)
                }
            }
        }
    }
}

struct HUDBar: View {
    @ObservedObject var service: SupabaseService
    @ObservedObject var loc: LocationManager
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 10) {
                Text("BRUIAJ AR")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Palette.cyan)
                Text("\(service.activeZones.count) active")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Palette.red)
                Spacer()
                if service.isLoading { ProgressView().tint(Palette.cyan) }
                Button { Task { await service.loadZones() } } label: {
                    Image(systemName: "arrow.clockwise").foregroundColor(Palette.txt)
                }
            }
            if let e = service.errorText {
                Text(e)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Palette.amber)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)
            }
        }
        .padding(10)
        .background(.black.opacity(0.45))
    }
}
