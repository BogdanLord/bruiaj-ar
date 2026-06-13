import Foundation

@MainActor
final class SupabaseService: ObservableObject {
    @Published var zones: [Zone] = []
    @Published var isLoading = false
    @Published var errorText: String?
    @Published var lastSync: Date?

    func loadZones() async {
        isLoading = true
        errorText = nil
        defer { isLoading = false }

        guard var comps = URLComponents(string: "\(Config.supabaseURL)/rest/v1/bruiaj_zones") else {
            errorText = "URL Supabase invalid."
            return
        }
        var items = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: "created_at.asc"),
        ]
        if Config.activeZonesOnly {
            items.append(URLQueryItem(name: "is_active", value: "eq.true"))
        }
        comps.queryItems = items
        guard let url = comps.url else {
            errorText = "Nu pot construi URL-ul cererii."
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(Config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 20

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                let body = String(data: data, encoding: .utf8) ?? ""
                errorText = "HTTP \(http.statusCode). \(body.prefix(180))"
                return
            }
            let decoded = try JSONDecoder().decode([Zone].self, from: data)
            self.zones = decoded
            self.lastSync = Date()
        } catch {
            errorText = "Eroare rețea/decodare: \(error.localizedDescription)"
        }
    }

    var activeZones: [Zone] { zones.filter { $0.isActive } }
}
