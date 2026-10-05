import SwiftUI
import SceneKit
import WiFiCore

struct SignalColumn: Identifiable {
    var id: String
    var x: Double
    var z: Double
    var rssi: Int
    var title: String
    var detail: String
    var color: NSColor
    var live = false
    var axisLabel: String? = nil
}

/// Retains one scene and updates nodes by identity; polling never resets the user's camera.
struct SignalScene: NSViewRepresentable {
    var columns: [SignalColumn]
    var floorPlan: Data? = nil
    var survey = false
    var animate = true
    var reset: Int = 0
    var onSelect: (String) -> Void = { _ in }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.scene = context.coordinator.scene
        view.backgroundColor = NSColor(red: 0.025, green: 0.045, blue: 0.085, alpha: 1)
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 30
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.defaultCameraController.inertiaEnabled = true
        view.defaultCameraController.target = SCNVector3(0, 0.8, 0)
        context.coordinator.view = view
        context.coordinator.setup()
        let click = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.selectColumn(_:)))
        view.addGestureRecognizer(click)
        view.setAccessibilityLabel("มุมมองสัญญาณสามมิติ ลากเพื่อหมุน เลื่อนเพื่อซูม คลิกแท่งเพื่อดูค่าที่วัด")
        return view
    }
    func updateNSView(_ view: SCNView, context: Context) {
        context.coordinator.onSelect = onSelect
        context.coordinator.update(columns: columns, plan: floorPlan, survey: survey, animate: animate)
        if context.coordinator.reset != reset { context.coordinator.reset = reset; context.coordinator.resetCamera() }
    }
    static func dismantleNSView(_ view: SCNView, coordinator: Coordinator) {
        view.isPlaying = false; view.scene = nil
    }
    final class Coordinator: NSObject {
        let scene = SCNScene()
        let camera = SCNNode()
        let ground = SCNNode()
        let content = SCNNode()
        var nodes: [String: SCNNode] = [:]
        var values: [String: SignalColumn] = [:]
        var oldPlan: Data?
        var oldSurvey: Bool?
        var reset = 0
        var onSelect: (String) -> Void = { _ in }
        weak var view: SCNView?
        func setup() {
            scene.rootNode.addChildNode(camera)
            scene.rootNode.addChildNode(ground)
            scene.rootNode.addChildNode(content)
            camera.camera = SCNCamera()
            camera.camera?.fieldOfView = 36
            camera.camera?.zFar = 150
            resetCamera()
            let ambient = SCNNode(); ambient.light = SCNLight(); ambient.light?.type = .ambient
            ambient.light?.color = NSColor(white: 0.65, alpha: 1); scene.rootNode.addChildNode(ambient)
        }
        func resetCamera() {
            camera.position = SCNVector3(10, 9, 13)
            camera.look(at: SCNVector3(0, 0.7, 0))
            view?.pointOfView = camera
            view?.defaultCameraController.pointOfView = camera
            view?.defaultCameraController.clearRoll()
        }
        func material(_ color: NSColor, glow: CGFloat = 0) -> SCNMaterial {
            let m = SCNMaterial(); m.diffuse.contents = color
            m.emission.contents = color.withAlphaComponent(glow)
            m.lightingModel = .blinn
            m.specular.contents = NSColor(white: 0.65, alpha: 1)
            return m
        }
        func textNode(_ text: String, color: NSColor, size: CGFloat = 0.32) -> SCNNode {
            let textGeometry = SCNText(string: text, extrusionDepth: 0)
            textGeometry.font = .monospacedSystemFont(ofSize: 1, weight: .semibold)
            textGeometry.flatness = 0.2
            textGeometry.firstMaterial = material(color, glow: 0.5)
            let node = SCNNode(geometry: textGeometry)
            node.scale = SCNVector3(size, size, size)
            let bounds = textGeometry.boundingBox
            node.pivot = SCNMatrix4MakeTranslation((bounds.max.x + bounds.min.x) / 2, 0, 0)
            let billboard = SCNBillboardConstraint(); billboard.freeAxes = .Y; node.constraints = [billboard]
            return node
        }
        func updateGround(plan: Data?, survey: Bool) {
            guard oldSurvey != survey || oldPlan != plan else { return }
            oldSurvey = survey; oldPlan = plan
            ground.childNodes.forEach { $0.removeFromParentNode() }
            let image = plan.flatMap(NSImage.init(data:))
            let dimensions = survey ? Self.dimensions(image) : (width: 16.0, depth: 11.0)
            let depth = dimensions.depth
            let plane = SCNPlane(width: dimensions.width, height: depth)
            let m = material(NSColor(red: 0.07, green: 0.12, blue: 0.20, alpha: 1))
            if let image, survey { m.diffuse.contents = image; m.emission.contents = NSColor.black; m.lightingModel = .constant }
            m.isDoubleSided = true; plane.firstMaterial = m
            let floor = SCNNode(geometry: plane); floor.eulerAngles.x = -.pi / 2
            floor.position.y = -0.02; ground.addChildNode(floor)
            if image == nil || !survey {
                for i in -8...8 where abs(Double(i)) <= dimensions.width / 2 {
                    let line = SCNNode(geometry: SCNBox(width: 0.012, height: 0.01, length: depth, chamferRadius: 0))
                    line.geometry?.firstMaterial = material(NSColor.cyan.withAlphaComponent(0.13))
                    line.position.x = CGFloat(i); ground.addChildNode(line)
                }
                for i in -5...5 where abs(Double(i)) <= depth / 2 {
                    let line = SCNNode(geometry: SCNBox(width: dimensions.width, height: 0.01, length: 0.012, chamferRadius: 0))
                    line.geometry?.firstMaterial = material(NSColor.cyan.withAlphaComponent(0.13))
                    line.position.z = CGFloat(i); ground.addChildNode(line)
                }
            }
            if !survey {
                for (label, z, color) in [("CONNECTED", -4.2, NSColor.systemGreen), ("2.4 GHz", -1.5, .cyan), ("5 GHz", 1.4, .systemPurple), ("6 GHz", 4.2, .systemOrange)] {
                    let text = textNode(label, color: color, size: 0.38)
                    text.position = SCNVector3(-6.5, 0.1, z); ground.addChildNode(text)
                }
                for (band, z) in [(Band.two, -1.5), (.five, 1.4), (.six, 4.2)] {
                    for channel in ChannelPlan.ticks(band) {
                        guard let x = ChannelPlan.xPosition(band: band, channel: channel), let mhz = band.frequency(channel: channel) else { continue }
                        let tick = textNode("\(channel) / \(mhz)", color: NSColor(StudioTheme.band(band)), size: 0.17)
                        tick.position = SCNVector3(x, 0.07, z + 0.65); ground.addChildNode(tick)
                    }
                }
            }
        }
        static func dimensions(_ image: NSImage?) -> (width: Double, depth: Double) {
            guard let image, image.size.width > 0, image.size.height > 0 else { return (16, 10) }
            let scale = min(16 / image.size.width, 10 / image.size.height)
            return (image.size.width * scale, image.size.height * scale)
        }
        func update(columns: [SignalColumn], plan: Data?, survey: Bool, animate: Bool) {
            updateGround(plan: plan, survey: survey)
            let ids = Set(columns.map(\.id))
            for id in Array(nodes.keys) where !ids.contains(id) { nodes.removeValue(forKey: id)?.removeFromParentNode(); values.removeValue(forKey: id) }
            for item in columns {
                let root: SCNNode
                if let existing = nodes[item.id] { root = existing }
                else {
                    root = SCNNode(); root.name = item.id
                    let bar = SCNNode(geometry: SCNCylinder(radius: item.live ? 0.32 : 0.23, height: 1)); bar.name = "bar"
                    root.addChildNode(bar)
                    let ring = SCNNode(geometry: SCNTorus(ringRadius: item.live ? 0.60 : 0.32, pipeRadius: 0.024)); ring.name = "ring"; ring.position.y = 0.035
                    root.addChildNode(ring)
                    content.addChildNode(root); nodes[item.id] = root
                }
                let height = SignalGeometry.height(rssi: item.rssi)
                SCNTransaction.begin(); SCNTransaction.animationDuration = animate ? 0.45 : 0
                root.position = SCNVector3(item.x, 0, item.z)
                if let bar = root.childNode(withName: "bar", recursively: false) {
                    bar.scale.y = height; bar.position.y = height / 2
                    bar.geometry?.firstMaterial = material(item.color, glow: 0.25)
                }
                SCNTransaction.commit()
                if values[item.id]?.rssi != item.rssi || values[item.id]?.title != item.title || values[item.id]?.axisLabel != item.axisLabel {
                    root.childNode(withName: "label", recursively: false)?.removeFromParentNode()
                    let label = textNode((item.axisLabel.map { $0 + "\n" } ?? "") + "\(item.rssi) dBm", color: .white, size: item.live ? 0.36 : 0.32)
                    label.name = "label"; label.position.y = height + 0.16; root.addChildNode(label)
                }
                if let ring = root.childNode(withName: "ring", recursively: false) {
                    ring.geometry?.firstMaterial = material(item.color, glow: 0.7)
                    if item.live && animate {
                        if ring.action(forKey: "pulse") == nil {
                            ring.runAction(.repeatForever(.sequence([.fadeOpacity(to: 0.25, duration: 0.8), .fadeOpacity(to: 1, duration: 0.8)])), forKey: "pulse")
                        }
                    } else { ring.removeAction(forKey: "pulse"); ring.opacity = 1 }
                }
                values[item.id] = item
            }
            // Static scenes render on demand. Only the connected sample has an animated pulse.
            view?.isPlaying = animate && columns.contains(where: \.live)
        }
        @objc func selectColumn(_ gesture: NSClickGestureRecognizer) {
            guard let view else { return }
            let hit = view.hitTest(gesture.location(in: view), options: [:])
            for result in hit {
                var node: SCNNode? = result.node
                while let current = node {
                    if let name = current.name, let value = values[name] { onSelect(value.detail); return }
                    node = current.parent
                }
            }
        }
    }
}

