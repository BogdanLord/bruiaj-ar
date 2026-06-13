import SwiftUI

// =====================================================================
//  CONFIGURARE — pune aici datele Supabase-ului tău self-hosted.
//  ANON KEY îl găsești în .env-ul instanței (SUPABASE_ANON_KEY / JWT „anon").
// =====================================================================
enum Config {
    static let supabaseURL = "https://supabase.virtual.uoradea.ro"
    static let supabaseAnonKey = "eyJhbGciOiAiSFMyNTYiLCAidHlwIjogIkpXVCJ9.eyJyb2xlIjogImFub24iLCAiaXNzIjogInN1cGFiYXNlIiwgImlhdCI6IDE3MDAwMDAwMDAsICJleHAiOiAxOTAwMDAwMDAwfQ.eFCERyIDXdGWyebj-da04YJVTUmJ1H2UjXt18CJVKzw"

    /// Citește doar zonele active (true) sau toate (false).
    static let activeZonesOnly = false
}

// Paletă (aceiași tokeni ca pe web)
enum Palette {
    static let bg = Color(hex: "#04060c")
    static let cyan = Color(hex: "#2dd4bf")
    static let blue = Color(hex: "#00aaff")
    static let green = Color(hex: "#00ff88")
    static let red = Color(hex: "#ff5555")
    static let amber = Color(hex: "#ffcc00")
    static let violet = Color(hex: "#a855f7")
    static let txt = Color(hex: "#d7f5ef")
    static let txtDim = Color(hex: "#a4c2c8")
    static let line = Color.white.opacity(0.12)
}

extension Color {
    init(hex raw: String) {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v & 0xFF0000) >> 16) / 255.0
        let g = Double((v & 0x00FF00) >> 8) / 255.0
        let b = Double(v & 0x0000FF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}

@main
struct BruiajARApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
