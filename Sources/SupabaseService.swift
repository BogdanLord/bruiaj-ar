import Foundation

@MainActor
final class SupabaseService: ObservableObject {
    @Published var zones: [Zone] = []
    @Published var isLoading = false
    @Published var errorText: String?
    @Published var lastSync: Date?

    private var pollTask: Task<Void, Never>?

    var activeZones: [Zone] { zones.filter { $0.isActive } }

    // Reîmprospătare automată la fiecare `seconds` secunde (silent: fără spinner).
    func startAutoRefresh(every seconds: UInt64 = 5) {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
                if Task.isCancelled { break }
                await self?.loadZones(showSpinner: false)
            }
        }
    }

    func stopAutoRefresh() {
        pollTask?.cancel()
        pollTask = nil
    }

    func loadZones() async { await loadZones(showSpinner: true) }

    func loadZones(showSpinner: Bool) async {
        if showSpinner { isLoading = true }
        defer { if showSpinner { isLoading = false } }

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
        req.cachePolicy = .reloadIgnoringLocalCacheData
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
            self.errorText = nil
        } catch {
            errorText = "Eroare rețea/decodare: \(error.localizedDescription)"
        }
    }
}