struct SignalStage: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var reset = 0
    @State private var selected = "คลิกแท่งสัญญาณเพื่อดูรายละเอียด"
    var survey = false
    var columns: [SignalColumn] {
        if survey {
            let dimensions = SignalScene.Coordinator.dimensions(store.survey.floorPlan.flatMap(NSImage.init(data:)))
            return store.survey.points.suffix(300).compactMap { p in
                guard let rssi = p.sample.rssi else { return nil }
                let position = SignalGeometry.surveyPosition(x: p.x, y: p.y, width: dimensions.width, depth: dimensions.depth)
                return SignalColumn(id: p.id.uuidString, x: position.x, z: position.z, rssi: rssi, title: p.label,
                                    detail: "\(p.label) · \(rssi) dBm · \(p.sample.band.rawValue) · \(p.sample.timestamp.formatted(date: .omitted, time: .standard))", color: NSColor(signalColor(rssi)))
            }
        }
        var result = store.networks.filter { $0.band != .unknown }.prefix(300).compactMap { n -> SignalColumn? in
            guard let rssi = n.rssi, let x = ChannelPlan.xPosition(band: n.band, channel: n.channel) else { return nil }
            return SignalColumn(id: n.id, x: x, z: n.band == .two ? -1.5 : n.band == .five ? 1.4 : 4.2,
                                rssi: rssi, title: n.name, detail: "\(n.name) · \(n.band.rawValue) · CH \(n.channel) / \(n.frequency.map(String.init) ?? "—") MHz · \(rssi) dBm · \(n.timestamp.formatted(date: .omitted, time: .standard))", color: NSColor(StudioTheme.band(n.band)), axisLabel: "CH \(n.channel)")
        }
        if let sample = store.link, let rssi = sample.rssi {
            result.append(SignalColumn(id: "current-link", x: 0, z: -4.2, rssi: rssi, title: "Connected", detail: "เชื่อมต่อปัจจุบัน · \(rssi) dBm · \(sample.band.rawValue) · \(sample.timestamp.formatted(date: .omitted, time: .standard))", color: NSColor(StudioTheme.green), live: true, axisLabel: sample.channel.map { "CH \($0)" }))
        }
        return result
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label(survey ? "SURVEY · 3D" : "SIGNAL SPACE · 3D", systemImage: "cube.transparent").font(.system(size: 12, weight: .bold, design: .monospaced)).tracking(1.4)
                Spacer()
                if survey {
                    HStack(spacing: 10) { Text("● ดี").foregroundStyle(StudioTheme.green); Text("● พอใช้").foregroundStyle(.orange); Text("● อ่อน").foregroundStyle(.red) }.font(.caption)
                } else { BandLegend() }
                Button { reset += 1 } label: { Image(systemName: "arrow.counterclockwise") }.help("คืนมุมกล้อง")
            }.padding(18)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                SignalScene(columns: columns, floorPlan: survey ? store.survey.floorPlan : nil, survey: survey,
                            animate: !reduceMotion && SampleFreshness.state(timestamp: store.link?.timestamp, now: context.date, monitoring: store.monitoring, interval: store.sampleInterval) == .live,
                            reset: reset, onSelect: { selected = $0 })
            }.frame(minHeight: 290, idealHeight: 330)
            VStack(alignment: .leading, spacing: 6) {
                HStack { Text(selected).lineLimit(2); Spacer(); Text("ลาก: หมุน  /  เลื่อน: ซูม").foregroundStyle(.secondary) }.font(.caption)
                Text(survey ? "ตำแหน่งจากแผนผัง · ความสูงแท่งแทน RSSI ไม่ใช่ความสูงอาคาร · ปักจุดในมุมมอง 2D" : "แถว CONNECTED อัปเดตสด · AP จากผลสแกน ~\(Int(store.scanInterval))s · ตำแหน่งจัดตามช่องในแต่ละย่าน ไม่ใช่ตำแหน่ง AP จริง").font(.system(size: 10)).foregroundStyle(.secondary)
                if survey && store.survey.points.count > 300 { Text("แสดง 300 จุดล่าสุดจาก \(store.survey.points.count) จุด ข้อมูลทั้งหมดอยู่ในตารางและไฟล์ส่งออก").font(.caption).foregroundStyle(.orange) }
                if !survey {
                    Text(store.lastScan.map { "AP snapshot: \($0.formatted(date: .omitted, time: .standard)) · แกนแต่ละแถว: CH / MHz (สเกลต่างกัน) · ช่องนอกผังดูหน้าเครือข่าย · แสดงสูงสุด 300 AP" } ?? "รอผลสแกน AP").font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                }
                if columns.isEmpty { Text(survey ? "ยังไม่มีจุดวัด — เพิ่มจุดในแผนผัง 2D" : "รอค่าจริงจาก Wi‑Fi — ไม่มีการเติมข้อมูลจำลอง").font(.caption).foregroundStyle(.orange) }
            }.padding(16).background(.white.opacity(0.025))
        }.background(StudioTheme.surface, in: RoundedRectangle(cornerRadius: 20)).clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(StudioTheme.cyan.opacity(0.22)))
    }
}
