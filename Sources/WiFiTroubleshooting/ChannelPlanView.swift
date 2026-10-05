import SwiftUI
import Charts
import WiFiCore

struct ChannelPlanView: View {
    @EnvironmentObject var store: AppStore
    @State private var band: Band = .two
    @State private var width = 20
    @State private var selectedChannel: Int?
    @State private var supportedOnly = false
    private var channels: [Int] {
        ChannelPlan.centers(band: band, width: width).filter { !supportedOnly || width != 20 || isReported($0) }
    }
    private func isReported(_ channel: Int) -> Bool { store.supportedChannels?.contains { $0.band == band && $0.channel == channel } == true }
    private func count(_ channel: Int) -> Int { store.networks.filter { $0.band == band && $0.channel == channel }.count }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("ย่านความถี่", selection: $band) { ForEach([Band.two, .five, .six], id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                    .onChange(of: band) { width = 20; selectedChannel = nil }
                HStack {
                    Picker("ผังความกว้าง", selection: $width) { ForEach(ChannelPlan.widths(band), id: \.self) { Text($0 == 20 ? "Primary · 20 MHz*" : "Center · \($0) MHz").tag($0) } }.frame(width: 280).onChange(of: width) { selectedChannel = nil; supportedOnly = false }
                    Spacer()
                    Toggle("เฉพาะช่องที่ macOS รายงาน", isOn: $supportedOnly).disabled(width != 20 || store.supportedChannels == nil)
                }
                Panel(title: "\(band.rawValue) · \(width == 20 ? "Primary channel" : "Bonded center channel")") {
                    Text("ประเทศที่อุปกรณ์รายงาน: \(store.link?.country ?? "ไม่เปิดเผย") · อัปเดตความสามารถ: \(store.channelsUpdatedAt?.formatted(date: .omitted, time: .standard) ?? "รอข้อมูล")").font(.caption).foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 10)], spacing: 10) {
                        ForEach(channels, id: \.self) { channel in
                            Button { selectedChannel = channel } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack { Text("CH \(channel)").font(.headline.monospaced()); Spacer(); if width == 20 && store.link?.band == band && store.link?.channel == channel { Image(systemName: "wifi").foregroundStyle(StudioTheme.green) } }
                                    Text("\(ChannelPlan.centerFrequency(band: band, channel: channel, width: width) ?? 0) MHz").font(.caption.monospaced())
                                    if width == 20 {
                                        Text(store.supportedChannels == nil ? "ยังไม่ทราบการรองรับ" : isReported(channel) ? "✓ macOS รายงาน" : "— ไม่อยู่ในผล API").font(.system(size: 10)).foregroundStyle(isReported(channel) ? StudioTheme.green : .secondary)
                                        Text("\(count(channel)) AP" + (ChannelPlan.isPSC(channel, band: band) ? " · PSC" : "")).font(.caption).foregroundStyle(.secondary)
                                    } else { Text("Center / อ้างอิง").font(.caption).foregroundStyle(.secondary) }
                                }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
                                    .background(StudioTheme.band(band).opacity(selectedChannel == channel ? 0.24 : 0.08), in: RoundedRectangle(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(StudioTheme.band(band).opacity(selectedChannel == channel ? 1 : 0.25)))
                            }.buttonStyle(.plain)
                        }
                    }
                    if channels.isEmpty { Text("ไม่มีช่องตรงตัวกรองจากข้อมูล API ปัจจุบัน").foregroundStyle(.secondary) }
                    if let channel = selectedChannel, let frequency = ChannelPlan.centerFrequency(band: band, channel: channel, width: width) {
                        Divider()
                        Text("\(band.rawValue) · \(width == 20 ? "Primary" : "Center") CH \(channel) · \(frequency) MHz").font(.title3.bold()).foregroundStyle(StudioTheme.band(band))
                        if !(band == .two && channel == 14) {
                            Text("ช่วงความถี่ nominal ของผัง \(width) MHz: \(frequency - width / 2)–\(frequency + width / 2) MHz (ไม่ใช่ spectral mask)").font(.caption)
                        }
                        if width == 20 {
                            let aps = store.networks.filter { $0.band == band && $0.channel == channel }
                            ForEach(aps) { n in
                                Text("\(n.name) · \(n.rssi.map { "\($0) dBm" } ?? "RSSI ไม่ทราบ") · ความกว้างที่อ่านได้ \(n.width.map { "\($0) MHz" } ?? "ไม่ทราบ")").font(.caption).textSelection(.enabled)
                            }
                        }
                    }
                }
                BandChannelChart(band: band, records: store.networks.filter { $0.band == band })
                Panel(title: "อ่านผังนี้อย่างไร") {
                    Text("การเลือกช่องในหน้านี้ใช้ดูรายละเอียดเท่านั้น ไม่เปลี่ยนช่องของ router หรือ adapter")
                    Text("เลข primary ของ AP กับเลข center ของช่อง 40/80/160/320 MHz เป็นคนละค่า ตัวอย่าง 5 GHz: primary CH 36 = 5180 MHz; center ของกลุ่ม 80 MHz CH 42 = 5210 MHz")
                    Text("✓ หมายถึง CoreWLAN รายงานช่องสำหรับ adapter และ country code ปัจจุบัน ไม่ใช่การรับรองว่าตั้ง AP ได้ทุกความกว้าง ช่องที่ไม่ปรากฏใน API อาจขึ้นกับรุ่นเครื่อง ประเทศ หรือสถานะระบบ")
                    if band == .two { Text("* CH 1–13 มีจุดกึ่งกลางห่างกัน 5 MHz จึงซ้อนทับกันเมื่อใช้ความกว้าง 20 MHz; CH 14 = 2484 MHz เป็นกรณี legacy 802.11b/22 MHz ที่จำกัดตามประเทศ ไม่ใช่ช่อง OFDM 20 MHz ทั่วไป") }
                    if band == .five { Text("ผังแสดงกลุ่ม WLAN 20 MHz หลัก: 36–64, 100–144 และ 149–177 (ขั้นละ 4) ช่อง DFS และช่วงบนขึ้นกับข้อกำหนดท้องถิ่น ไม่แสดงว่าเป็น DFS โดยเดาจากเลขช่องอย่างเดียว") }
                    if band == .six {
                        Text("ผังปกติ 59 ช่อง: 1, 5, 9 … 233 ห่างกัน 20 MHz พร้อมกรณีพิเศษ CH 2 = 5935 MHz; PSC = 5, 21 … 229 เป็นช่องที่ช่วยการค้นพบ AP ไม่ใช่การรับประกันช่องที่ดีที่สุด")
                        Text("320 MHz แสดง center 31, 63, 95, 127, 159, 191 ซึ่งมีตำแหน่งซ้อนทับกัน ไม่ใช่ 6 ช่องอิสระ; เป็นข้อมูลอ้างอิง ไม่ใช่ความสามารถ 320 MHz ที่ CoreWLAN ตรวจยืนยันแล้ว")
                    }
                    Text("ผังอ้างอิงไม่ใช่รายการอนุญาตทั่วโลกหรือประกาศ กสทช. ใช้ข้อมูลประเทศ/อุปกรณ์ประกอบ และไม่อนุมาน center ของ AP จาก primary + width เมื่อข้อมูลไม่ครบ").font(.caption).foregroundStyle(.secondary)
                    Link("อ้างอิงผังช่องและ primary/center (MathWorks / IEEE Annex E)", destination: URL(string: "https://www.mathworks.com/help/wlan/ug/valid-channel-number-and-bandwidth-combinations.html")!)
                    Link("รายการช่องที่ adapter รองรับ (Apple CoreWLAN)", destination: URL(string: "https://developer.apple.com/documentation/corewlan/cwinterface/supportedwlanchannels()")!)
                }
            }.padding(28)
        }
    }
}

