import Foundation

actor LocalStore {
    private let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.directory = support.appendingPathComponent("ResetRadar", isDirectory: true)
        }
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadEvents() -> [ResetEvent] { load([ResetEvent].self, from: "events.json") ?? [] }
    func loadStatuses() -> [SourceStatus] { load([SourceStatus].self, from: "source-status.json") ?? [] }
    func loadPreferences() -> UserPreferences { load(UserPreferences.self, from: "preferences.json") ?? .defaults }

    func saveEvents(_ events: [ResetEvent]) throws { try save(events, to: "events.json") }
    func saveStatuses(_ statuses: [SourceStatus]) throws { try save(statuses, to: "source-status.json") }
    func savePreferences(_ preferences: UserPreferences) throws { try save(preferences, to: "preferences.json") }

    private func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        let url = directory.appendingPathComponent(name)
        let backup = directory.appendingPathComponent(name + ".backup")
        if let data = try? Data(contentsOf: url), let value = try? decoder.decode(type, from: data) { return value }
        if let data = try? Data(contentsOf: backup), let value = try? decoder.decode(type, from: data) { return value }
        return nil
    }

    private func save<T: Encodable>(_ value: T, to name: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        let backup = directory.appendingPathComponent(name + ".backup")
        let temporary = directory.appendingPathComponent(name + ".temporary")
        let data = try encoder.encode(value)
        if FileManager.default.fileExists(atPath: url.path) {
            if FileManager.default.fileExists(atPath: backup.path) { try FileManager.default.removeItem(at: backup) }
            try FileManager.default.copyItem(at: url, to: backup)
        }
        try data.write(to: temporary, options: [.atomic])
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        try FileManager.default.moveItem(at: temporary, to: url)
    }
}
