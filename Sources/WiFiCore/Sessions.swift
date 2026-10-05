import Foundation

public struct MeasurementSession: Codable, Identifiable, Sendable {
    public var version = 1
    public var id = UUID()
    public var name: String
    public var note: String
    public var startedAt: Date
    public var endedAt: Date?
    public var threshold: Int
    public var sampleInterval: Double
    public var samples: [LinkSample]
    public var networks: [NetworkRecord]
    public var events: [SignalEvent]
    public init(name: String, note: String = "", threshold: Int, sampleInterval: Double, startedAt: Date = Date(), samples: [LinkSample] = [], networks: [NetworkRecord] = [], events: [SignalEvent] = []) {
        self.name = name; self.note = note; self.threshold = threshold; self.sampleInterval = sampleInterval
        self.startedAt = startedAt; self.samples = samples; self.networks = networks; self.events = events
    }
    public static func decode(_ data: Data) throws -> Self {
        guard data.count <= 25_000_000 else { throw SessionError.invalid }
        let s = try JSONDecoder().decode(Self.self, from: data)
        guard s.version == 1, !s.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              s.name.count <= 200, s.note.count <= 5_000, s.samples.count <= 3_600, s.events.count <= 10_000, s.networks.count <= 10_000,
              (-90 ... -50).contains(s.threshold), [1.0, 2, 5].contains(s.sampleInterval),
              s.startedAt.timeIntervalSince1970.isFinite,
              s.endedAt.map({ $0 >= s.startedAt && $0.timeIntervalSince1970.isFinite }) ?? true,
              Set(s.samples.map(\.id)).count == s.samples.count,
              Set(s.events.map(\.id)).count == s.events.count,
              Set(s.networks.map(\.id)).count == s.networks.count,
              s.events.allSatisfy({ event in event.timestamp.timeIntervalSince1970.isFinite && event.timestamp >= s.startedAt && (s.endedAt.map { event.timestamp <= $0 } ?? true) }),
              s.samples.allSatisfy({ sample in
                  sample.timestamp >= s.startedAt && sample.timestamp.timeIntervalSince1970.isFinite &&
                  (s.endedAt.map { sample.timestamp <= $0 } ?? true) &&
                  (sample.rssi.map { Signal.valid($0) != nil } ?? true) &&
                  (sample.noise.map { Signal.valid($0) != nil } ?? true) &&
                  (sample.rate.map { $0.isFinite && $0 >= 0 } ?? true)
              }), zip(s.samples, s.samples.dropFirst()).allSatisfy({ $0.timestamp <= $1.timestamp }) else { throw SessionError.invalid }
        return s
    }
}
public enum SessionError: LocalizedError {
    case invalid
    public var errorDescription: String? { "ไฟล์รอบงานไม่ถูกต้อง เวอร์ชันไม่รองรับ หรือมีข้อมูลเกินขอบเขต" }
}
public struct SessionComparison: Sendable {
    public let before: SignalSummary
    public let after: SignalSummary
    public let threshold: Int
    public var delta: Double? {
        guard let a = before.mean, let b = after.mean else { return nil }; return b - a
    }
    public init(before: MeasurementSession, after: MeasurementSession, threshold: Int) {
        self.threshold = threshold
        self.before = SignalSummary(samples: before.samples, threshold: threshold)
        self.after = SignalSummary(samples: after.samples, threshold: threshold)
    }
}

/// Files are immutable to users while recording; writes replace atomically inside a serial actor.
public actor SessionArchive {
    public let directory: URL
    public init(directory: URL) { self.directory = directory }
    public func save(_ session: MeasurementSession) throws {
        let data = try JSONEncoder().encode(session)
        _ = try MeasurementSession.decode(data)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let file = directory.appendingPathComponent(session.id.uuidString + ".json")
        try data.write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }
    public func list() throws -> (sessions: [MeasurementSession], skipped: Int) {
        guard FileManager.default.fileExists(atPath: directory.path) else { return ([], 0) }
        var sessions: [MeasurementSession] = []; var skipped = 0; var ids = Set<UUID>()
        for url in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey]) where url.pathExtension == "json" {
            do {
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= 25_000_000 else { throw SessionError.invalid }
                let session = try MeasurementSession.decode(Data(contentsOf: url))
                guard ids.insert(session.id).inserted else { throw SessionError.invalid }
                sessions.append(session)
            } catch { skipped += 1 }
        }
        return (sessions.sorted { $0.startedAt > $1.startedAt }, skipped)
    }
}
