import SwiftUI
import RealityKit
import ARKit
import CoreLocation
import Combine

// Hartă 3D a României în AR (tabletop): se ancorează pe o suprafață orizontală,
// afișează conturul țării, orașe, zonele de bruiaj active ca domuri, și poziția ta reală.
struct ZoneARView: UIViewRepresentable {
    var zones: [Zone]
    var user: CLLocationCoordinate2D?

    static let MAP_W: Float = 0.72
    static var scale: Float { MAP_W / RoGeo.viewW }
    static var kmToPx: Float { Float(RoGeo.S / 111.0) }

    static func local(_ p: SIMD2<Float>, y: Float = 0) -> SIMD3<Float> {
        SIMD3<Float>((p.x - RoGeo.viewW / 2) * scale, y, (p.y - RoGeo.viewH / 2) * scale)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.worldAlignment = .gravity
        arView.session.run(config)
        arView.environment.background = .cameraFeed()

        let anchor = AnchorEntity(.plane(.horizontal, classification: .any, minimumBounds: [0.15, 0.15]))
        arView.scene.addAnchor(anchor)

        let mapRoot = Entity()
        anchor.addChild(mapRoot)
        context.coordinator.buildStaticMap(into: mapRoot)

        context.coordinator.arView = arView
        context.coordinator.mapRoot = mapRoot
        context.coordinator.cancellable = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak coord = context.coordinator] _ in
            coord?.onUpdate()
        }
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.update(zones: zones, user: user)
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        uiView.session.pause()
        coordinator.cancellable?.cancel()
    }

    // MARK: - Coordinator
    final class Coordinator {
        weak var arView: ARView?
        var mapRoot: Entity?
        var cancellable: Cancellable?

        private struct Ping { let e: ModelEntity; let off: Float }

        private var zonesRoot = Entity()
        private var userMarker: Entity?
        private var userHead: ModelEntity?
        private var userNeedle: ModelEntity?
        private var userRing: ModelEntity?
        private var cores: [ModelEntity] = []
        private var halos: [ModelEntity] = []
        private var pings: [Ping] = []
        private var zoneLabels: [ModelEntity] = []
        private var staticLabels: [ModelEntity] = []
        private var key = ""
        private var insideZone = false
        private var lastInside: Bool? = nil
        private var t: Float = 0

        private func setMaterial(_ e: ModelEntity?, _ mat: Material) {
            guard let e = e, var m = e.model else { return }
            m.materials = [mat]
            e.model = m
        }

        // ---- harta statică (placă + bezel + grilă + contur + orașe + N) ----
        func buildStaticMap(into root: Entity) {
            let scale = ZoneARView.scale
            let w = RoGeo.viewW * scale
            let h = RoGeo.viewH * scale
            let teal = UIColor(hex: "#2dd4bf")

            // placă translucidă
            let plate = ModelEntity(
                mesh: .generateBox(size: [w * 1.05, 0.004, h * 1.05], cornerRadius: 0.012),
                materials: [SimpleMaterial(color: UIColor(white: 0.015, alpha: 0.66), isMetallic: false)]
            )
            plate.position = [0, -0.003, 0]
            root.addChild(plate)

            // grilă fină
            let grid = SimpleMaterial(color: teal.withAlphaComponent(0.07), isMetallic: false)
            let fw = w * 1.05, fh = h * 1.05
            for i in 1..<6 {
                let x = -fw / 2 + fw * Float(i) / 6
                let ln = ModelEntity(mesh: .generateBox(size: [0.0012, 0.001, fh]), materials: [grid])
                ln.position = [x, 0.0026, 0]; root.addChild(ln)
            }
            for i in 1..<6 {
                let z = -fh / 2 + fh * Float(i) / 6
                let ln = ModelEntity(mesh: .generateBox(size: [fw, 0.001, 0.0012]), materials: [grid])
                ln.position = [0, 0.0026, z]; root.addChild(ln)
            }

            // bezel teal
            let bezel = UnlitMaterial(color: teal)
            for sz in [-fh / 2, fh / 2] {
                let bar = ModelEntity(mesh: .generateBox(size: [fw + 0.004, 0.006, 0.004]), materials: [bezel])
                bar.position = [0, 0.004, sz]; root.addChild(bar)
            }
            for sx in [-fw / 2, fw / 2] {
                let bar = ModelEntity(mesh: .generateBox(size: [0.004, 0.006, fh + 0.004]), materials: [bezel])
                bar.position = [sx, 0.004, 0]; root.addChild(bar)
            }

            // contur România
            let outline = RoGeo.outline
            for i in 0..<outline.count {
                let a = ZoneARView.local(outline[i], y: 0.0045)
                let b = ZoneARView.local(outline[(i + 1) % outline.count], y: 0.0045)
                let dx = b.x - a.x, dz = b.z - a.z
                let len = max(0.0005, sqrt(dx * dx + dz * dz))
                let seg = ModelEntity(mesh: .generateBox(size: [len, 0.006, 0.005]), materials: [UnlitMaterial(color: teal)])
                seg.position = [(a.x + b.x) / 2, 0.0045, (a.z + b.z) / 2]
                seg.orientation = simd_quatf(angle: -atan2(dz, dx), axis: [0, 1, 0])
                root.addChild(seg)
            }

            // orașe (+ halou pentru cele mari)
            for c in RoGeo.cities {
                let p = ZoneARView.local(RoGeo.project(lon: c.lon, lat: c.lat), y: 0.006)
                if c.tier == 1 {
                    let halo = ModelEntity(mesh: .generateSphere(radius: 0.012),
                                           materials: [SimpleMaterial(color: teal.withAlphaComponent(0.16), isMetallic: false)])
                    halo.position = p; halo.scale = [1, 0.35, 1]; root.addChild(halo)
                }
                let col = c.tier == 1 ? UIColor(hex: "#7fe9d8") : UIColor(white: 0.7, alpha: 1)
                let r: Float = c.tier == 1 ? 0.006 : 0.004
                let dot = ModelEntity(mesh: .generateSphere(radius: r), materials: [UnlitMaterial(color: col)])
                dot.position = p; root.addChild(dot)
            }

            // eticheta N
            let nMesh = MeshResource.generateText("N", extrusionDepth: 0.001,
                                                  font: .systemFont(ofSize: 0.022, weight: .bold))
            let nLabel = ModelEntity(mesh: nMesh, materials: [UnlitMaterial(color: UIColor(hex: "#ff5555"))])
            nLabel.position = SIMD3<Float>(0, 0.02, -h / 2 - 0.03)
            root.addChild(nLabel)
            staticLabels.append(nLabel)

            root.addChild(zonesRoot)
        }

        // ---- update zone + poziție utilizator ----
        func update(zones: [Zone], user: CLLocationCoordinate2D?) {
            let active = zones.filter { $0.isActive }

            let newKey = active.map { "\($0.id)|\(Int($0.radiusKm))|\($0.color)|\($0.latitude),\($0.longitude)|\(Int($0.intensity))" }.joined()
            if newKey != key {
                key = newKey
                zonesRoot.children.removeAll()
                cores.removeAll(); halos.removeAll(); pings.removeAll(); zoneLabels.removeAll()

                for z in active {
                    let center = RoGeo.project(lon: z.longitude, lat: z.latitude)
                    let pos = ZoneARView.local(center, y: 0.006)
                    let r = max(0.012, Float(z.radiusKm) * ZoneARView.kmToPx * ZoneARView.scale)
                    let col = UIColor(hex: z.color)

                    // amprenta (disc glow la sol)
                    let foot = ModelEntity(mesh: .generateSphere(radius: r * 1.06),
                                           materials: [SimpleMaterial(color: col.withAlphaComponent(0.16), isMetallic: false)])
                    foot.position = pos; foot.scale = [1, 0.02, 1]; zonesRoot.addChild(foot)

                    // unde de șoc (2)
                    for k in 0..<2 {
                        let pg = ModelEntity(mesh: .generateSphere(radius: r),
                                             materials: [SimpleMaterial(color: col.withAlphaComponent(0.20), isMetallic: false)])
                        pg.position = pos; pg.scale = [0.25, 0.02, 0.25]; zonesRoot.addChild(pg)
                        pings.append(Ping(e: pg, off: Float(k) * 0.5))
                    }

                    // dom din sticlă
                    let alpha = 0.13 + 0.10 * Float(z.intensity) / 100
                    let dome = ModelEntity(mesh: .generateSphere(radius: r),
                                           materials: [SimpleMaterial(color: col.withAlphaComponent(CGFloat(alpha)), isMetallic: false)])
                    dome.position = pos; dome.scale = [1, 0.55, 1]; zonesRoot.addChild(dome)

                    // beacon + halo
                    let beacon = ModelEntity(mesh: .generateBox(size: [0.0028, 0.075, 0.0028]), materials: [UnlitMaterial(color: col)])
                    beacon.position = [pos.x, 0.037, pos.z]; zonesRoot.addChild(beacon)
                    let bHalo = ModelEntity(mesh: .generateBox(size: [0.008, 0.075, 0.008]),
                                            materials: [SimpleMaterial(color: col.withAlphaComponent(0.16), isMetallic: false)])
                    bHalo.position = [pos.x, 0.037, pos.z]; zonesRoot.addChild(bHalo)

                    // miez + halou
                    let core = ModelEntity(mesh: .generateSphere(radius: 0.006), materials: [UnlitMaterial(color: col)])
                    core.position = [pos.x, 0.078, pos.z]; zonesRoot.addChild(core); cores.append(core)
                    let cHalo = ModelEntity(mesh: .generateSphere(radius: 0.011),
                                            materials: [SimpleMaterial(color: col.withAlphaComponent(0.22), isMetallic: false)])
                    cHalo.position = [pos.x, 0.078, pos.z]; zonesRoot.addChild(cHalo); halos.append(cHalo)

                    // etichetă
                    let txt = "\(z.name)\n\(z.jammerLabel) · \(z.band) · \(Int(z.intensity))%"
                    let mesh = MeshResource.generateText(txt, extrusionDepth: 0.001,
                                                         font: .systemFont(ofSize: 0.013, weight: .semibold))
                    let label = ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: .white)])
                    label.position = [pos.x, 0.092, pos.z]; zonesRoot.addChild(label); zoneLabels.append(label)
                }
            }

            // marker utilizator
            guard let user = user else { return }
            insideZone = active.contains { distanceMeters(user, CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)) <= $0.radiusKm * 1000 }
            let up = ZoneARView.local(RoGeo.project(lon: user.longitude, lat: user.latitude), y: 0.006)

            if userMarker == nil {
                let marker = Entity()
                let blue = UIColor(hex: "#00aaff")

                let ring = ModelEntity(mesh: .generateSphere(radius: 0.014),
                                       materials: [SimpleMaterial(color: blue.withAlphaComponent(0.45), isMetallic: false)])
                ring.scale = [1, 0.03, 1]; ring.position = [0, 0.004, 0]
                let needle = ModelEntity(mesh: .generateBox(size: [0.0035, 0.085, 0.0035]), materials: [UnlitMaterial(color: blue)])
                needle.position = [0, 0.0425, 0]
                let head = ModelEntity(mesh: .generateSphere(radius: 0.009), materials: [UnlitMaterial(color: .white)])
                head.position = [0, 0.092, 0]
                let headHalo = ModelEntity(mesh: .generateSphere(radius: 0.015),
                                           materials: [SimpleMaterial(color: blue.withAlphaComponent(0.3), isMetallic: false)])
                headHalo.position = [0, 0.092, 0]

                marker.addChild(ring); marker.addChild(needle); marker.addChild(head); marker.addChild(headHalo)
                mapRoot?.addChild(marker)
                userMarker = marker; userRing = ring; userNeedle = needle; userHead = head
            }
            userMarker?.position = up
        }

        func onUpdate() {
            guard let arView = arView else { return }
            t += 1.0 / 60.0

            let camPos = arView.cameraTransform.translation
            for l in staticLabels + zoneLabels {
                let p = l.position(relativeTo: nil)
                l.look(at: camPos, from: p, relativeTo: nil)
                l.orientation = simd_mul(l.orientation, simd_quatf(angle: .pi, axis: [0, 1, 0]))
            }

            let s = 1.0 + 0.28 * sin(t * 3.0)
            for c in cores { c.scale = [s, s, s] }
            let hs = 1.0 + 0.45 * (0.5 + 0.5 * sin(t * 3.0 + .pi))
            for h in halos { h.scale = [hs, hs, hs] }

            for p in pings {
                let phase = (t * 0.6 + p.off).truncatingRemainder(dividingBy: 1.0)
                let k = 0.25 + phase * 1.9
                p.e.scale = [k, 0.02, k]
            }

            // marker: roșu + puls când ești în zonă
            if insideZone != lastInside {
                lastInside = insideZone
                let blue = UIColor(hex: "#00aaff")
                let red = UIColor(hex: "#ff5555")
                setMaterial(userNeedle, UnlitMaterial(color: insideZone ? red : blue))
                setMaterial(userHead, UnlitMaterial(color: insideZone ? red : .white))
                setMaterial(userRing, SimpleMaterial(color: (insideZone ? red : blue).withAlphaComponent(0.5), isMetallic: false))
            }
            if let ring = userRing {
                let rs = insideZone ? Float(1.0 + 0.5 * sin(t * 6.0)) : Float(1.0 + 0.18 * sin(t * 2.2))
                ring.scale = [rs, 0.03, rs]
            }
            if let head = userHead {
                let us = insideZone ? Float(1.0 + 0.4 * sin(t * 6.0)) : 1.0
                head.scale = [us, us, us]
            }
        }
    }
}