import SwiftUI
import CoreLocation

struct RadarView: View {
    let zones: [Zone]
    let user: CLLocationCoordinate2D?
    let heading: Double

    /// km -> fracție din raza radarului (0.08..1). 60 km = marginea.
    private func radiusFraction(_ km: Double) -> CGFloat {
        CGFloat(min(1.0, max(0.08, km / 60.0)))
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let R = side / 2 - 20
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            ZStack {
                // inele
                ForEach(1...3, id: \.self) { i in
                    Circle()
                        .stroke(Palette.cyan.opacity(0.18), lineWidth: 1)
                        .frame(width: R * 2 * CGFloat(i) / 3, height: R * 2 * CGFloat(i) / 3)
                        .position(center)
                }
                // cruce
                Path { p in
                    p.move(to: CGPoint(x: center.x - R, y: center.y))
                    p.addLine(to: CGPoint(x: center.x + R, y: center.y))
                    p.move(to: CGPoint(x: center.x, y: center.y - R))
                    p.addLine(to: CGPoint(x: center.x, y: center.y + R))
                }
                .stroke(Palette.cyan.opacity(0.12), lineWidth: 1)

                // marcaj Nord (rotește cu heading-ul)
                let nA = (-heading) * .pi / 180
                Text("N")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Palette.red)
                    .position(x: center.x + (R - 4) * CGFloat(sin(nA)),
                              y: center.y - (R - 4) * CGFloat(cos(nA)))

                // tu (centru)
                Circle().fill(Palette.cyan).frame(width: 10, height: 10).position(center)

                // blip-uri
                if let user = user {
                    ForEach(zones.filter { $0.isActive }) { z in
                        let to = CLLocationCoordinate2D(latitude: z.latitude, longitude: z.longitude)
                        let km = distanceMeters(user, to) / 1000.0
                        let rel = (bearingDegrees(user, to) - heading) * .pi / 180
                        let rr = R * radiusFraction(km)
                        let pt = CGPoint(x: center.x + rr * CGFloat(sin(rel)),
                                         y: center.y - rr * CGFloat(cos(rel)))
                        ZStack {
                            Circle().fill(Color(hex: z.color)).frame(width: 12, height: 12)
                            Circle().stroke(Color(hex: z.color).opacity(0.5), lineWidth: 1).frame(width: 22, height: 22)
                        }
                        .position(pt)
                    }
                } else {
                    Text("Se așteaptă GPS…")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Palette.amber)
                        .position(x: center.x, y: center.y + R + 12)
                }
            }
        }
    }
}
