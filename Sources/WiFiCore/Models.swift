import Foundation

public enum Band: String, Codable, CaseIterable, Sendable {
    case two = "2.4 GHz", five = "5 GHz", six = "6 GHz", unknown = "ไม่ทราบ"
    public static func from(raw: Int) -> Band {
        switch raw { case 1: return .two; case 2: return .five; case 3: return .six; default: return .unknown }
    }
    public func frequency(channel: Int) -> Int? {
        switch self {
        case .two: return (1...13).contains(channel) ? 2407 + channel * 5 : channel == 14 ? 2484 : nil
        case .five: return (1...196).contains(channel) ? (channel >= 182 ? 4000 : 5000) + channel * 5 : nil
        case .six: return channel == 2 ? 5935 : (1...233).contains(channel) && (channel - 1) % 4 == 0 ? 5950 + channel * 5 : nil
        case .unknown: return nil
        }
    }
}
public struct NetworkRecord: Identifiable, Codable, Sendable {
    public var id: String
    public var ssid: String?
    public var bssid: String?
    public var rssi: Int?
    public var noise: Int?
    public var channel: Int
    public var band: Band
    public var width: Int?
    public var security: String
    public var standards: [String]
    public var timestamp: Date
    public var snr: Int? { guard let rssi, let noise else { return nil }; return rssi - noise }
    public var name: String { ssid.flatMap { $0.isEmpty ? nil : $0 } ?? "SSID ไม่เปิดเผย / เครือข่ายซ่อน" }
    public var frequency: Int? { band.frequency(channel: channel) }
    public init(id: String, ssid: String?, bssid: String?, rssi: Int?, noise: Int?, channel: Int, band: Band, width: Int?, security: String, standards: [String], timestamp: Date = Date()) {
        self.id = id; self.ssid = ssid; self.bssid = bssid; self.rssi = rssi; self.noise = noise
        self.channel = channel; self.band = band; self.width = width; self.security = security
        self.standards = standards; self.timestamp = timestamp
    }
}
public struct LinkSample: Identifiable, Codable, Sendable {
    public var id: UUID = UUID()
    public var timestamp: Date = Date()
    public var interface: String
    public var powered: Bool
    public var ssid: String?
    public var bssid: String?
    public var rssi: Int?
    public var noise: Int?
    public var rate: Double?
    public var channel: Int?
    public var band: Band
    public var phy: String
    public var country: String?
    public var supportedBands: [Band]
    public var snr: Int? { guard let rssi, let noise else { return nil }; return rssi - noise }
    public init(interface: String, powered: Bool, ssid: String?, bssid: String?, rssi: Int?, noise: Int?, rate: Double?, channel: Int?, band: Band, phy: String, country: String?, supportedBands: [Band]) {
        self.interface = interface; self.powered = powered; self.ssid = ssid; self.bssid = bssid
        self.rssi = rssi; self.noise = noise; self.rate = rate; self.channel = channel; self.band = band
        self.phy = phy; self.country = country; self.supportedBands = supportedBands
    }
}
public struct SurveyPoint: Codable, Identifiable, Sendable {
    public var id: UUID = UUID()
    public var x: Double
    public var y: Double
    public var label: String
    public var sample: LinkSample
    public init(x: Double, y: Double, label: String, sample: LinkSample) {
        self.x = x; self.y = y; self.label = label; self.sample = sample
    }
}
public struct Survey: Codable, Sendable {
    public var version: Int = 1
    public var name: String = "การสำรวจใหม่"
    public var floorPlan: Data?
    public var points: [SurveyPoint] = []
    public init() {}
    public static func decode(_ data: Data) throws -> Survey {
        let result = try JSONDecoder().decode(Survey.self, from: data)
        guard result.version == 1, result.points.count <= 100_000,
              result.points.allSatisfy({ $0.x.isFinite && $0.y.isFinite && (0...1).contains($0.x) && (0...1).contains($0.y) }) else {
            throw ValidationError.invalidSurvey
        }
        return result
    }
}
public enum ValidationError: Error { case invalidSurvey }
public enum Signal {
    public static func valid(_ value: Int) -> Int? { (-127 ... -1).contains(value) ? value : nil }
    public static func quality(_ rssi: Int?) -> String {
        guard let rssi else { return "ไม่มีข้อมูล" }
        switch rssi { case -55...0: return "ดีมาก"; case -67 ... -56: return "ดี"; case -75 ... -68: return "พอใช้"; default: return "อ่อน" }
    }
    public static func advice(rssi: Int?, snr: Int?) -> [String] {
        var result: [String] = []
        if let rssi, rssi < -70 { result.append("สัญญาณอ่อน: ทดสอบใกล้ AP และสำรวจสิ่งกีดขวาง ก่อนพิจารณาย้ายหรือเพิ่ม AP") }
        if let snr, snr < 20 { result.append("SNR ต่ำ: สำรวจช่องข้างเคียงและแหล่งรบกวน ทดลองลดความกว้างช่องแล้ววัดซ้ำ") }
        if rssi == nil { result.append("ยังอ่านสัญญาณไม่ได้: ตรวจการเชื่อมต่อ Wi‑Fi และสิทธิ์ Location Services") }
        if result.isEmpty { result.append("ระดับสัญญาณอยู่ในเกณฑ์ใช้งานทั่วไป หากยังมีปัญหาให้ตรวจ gateway, DNS และ HTTPS") }
        return result
    }
}
public enum CSV {
    public static func cell(_ value: String) -> String {
        // Prevent spreadsheet formula execution when importing untrusted SSIDs / labels.
        let first = value.trimmingCharacters(in: .whitespacesAndNewlines).first
        let numeric = value.range(of: #"^-?[0-9]+(?:\.[0-9]+)?$"#, options: .regularExpression) != nil
        let safe = !numeric && first.map { "=+-@".contains($0) } == true ? "'" + value : value
        return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
    public static func row(_ values: [String]) -> String { values.map(cell).joined(separator: ",") }
    public static func networks(_ records: [NetworkRecord]) -> String {
        let header = "timestamp,ssid,bssid,band,channel,primary_frequency_mhz,width_mhz,rssi_dbm,noise_dbm,snr_db,security,standards"
        return header + "\r\n" + records.map { n in
            row([n.timestamp.ISO8601Format(), n.ssid ?? "", n.bssid ?? "", n.band.rawValue, String(n.channel),
                 n.frequency.map(String.init) ?? "", n.width.map(String.init) ?? "", n.rssi.map(String.init) ?? "",
                 n.noise.map(String.init) ?? "", n.snr.map(String.init) ?? "", n.security, n.standards.joined(separator: "/")])
        }.joined(separator: "\r\n")
    }
    public static func survey(_ survey: Survey) -> String {
        "timestamp,label,x_normalized,y_normalized,ssid,bssid,band,channel,rssi_dbm,noise_dbm,snr_db\r\n" + survey.points.map { p in
            row([p.sample.timestamp.ISO8601Format(), p.label, String(p.x), String(p.y), p.sample.ssid ?? "", p.sample.bssid ?? "", p.sample.band.rawValue,
                 p.sample.channel.map(String.init) ?? "", p.sample.rssi.map(String.init) ?? "", p.sample.noise.map(String.init) ?? "", p.sample.snr.map(String.init) ?? ""])
        }.joined(separator: "\r\n")
    }
}

public enum SampleFreshness: String, Sendable {
    case live = "LIVE", paused = "PAUSED", stale = "STALE", waiting = "WAITING"
    public static func state(timestamp: Date?, now: Date, monitoring: Bool, interval: Double) -> Self {
        guard monitoring else { return .paused }
        guard let timestamp else { return .waiting }
        return now.timeIntervalSince(timestamp) <= max(5, interval * 3) ? .live : .stale
    }
}
public enum SignalGeometry {
    /// Visual scale only. This is not a distance, coverage radius or physical height.
    public static func height(rssi: Int) -> Double { 0.15 + Double(min(-20, max(-100, rssi)) + 100) / 80 * 4.5 }
    public static func surveyPosition(x: Double, y: Double, width: Double, depth: Double) -> (x: Double, z: Double) {
        ((x - 0.5) * width, (y - 0.5) * depth)
    }
}
