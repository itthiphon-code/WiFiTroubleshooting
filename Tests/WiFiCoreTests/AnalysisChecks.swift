import Foundation
import WiFiCore

func measured(_ rssi: Int?, time: Double = 100, bssid: String? = "AA:BB:CC:DD:EE:01", channel: Int = 1) -> LinkSample {
    var sample = LinkSample(interface: "en0", powered: true, ssid: "Test", bssid: bssid, rssi: rssi, noise: -95, rate: 144, channel: channel, band: .two, phy: "ax", country: nil, supportedBands: [.two])
    sample.timestamp = Date(timeIntervalSince1970: time)
    return sample
}
func checkSummary() {
    let empty = SignalSummary(samples: [])
    XCTAssertNil(empty.mean); XCTAssertNil(empty.belowPercent)
    let summary = SignalSummary(samples: [measured(-80), measured(-60), measured(nil)], threshold: -70)
    XCTAssertEqual(summary.total, 3); XCTAssertEqual(summary.valid, 2)
    XCTAssertEqual(summary.mean, -70); XCTAssertEqual(summary.deviation, 10)
    XCTAssertEqual(summary.belowThreshold, 1); XCTAssertEqual(summary.belowPercent, 50)
    XCTAssertEqual(summary.minimum, -80); XCTAssertEqual(summary.maximum, -60)
}
func checkWeakEvents() {
    var observer = SignalObserver()
    func consume(_ rssi: Int?, _ time: Double) -> [SignalEvent] { observer.consume(measured(rssi, time: time), threshold: -70, maximumGap: 5) }
    XCTAssertTrue(consume(-75, 100).isEmpty)
    XCTAssertTrue(consume(-75, 101).isEmpty)
    XCTAssertEqual(consume(-75, 102).map(\.kind), ["สัญญาณอ่อน"])
    XCTAssertTrue(consume(-75, 103).isEmpty)
    XCTAssertTrue(consume(-69, 104).isEmpty)
    XCTAssertEqual(consume(-67, 105).map(\.kind), ["สัญญาณฟื้นตัว"])
    XCTAssertEqual(consume(nil, 106).map(\.kind), ["ไม่มีค่าสัญญาณ"])
    XCTAssertTrue(consume(nil, 107).isEmpty)
    XCTAssertEqual(consume(-60, 108).map(\.kind), ["กลับมาอ่านค่าได้"])
    observer.reset()
    XCTAssertTrue(consume(-60, 109).isEmpty)
    _ = consume(-75, 110); _ = consume(-75, 111)
    XCTAssertTrue(consume(-75, 130).isEmpty) // Samples across a pause must not trigger an alert.
}
func checkAPChanges() {
    var observer = SignalObserver()
    _ = observer.consume(measured(-60, bssid: nil), threshold: -70, maximumGap: 5)
    XCTAssertTrue(observer.consume(measured(-60, time: 101), threshold: -70, maximumGap: 5).isEmpty)
    XCTAssertTrue(observer.consume(measured(-60, time: 102, bssid: "aa:bb:cc:dd:ee:01"), threshold: -70, maximumGap: 5).isEmpty)
    let changed = observer.consume(measured(-60, time: 103, bssid: "AA:BB:CC:DD:EE:02", channel: 6), threshold: -70, maximumGap: 5)
    XCTAssertEqual(changed.map(\.kind), ["เปลี่ยน AP", "เปลี่ยนช่อง"])
    XCTAssertTrue(CSV.events(changed).contains("เปลี่ยน AP"))
    let csv = CSV.history([measured(nil)])
    XCTAssertTrue(csv.contains("timestamp,interface"))
    XCTAssertTrue(csv.contains("\"en0\""))
    XCTAssertTrue(!csv.contains("\"0\""))
}
func checkNetworkSorting() {
    func record(_ id: String, _ rssi: Int?, _ band: Band, _ channel: Int) -> NetworkRecord {
        NetworkRecord(id: id, ssid: id, bssid: nil, rssi: rssi, noise: nil, channel: channel, band: band, width: nil, security: "Unknown", standards: [])
    }
    let records = [record("none", nil, .unknown, 0), record("weak", -90, .two, 11), record("strong", -30, .six, 1)]
    XCTAssertEqual(NetworkSort.strongest.sort(records).map(\.id), ["strong", "weak", "none"])
    XCTAssertEqual(NetworkSort.weakest.sort(records).map(\.id), ["weak", "strong", "none"])
    XCTAssertEqual(NetworkSort.channel.sort(records).map(\.id), ["weak", "strong", "none"])
}
