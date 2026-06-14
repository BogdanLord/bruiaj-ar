import SwiftUI
import CoreLocation

struct RadarView: View {
    let zones: [Zone]
    let user: CLLocationCoordinate2D?
    let heading: Double

    private func niceCeil(_ v: Double) -> Double {
        let steps: [Double] = [20, 50, 100, 200, 300, 500, 800, 1000, 1500, 2000]
        return steps.first(where: { $0 >= v }) ?? (ceil(v / 100) * 100)
    }

    var body: some View {
        let active = zones.filter { $0.isActive }
        let dists: [Double] = user.map { u in
            active.map { distanceMeters(u, CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)) / 1000 }
        } ?? []
        let maxKm = niceCeil(max((dists.max() ?? 0) * 1.12, 20))

        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let R = side / 2 - 26
            let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            TimelineView(.animation) { tl in
                let now = tl.date.timeIntervalSinceReferenceDate
                let sweep = Angle(degrees: (now * 55).truncatingRemainder(dividingBy: 360))

                ZStack {
                    // fundal scope: glow radial
                    Circle()
                        .fill(RadialGradient(colors: [Palette.green.opacity(0.10), Color(hex: "#02140e").opacity(0.85), .black.opacity(0.92)],
                                             center: .center, startRadius: 0, endRadius: R))
                        .frame(width: R * 2, height: R * 2)
                        .position(c)

                    // spițe la 30°
                    ForEach(0..<12, id: \.self) { i in
                        Rectangle()
                            .fill(Palette.cyan.opacity(0.10))
                            .frame(width: 1, height: R)
                            .offset(y: -R / 2)
                            .rotationEffect(.degrees(Double(i) * 30))
                            .position(c)
                    }

                    // inele + etichete km
                    ForEach(1...4, id: \.self) { i in
                        let rr = R * CGFloat(i) / 4
                        Circle()
                            .stroke(Palette.cyan.opacity(i == 4 ? 0.32 : 0.16), lineWidth: i == 4 ? 1.4 : 1)
                            .frame(width: rr * 2, height: rr * 2)
                            .position(c)
                        Text("\(Int(maxKm * Double(i) / 4))")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(Palette.cyan.opacity(0.55))
                            .position(x: c.x + 9, y: c.y - rr + 7)
                    }

                    // sweep rotativ
                    ZStack {
                        Circle()
                            .fill(AngularGradient(gradient: Gradient(stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: Palette.green.opacity(0.0), location: 0.72),
                                .init(color: Palette.green.opacity(0.28), location: 0.96),
                                .init(color: Palette.green.opacity(0.85), location: 1.0),
                            ]), center: .center))
                        Rectangle()
                            .fill(LinearGradient(colors: [Palette.green.opacity(0.0), Palette.green],
                                                 startPoint: .bottom, endPoint: .top))
                            .frame(width: 2, height: R)
                            .offset(y: -R / 2)
                    }
                    .frame(width: R * 2, height: R * 2)
                    .rotationEffect(sweep)
                    .clipShape(Circle())
                    .blendMode(.screen)
                    .position(c)

                    // bezel + gradații (busolă heading-up: roteste cu -heading)
                    Circle().stroke(Palette.cyan.opacity(0.45), lineWidth: 2)
                        .frame(width: R * 2, height: R * 2).position(c)
                    ForEach(0..<72, id: \.self) { i in
                        let major = i % 6 == 0
                        Rectangle()
                            .fill(Palette.cyan.opacity(major ? 0.7 : 0.3))
                            .frame(width: major ? 2 : 1, height: major ? 9 : 5)
                            .offset(y: -R + (major ? 4.5 : 2.5))
                            .rotationEffect(.degrees(Double(i) * 5 - heading))
                            .position(c)
                    }
                    ForEach(Array(["N", "E", "S", "V"].enumerated()), id: \.offset) { idx, lab in
                        let a = (Double(idx) * 90 - heading) * .pi / 180
                        Text(lab)
                            .font(.system(size: 12, weight: .heavy, design: .monospaced))
                            .foregroundColor(lab == "N" ? Palette.red : Palette.cyan.opacity(0.8))
                            .position(x: c.x + (R - 16) * CGFloat(sin(a)),
                                      y: c.y - (R - 16) * CGFloat(cos(a)))
                    }

                    // tu (centru)
                    let blink = 0.55 + 0.45 * sin(now * 3)
                    Circle().fill(Palette.cyan.opacity(0.25)).frame(width: 22, height: 22)
                        .scaleEffect(1 + 0.25 * sin(now * 2)).position(c)
                    Circle().fill(Palette.cyan).frame(width: 9, height: 9)
                        .shadow(color: Palette.cyan, radius: 5).opacity(blink).position(c)

                    // blip-uri
                    if user != nil {
                        ForEach(Array(active.enumerated()), id: \.element.id) { i, z in
                            let km = dists.indices.contains(i) ? dists[i] : 0
                            let rel = (bearingDegrees(user!, CLLocationCoordinate2D(latitude: z.latitude, longitude: z.longitude)) - heading) * .pi / 180
                            let rr = R * CGFloat(min(1.0, km / maxKm))
                            let pt = CGPoint(x: c.x + rr * CGFloat(sin(rel)), y: c.y - rr * CGFloat(cos(rel)))
                            let zc = Color(hex: z.color)
                            let dia = 9 + CGFloat(z.intensity / 100) * 9
                            let ping = (now + Double(i) * 0.4).truncatingRemainder(dividingBy: 1.8) / 1.8

                            ZStack {
                                Circle().stroke(zc.opacity(0.9 * (1 - ping)), lineWidth: 2)
                                    .frame(width: 14 + ping * 40, height: 14 + ping * 40)
                                Circle().fill(zc.opacity(0.18)).frame(width: dia * 2.4, height: dia * 2.4)
                                Circle().fill(zc).frame(width: dia, height: dia)
                                    .shadow(color: zc, radius: 6)
                                Text("\(Int(km))km")
                                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.9))
                                    .offset(y: -dia)
                            }
                            .position(pt)
                        }
                    } else {
                        Text("SE AȘTEAPTĂ GPS…")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(Palette.amber)
                            .position(x: c.x, y: c.y + R + 14)
                    }

                    // readout colțuri
                    VStack { Spacer()
                        HStack {
                            Text("RANGE \(Int(maxKm)) KM").foregroundColor(Palette.cyan.opacity(0.7))
                            Spacer()
                            Text("HDG \(Int(heading.rounded()))°").foregroundColor(Palette.cyan.opacity(0.7))
                        }
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 18).padding(.bottom, 6)
                    }
                }
            }
        }
    }
}