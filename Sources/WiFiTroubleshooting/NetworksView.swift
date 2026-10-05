import SwiftUI
import Charts
import WiFiCore

struct NetworksView: View {
    @EnvironmentObject var store: AppStore
    @State private var search = ""
    @State private var band = "ทั้งหมด"
    @State private var sort: NetworkSort = .strongest
    @State private var onlyUsable = false
    @State private var selected: NetworkRecord.ID?
    var filtered: [NetworkRecord] {
        sort.sort(store.networks.filter { (band == "ทั้งหมด" || $0.band.rawValue == band) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || ($0.bssid ?? "").localizedCaseInsensitiveContains(search) || $0.security.localizedCaseInsensitiveContains(search)) && (!onlyUsable || ($0.rssi ?? -999) >= -75) })
    }
    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                TextField("ค้นหา SSID / BSSID / Security", text: $search).textFieldStyle(.roundedBorder).frame(maxWidth: 280)
                Picker("ย่าน", selection: $band) { Text("ทั้งหมด").tag("ทั้งหมด"); ForEach(Band.allCases, id: \.self) { Text($0.rawValue).tag($0.rawValue) } }.frame(width: 190)
                Spacer(); Toggle("สแกนอัตโนมัติ ~\(Int(store.scanInterval))s", isOn: $store.autoScan).toggleStyle(.switch)
                Button("CSV ผลที่กรอง") { store.exportNetworks(filtered) }.disabled(filtered.isEmpty)
            }
            HStack {
                Picker("จัดเรียง", selection: $sort) { ForEach(NetworkSort.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.frame(width: 230)
                Toggle("RSSI ≥ −75 dBm", isOn: $onlyUsable)
                Spacer()
                ForEach([Band.two, .five, .six], id: \.self) { band in
                    Text("\(band.rawValue): \(filtered.filter { $0.band == band }.count)").font(.caption.monospaced()).foregroundStyle(StudioTheme.band(band))
                }
            }
            HStack {
                Text("\(filtered.count) access points").font(.headline)
                Spacer(); Text(store.lastScan.map { "สแกนล่าสุด \($0.formatted(date: .omitted, time: .standard))" } ?? "กดสแกนเพื่อเริ่มต้น").foregroundStyle(.secondary).font(.caption)
            }
            Table(filtered, selection: $selected) {
                TableColumn("SSID") { n in Text(n.name).fontWeight(.medium) }.width(min: 140, ideal: 200)
                TableColumn("RSSI") { n in Text(n.rssi.map { "\($0) dBm" } ?? "—").foregroundStyle(signalColor(n.rssi)).monospacedDigit() }.width(78)
                TableColumn("SNR") { n in Text(n.snr.map { "\($0) dB" } ?? "—") }.width(62)
                TableColumn("ย่าน") { n in Text(n.band.rawValue) }.width(75)
                TableColumn("Primary") { n in Text(String(n.channel)) }.width(58)
                TableColumn("ความถี่ MHz") { n in Text(n.frequency.map(String.init) ?? "—") }.width(84)
                TableColumn("กว้าง MHz") { n in Text(n.width.map(String.init) ?? "—") }.width(72)
                TableColumn("Security", value: \.security).width(min: 100, ideal: 135)
                TableColumn("BSSID") { n in Text(n.bssid ?? "ไม่เปิดเผย").font(.system(.caption, design: .monospaced)) }.width(min: 130, ideal: 145)
            }.frame(height: 250)
            if let record = filtered.first(where: { $0.id == selected }) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(record.name) · \(record.security)").textSelection(.enabled)
                    HStack {
                    Text(record.standards.isEmpty ? "มาตรฐานไม่เปิดเผย" : record.standards.joined(separator: " / "))
                    Spacer(); Text(record.frequency.map { "Primary channel: \($0) MHz" } ?? "ความถี่ไม่ทราบ")
                    }
                }.font(.caption).padding(12).background(.teal.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
            ForEach([Band.two, .five, .six].filter { band == "ทั้งหมด" || $0.rawValue == band }, id: \.self) { item in
                BandChannelChart(band: item, records: filtered)
            }
            Text("ผังเลขช่องทั้งหมดและช่อง center ตามความกว้าง ดูที่เมนู ผังช่องสัญญาณ").font(.caption).foregroundStyle(.secondary)
        }.padding(28)
        }
    }
}