struct BandChannelChart: View {
    var band: Band
    var records: [NetworkRecord]
    private var plotted: [NetworkRecord] { records.filter { $0.band == band && $0.frequency != nil && $0.rssi != nil } }
    private var domain: ClosedRange<Double> {
        let base = ChannelPlan.range(band)
        let values = plotted.compactMap(\.frequency).map(Double.init)
        return min(base.lowerBound, (values.min() ?? base.lowerBound) - 10)...max(base.upperBound, (values.max() ?? base.upperBound) + 10)
    }
    var body: some View {
        Panel(title: "\(band.rawValue) · primary channel / ความถี่ MHz") {
            Chart(plotted) { n in
                if let frequency = n.frequency, let rssi = n.rssi {
                    PointMark(x: .value("MHz", frequency), y: .value("RSSI dBm", rssi)).foregroundStyle(StudioTheme.band(band)).symbolSize(65)
                        .annotation(position: .top) { Text("CH \(n.channel)").font(.system(size: 9, design: .monospaced)) }
                }
            }.chartYScale(domain: -130 ... 0).chartXScale(domain: domain, range: .plotDimension(padding: 28))
                .chartXAxis { AxisMarks(values: ChannelPlan.ticks(band).compactMap { band.frequency(channel: $0) }) { value in
                    AxisGridLine(); AxisTick()
                    AxisValueLabel {
                        if let frequency = value.as(Int.self), let channel = ChannelPlan.ticks(band).first(where: { band.frequency(channel: $0) == frequency }) {
                            VStack { Text("CH \(channel)"); Text("\(frequency)").foregroundStyle(.secondary) }.font(.system(size: 9, design: .monospaced))
                        }
                    }
                } }.chartXAxisLabel("เลขช่อง / ความถี่กึ่งกลาง primary (MHz)").frame(height: 175)
            if plotted.isEmpty { Text("ยังไม่มี AP ที่อ่านสัญญาณได้ในย่านนี้").font(.caption).foregroundStyle(.secondary) }
            Text("จุดเป็น primary ของ AP ไม่ใช่ขอบเขต bonded channel หรือ channel utilization").font(.caption).foregroundStyle(.secondary)
        }
    }
}
