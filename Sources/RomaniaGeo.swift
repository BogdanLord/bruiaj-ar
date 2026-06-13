// AUTO-GENERAT (din romaniaGeo.ts + outline johan/world.geo.json), proiectat în spațiul 1000x730.
import Foundation
import simd

enum RoGeo {
    static let viewW: Float = 1000.0
    static let viewH: Float = 730.1
    static let lonMin = 20.263331
    static let latMax = 48.265448
    static let cosLat = 0.695379
    static let S = 139.932300
    static let pad = 40.0

    /// lon/lat -> punct în spațiul hărții (x:0..viewW, y:0..viewH, y în jos)
    static func project(lon: Double, lat: Double) -> SIMD2<Float> {
        let x = (lon - lonMin) * cosLat * S + Double(pad)
        let y = (latMax - lat) * S + Double(pad)
        return SIMD2<Float>(Float(x), Float(y))
    }

    /// conturul României (puncte proiectate)
    static let outline: [SIMD2<Float>] = [
        SIMD2<Float>(278.1, 93.6),
        SIMD2<Float>(320.1, 63.7),
        SIMD2<Float>(380.3, 79.2),
        SIMD2<Float>(442.7, 79.7),
        SIMD2<Float>(487.9, 113.9),
        SIMD2<Float>(521.1, 92.4),
        SIMD2<Float>(593.0, 78.9),
        SIMD2<Float>(617.4, 46.2),
        SIMD2<Float>(658.5, 46.3),
        SIMD2<Float>(688.1, 59.9),
        SIMD2<Float>(718.3, 101.4),
        SIMD2<Float>(749.1, 160.4),
        SIMD2<Float>(805.3, 243.6),
        SIMD2<Float>(808.4, 305.0),
        SIMD2<Float>(798.1, 364.8),
        SIMD2<Float>(815.6, 428.6),
        SIMD2<Float>(859.0, 454.4),
        SIMD2<Float>(904.7, 431.9),
        SIMD2<Float>(948.8, 455.9),
        SIMD2<Float>(951.1, 492.0),
        SIMD2<Float>(903.9, 522.1),
        SIMD2<Float>(874.4, 509.0),
        SIMD2<Float>(847.1, 677.8),
        SIMD2<Float>(789.9, 663.1),
        SIMD2<Float>(719.1, 612.2),
        SIMD2<Float>(604.6, 644.8),
        SIMD2<Float>(556.3, 680.5),
        SIMD2<Float>(413.4, 673.1),
        SIMD2<Float>(338.6, 651.3),
        SIMD2<Float>(300.9, 661.5),
        SIMD2<Float>(272.9, 604.0),
        SIMD2<Float>(255.1, 579.6),
        SIMD2<Float>(277.7, 556.0),
        SIMD2<Float>(253.7, 538.6),
        SIMD2<Float>(223.1, 569.9),
        SIMD2<Float>(166.4, 529.3),
        SIMD2<Float>(158.7, 471.6),
        SIMD2<Float>(99.5, 438.7),
        SIMD2<Float>(88.5, 394.2),
        SIMD2<Float>(35.8, 339.2),
        SIMD2<Float>(113.8, 312.8),
        SIMD2<Float>(172.6, 217.9),
        SIMD2<Float>(218.7, 123.0),
        SIMD2<Float>(278.1, 93.6)
    ]

    static let cities: [MapCity] = [
        MapCity(name: "București", lat: 44.4268, lon: 26.1025, tier: 1),
        MapCity(name: "Cluj-Napoca", lat: 46.7712, lon: 23.6236, tier: 1),
        MapCity(name: "Timișoara", lat: 45.7489, lon: 21.2087, tier: 1),
        MapCity(name: "Iași", lat: 47.1585, lon: 27.6014, tier: 1),
        MapCity(name: "Constanța", lat: 44.1733, lon: 28.6383, tier: 1),
        MapCity(name: "Oradea", lat: 47.0722, lon: 21.9211, tier: 1),
        MapCity(name: "Sibiu", lat: 45.7983, lon: 24.1256, tier: 1),
        MapCity(name: "Brașov", lat: 45.658, lon: 25.6012, tier: 2),
        MapCity(name: "Craiova", lat: 44.3302, lon: 23.7949, tier: 2),
        MapCity(name: "Galați", lat: 45.4353, lon: 28.008, tier: 2),
        MapCity(name: "Ploiești", lat: 44.9469, lon: 26.0215, tier: 2),
        MapCity(name: "Arad", lat: 46.1866, lon: 21.3123, tier: 2),
        MapCity(name: "Pitești", lat: 44.8565, lon: 24.8692, tier: 2),
        MapCity(name: "Bacău", lat: 46.567, lon: 26.9146, tier: 2),
        MapCity(name: "Târgu Mureș", lat: 46.5425, lon: 24.5579, tier: 2),
        MapCity(name: "Baia Mare", lat: 47.6573, lon: 23.5681, tier: 2),
        MapCity(name: "Satu Mare", lat: 47.792, lon: 22.885, tier: 2),
        MapCity(name: "Suceava", lat: 47.6514, lon: 26.2556, tier: 2),
        MapCity(name: "Buzău", lat: 45.1486, lon: 26.824, tier: 3),
        MapCity(name: "Botoșani", lat: 47.7486, lon: 26.6694, tier: 3),
        MapCity(name: "Râmnicu Vâlcea", lat: 45.0997, lon: 24.3693, tier: 3),
        MapCity(name: "Drobeta-Turnu Severin", lat: 44.6369, lon: 22.6597, tier: 3),
        MapCity(name: "Focșani", lat: 45.6963, lon: 27.1863, tier: 3),
        MapCity(name: "Tulcea", lat: 45.1714, lon: 28.7917, tier: 3),
        MapCity(name: "Alba Iulia", lat: 46.0667, lon: 23.5833, tier: 3),
        MapCity(name: "Deva", lat: 45.8772, lon: 22.9106, tier: 3)
    ]
}

struct MapCity { let name: String; let lat: Double; let lon: Double; let tier: Int }
