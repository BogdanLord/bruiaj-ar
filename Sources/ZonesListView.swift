import SwiftUI
import CoreLocation

struct ZonesListView: View {
    let zones: [Zone]
    let user: CLLocationCoordinate2D?

    var body: some View {
        List {
            if zones.isEmpty {
                Text("Nicio zonă încărcată. Verifică URL-ul Supabase și cheia anon din Config.")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Palette.txtDim)
                    .listRowBackground(Palette.bg)
            }
            ForEach(zones) { z in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Circle().fill(Color(hex: z.color)).frame(width: 10, height: 10)
                        Text(z.name)
                            .font(.system(.headline, design: .monospaced))
                            .foregroundColor(Palette.txt)
                        Spacer()
                        Text(z.statusLabel)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(z.isActive ? Palette.red : Palette.txtDim)
                    }
                    HStack(spacing: 14) {
                        Label(z.band, systemImage: "dot.radiowaves.left.and.right")
                        Label(z.jammerLabel, systemImage: "antenna.radiowaves.left.and.right")
                        Label("\(Int(z.radiusKm)) km", systemImage: "scope")
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Palette.txtDim)

                    if let user = user {
                        let to = CLLocationCoordinate2D(latitude: z.latitude, longitude: z.longitude)
                        let km = distanceMeters(user, to) / 1000.0
                        let brg = bearingDegrees(user, to)
                        Text(String(format: "%.1f km · %.0f° · %.0f dBm · %.0f%%", km, brg, z.powerDbm, z.intensity))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Palette.cyan)
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(Palette.bg)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.bg)
    }
}
