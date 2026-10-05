import Foundation

public struct SignalSummary: Sendable {
    public let total: Int
    public let valid: Int
    public let minimum: Int?
    public let maximum: Int?
    public let mean: Double?
    public let deviation: Double?
    public let belowThreshold: Int
    public let threshold: Int
    public var belowPercent: Double? { valid == 0 ? nil : Double(belowThreshold) / Double(valid) * 100 }
    public init(samples: [LinkSample], threshold: Int = -70) {
        let values = samples.compactMap(\.rssi).filter { Signal.valid($0) != nil }
        self.total = samples.count; self.valid = values.count; self.threshold = threshold
        self.minimum = values.min(); self.maximum = values.max()
        self.belowThreshold = values.filter { $0 < threshold }.count
        if values.isEmpty { mean = nil; deviation = nil }
        else {
            let average = Double(values.reduce(0, +)) / Double(values.count)
            mean = average
            deviation = sqrt(values.reduce(0.0) { $0 + pow(Double($1) - average, 2) } / Double(values.count))
        }
    }
}
public struct SignalEvent: Codable, Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let kind: String
    public let detail: String
    public let interface: String
    public init(timestamp: Date, kind: String, detail: String, interface: String) {
        id = UUID(); self.timestamp = timestamp; self.kind = kind; self.detail = detail; self.interface = interface
    }
}
/// Observed changes only. Missing BSSIDs are never interpreted as roaming.
public struct SignalObserver: Sendable {
    private var previous: LinkSample?
    private var lowCount = 0
    private var isLow = false
    public init() {}
    public mutating func reset() { previous = nil; lowCount = 0; isLow = false }
    public mutating func consume(_ sample: LinkSample, threshold: Int, maximumGap: Double) -> [SignalEvent] {
        var events: [SignalEvent] = []
        func event(_ kind: String, _ detail: String) -> SignalEvent {
            SignalEvent(timestamp: sample.timestamp, kind: kind, detail: detail, interface: sample.interface)
        }
        if let old = previous, old.interface != sample.interface || sample.timestamp.timeIntervalSince(old.timestamp) > maximumGap {
            reset()
        }
        if let old = previous {
            if old.rssi != nil && sample.rssi == nil { events.append(event("ไม่มีค่าสัญญาณ", "ระบบหยุดรายงาน RSSI ตรวจ Wi-Fi และสถานะ adapter; ไม่ใช่หลักฐานว่าอินเทอร์เน็ตล่ม")) }
            if old.rssi == nil && sample.rssi != nil { events.append(event("กลับมาอ่านค่าได้", "ระบบรายงาน RSSI อีกครั้ง")) }
            if let a = old.bssid, !a.isEmpty, let b = sample.bssid, !b.isEmpty, a.lowercased() != b.lowercased() {
                events.append(event("เปลี่ยน AP", "BSSID \(a) → \(b) อาจเกิด roaming หรือเปลี่ยนเครือข่าย"))
            }
            if let a = old.channel, let b = sample.channel, old.rssi != nil, sample.rssi != nil, a != b || old.band != sample.band {
                events.append(event("เปลี่ยนช่อง", "\(old.band.rawValue) CH \(a) → \(sample.band.rawValue) CH \(b)"))
            }
        }
        if let rssi = sample.rssi {
            if rssi < threshold {
                lowCount += 1
                if lowCount >= 3 && !isLow {
                    isLow = true
                    events.append(event("สัญญาณอ่อน", "RSSI ต่ำกว่า \(threshold) dBm ติดต่อกัน 3 ตัวอย่าง; ล่าสุด \(rssi) dBm"))
                }
            } else {
                lowCount = 0
                if isLow && rssi >= threshold + 3 {
                    isLow = false
                    events.append(event("สัญญาณฟื้นตัว", "RSSI กลับถึง \(rssi) dBm (เกณฑ์ฟื้นตัว \(threshold + 3) dBm)"))
                }
            }
        } else { lowCount = 0; isLow = false }
        previous = sample
        return events
    }
}
public enum NetworkSort: String, CaseIterable, Sendable {
    case strongest = "แรง → อ่อน", weakest = "อ่อน → แรง", name = "ชื่อ SSID", channel = "ย่าน / ช่อง"
    public func sort(_ records: [NetworkRecord]) -> [NetworkRecord] {
        records.sorted { a, b in
            switch self {
            case .strongest, .weakest:
                if a.rssi == nil && b.rssi != nil { return false }
                if a.rssi != nil && b.rssi == nil { return true }
                if let x = a.rssi, let y = b.rssi, x != y { return self == .strongest ? x > y : x < y }
            case .name:
                if a.name != b.name { return a.name.localizedStandardCompare(b.name) == .orderedAscending }
            case .channel:
                let bands: [Band: Int] = [.two: 0, .five: 1, .six: 2, .unknown: 3]
                if a.band != b.band { return bands[a.band, default: 3] < bands[b.band, default: 3] }
                if a.channel != b.channel { return a.channel < b.channel }
            }
            return a.id < b.id
        }
    }
}
public extension CSV {
    static func history(_ samples: [LinkSample]) -> String {
        "timestamp,interface,ssid,bssid,band,channel,rssi_dbm,noise_dbm,snr_db,tx_rate_mbps\r\n" + samples.map { s in
            row([s.timestamp.ISO8601Format(), s.interface, s.ssid ?? "", s.bssid ?? "", s.band.rawValue, s.channel.map(String.init) ?? "", s.rssi.map(String.init) ?? "", s.noise.map(String.init) ?? "", s.snr.map(String.init) ?? "", s.rate.map { String($0) } ?? ""])
        }.joined(separator: "\r\n")
    }
    static func events(_ events: [SignalEvent]) -> String {
        "timestamp,interface,event,detail\r\n" + events.map { row([$0.timestamp.ISO8601Format(), $0.interface, $0.kind, $0.detail]) }.joined(separator: "\r\n")
    }
}
