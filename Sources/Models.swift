import Foundation

struct Zone: Identifiable, Decodable, Equatable {
    var id: String
    var name: String
    var latitude: Double
    var longitude: Double
    var radiusKm: Double
    var intensity: Double
    var powerDbm: Double
    var band: String
    var jammerType: String
    var status: String
    var isActive: Bool
    var color: String

    enum CodingKeys: String, CodingKey {
        case id, name, latitude, longitude, intensity, band, status, color
        case radiusKm = "radius_km"
        case powerDbm = "power_dbm"
        case jammerType = "jammer_type"
        case isActive = "is_active"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        // numeric tolerant (PostgREST poate trimite număr SAU string pentru numeric)
        func num(_ k: CodingKeys, _ def: Double) -> Double {
            if let d = try? c.decode(Double.self, forKey: k) { return d }
            if let i = try? c.decode(Int.self, forKey: k) { return Double(i) }
            if let s = try? c.decode(String.self, forKey: k), let d = Double(s) { return d }
            return def
        }

        if let s = try? c.decode(String.self, forKey: .id) {
            id = s
        } else if let i = try? c.decode(Int.self, forKey: .id) {
            id = String(i)
        } else {
            id = UUID().uuidString
        }
        name = (try? c.decode(String.self, forKey: .name)) ?? "Zonă"
        latitude = num(.latitude, 0)
        longitude = num(.longitude, 0)
        radiusKm = num(.radiusKm, 10)
        intensity = num(.intensity, 50)
        powerDbm = num(.powerDbm, 30)
        band = (try? c.decode(String.self, forKey: .band)) ?? "GPS_L1"
        jammerType = (try? c.decode(String.self, forKey: .jammerType)) ?? "barrage"
        status = (try? c.decode(String.self, forKey: .status)) ?? "idle"
        isActive = (try? c.decode(Bool.self, forKey: .isActive)) ?? false
        color = (try? c.decode(String.self, forKey: .color)) ?? "#ff5555"
    }

    var jammerLabel: String {
        switch jammerType {
        case "barrage": return "Baraj"
        case "spot": return "Punctual"
        case "sweep": return "Baleiaj"
        case "pulse": return "Pulsat"
        case "deceptive": return "Decepție"
        default: return jammerType
        }
    }

    var statusLabel: String {
        switch status {
        case "active": return "ACTIV"
        case "scheduled": return "PROGRAMAT"
        case "expired": return "EXPIRAT"
        default: return "INACTIV"
        }
    }
}
