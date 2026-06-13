import Foundation
import CoreLocation
import UIKit

/// Distanța în metri între două coordonate.
func distanceMeters(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
    let la = CLLocation(latitude: a.latitude, longitude: a.longitude)
    let lb = CLLocation(latitude: b.latitude, longitude: b.longitude)
    return la.distance(from: lb)
}

/// Azimutul (0..360, 0 = Nord, sens orar) de la a către b.
func bearingDegrees(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
    let lat1 = a.latitude * .pi / 180
    let lat2 = b.latitude * .pi / 180
    let dLon = (b.longitude - a.longitude) * .pi / 180
    let y = sin(dLon) * cos(lat2)
    let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
    let deg = atan2(y, x) * 180 / .pi
    return (deg + 360).truncatingRemainder(dividingBy: 360)
}

extension UIColor {
    convenience init(hex raw: String) {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = CGFloat((v & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((v & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(v & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
