import Foundation
import CoreWLAN
import WiFiCore

actor WiFiService {
    private let client = CWWiFiClient()
    func interfaces() -> [String] { client.interfaceNames() ?? [] }
    private func adapter(_ name: String?) throws -> CWInterface {
        guard let interface = client.interface(withName: name) else { throw ServiceError.noAdapter }
        return interface
    }
    func capabilities(_ name: String?) throws -> [ChannelCapability]? {
        let i = try adapter(name)
        return i.supportedWLANChannels()?.map { channel in
            ChannelCapability(band: Band.from(raw: channel.channelBand.rawValue), channel: channel.channelNumber,
                              width: [1:20, 2:40, 3:80, 4:160][channel.channelWidth.rawValue])
        }
    }
    func sample(_ name: String?) throws -> LinkSample {
        let i = try adapter(name)
        let connected = i.wlanChannel() != nil && i.transmitRate() > 0 && i.powerOn()
        return LinkSample(interface: i.interfaceName ?? "—", powered: i.powerOn(), ssid: i.ssid(), bssid: i.bssid(),
                          rssi: connected ? Signal.valid(i.rssiValue()) : nil, noise: connected ? Signal.valid(i.noiseMeasurement()) : nil,
                          rate: connected ? i.transmitRate() : nil, channel: i.wlanChannel()?.channelNumber,
                          band: Band.from(raw: i.wlanChannel()?.channelBand.rawValue ?? 0), phy: Self.phy(i.activePHYMode().rawValue),
                          country: i.countryCode(), supportedBands: Array(Set((i.supportedWLANChannels() ?? []).map { Band.from(raw: $0.channelBand.rawValue) })).sorted { $0.rawValue < $1.rawValue })
    }
    func scan(_ name: String?) throws -> [NetworkRecord] {
        let i = try adapter(name)
        guard i.powerOn() else { throw ServiceError.powerOff }
        let values = try i.scanForNetworks(withSSID: nil)
        let date = Date()
        return values.map { n in
            let ch = n.wlanChannel
            let band = Band.from(raw: ch?.channelBand.rawValue ?? 0)
            let width = [1: 20, 2: 40, 3: 80, 4: 160][ch?.channelWidth.rawValue ?? 0]
            let standards = (1...7).compactMap { raw -> String? in
                guard let mode = CWPHYMode(rawValue: raw), n.supportsPHYMode(mode) else { return nil }
                return Self.phy(raw)
            }
            let securityValues: [(Int, String)] = [(0,"Open"),(1,"WEP"),(2,"WPA"),(3,"WPA/WPA2"),(4,"WPA2 Personal"),(6,"Dynamic WEP"),(7,"WPA Enterprise"),(8,"WPA/WPA2 Enterprise"),(9,"WPA2 Enterprise"),(11,"WPA3 Personal"),(12,"WPA3 Enterprise"),(13,"WPA2/WPA3"),(14,"OWE"),(15,"OWE Transition")]
            let security = securityValues.compactMap { raw, label -> String? in
                guard let value = CWSecurity(rawValue: raw), n.supportsSecurity(value) else { return nil }; return label
            }.joined(separator: ", ")
            return NetworkRecord(id: "\(n.bssid ?? UUID().uuidString)-\(band.rawValue)-\(ch?.channelNumber ?? 0)", ssid: n.ssid, bssid: n.bssid,
                                 rssi: Signal.valid(n.rssiValue), noise: Signal.valid(n.noiseMeasurement), channel: ch?.channelNumber ?? 0,
                                 band: band, width: width, security: security.isEmpty ? "ไม่ทราบ" : security, standards: standards, timestamp: date)
        }.sorted { ($0.rssi ?? -200) > ($1.rssi ?? -200) }
    }
    static func phy(_ raw: Int) -> String {
        [1:"802.11a",2:"802.11b",3:"802.11g",4:"Wi‑Fi 4 · n",5:"Wi‑Fi 5 · ac",6:"Wi‑Fi 6/6E · ax",7:"Wi‑Fi 7 · be"][raw] ?? "ไม่ทราบ"
    }
}
enum ServiceError: LocalizedError {
    case noAdapter, powerOff
    var errorDescription: String? {
        switch self { case .noAdapter: return "ไม่พบ Wi‑Fi adapter ที่ CoreWLAN รองรับ"; case .powerOff: return "Wi‑Fi ปิดอยู่ เปิด Wi‑Fi ใน System Settings แล้วลองอีกครั้ง" }
    }
}
