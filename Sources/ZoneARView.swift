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

    // 1000 px (lățimea proiecției) -> MAP_W metri pe masă
    static let MAP_W: Float = 0.72
    static var scale: Float { MAP_W / RoGeo.viewW }
    static var kmToPx: Float { Float(RoGeo.S / 111.0) }   // ~1.26 px / km

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

        // se prinde de prima suprafață orizontală găsită
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

        private var zonesRoot = Entity()
        private var userMarker: Entity?
        private var cores: [ModelEntity] = []
        private var labels: [ModelEntity] = []
        private var key = ""
        private var insideZone = false
        private var t: Float = 0

        // ---- harta statică (placă + contur + orașe + N) ----
        func buildStaticMap(into root: Entity) {
            let scale = ZoneARView.scale
            let w = RoGeo.viewW * scale
            let h = RoGeo.viewH * scale

            // placă translucidă
            let plate = ModelEntity(
                mesh: .generateBox(size: [w * 1.04, 0.004, h * 1.04], cornerRadius: 0.01),
                materials: [SimpleMaterial(color: UIColor(white: 0.02, alpha: 0.6), isMetallic: false)]
            )
            plate.position = [0, -0.003, 0]
            root.addChild(plate)

            // contur România (segmente ca bare subțiri)
            let outline = RoGeo.outline
            let cyan = UIColor(hex: "#2dd4bf")
            for i in 0..<outline.count {
                let a = ZoneARView.local(outline[i], y: 0.004)
                let b = ZoneARView.local(outline[(i + 1) % outline.count], y: 0.004)
                let dx = b.x - a.x, dz = b.z - a.z
                let len = max(0.0005, sqrt(dx * dx + dz * dz))
                let seg = ModelEntity(
                    mesh: .generateBox(size: [len, 0.006, 0.004]),
                    materials: [UnlitMaterial(color: cyan)]
                )
                seg.position = [(a.x + b.x) / 2, 0.004, (a.z + b.z) / 2]
                seg.orientation = simd_quatf(angle: -atan2(dz, dx), axis: [0, 1, 0])
                root.addChild(seg)
            }

            // orașe
            for c in RoGeo.cities {
                let p = ZoneARView.local(RoGeo.project(lon: c.lon, lat: c.lat), y: 0.006)
                let col = c.tier == 1 ? UIColor(hex: "#7fe9d8") : UIColor(white: 0.7, alpha: 1)
                let r: Float = c.tier == 1 ? 0.006 : 0.004
                let dot = ModelEntity(mesh: .generateSphere(radius: r), materials: [UnlitMaterial(color: col)])
                dot.position = p
                root.addChild(dot)
            }

            // eticheta N (sus = nord, py mic)
            let nPos = SIMD3<Float>(0, 0.02, -h / 2 - 0.02)
            let nMesh = MeshResource.generateText("N", extrusionDepth: 0.001,
                                                  font: .systemFont(ofSize: 0.022, weight: .bold))
            let nLabel = ModelEntity(mesh: nMesh, materials: [UnlitMaterial(color: UIColor(hex: "#ff5555"))])
            nLabel.position = nPos
            root.addChild(nLabel)
            labels.append(nLabel)

            // rădăcina zonelor + marker utilizator
            root.addChild(zonesRoot)
        }

        // ---- update zone + poziție utilizator ----
        func update(zones: [Zone], user: CLLocationCoordinate2D?) {
            let active = zones.filter { $0.isActive }

            // reconstruim domurile doar la schimbare
            let newKey = active.map { "\($0.id)|\(Int($0.radiusKm))|\($0.color)|\($0.latitude),\($0.longitude)" }.joined()
            if newKey != key {
                key = newKey
                zonesRoot.children.removeAll()
                cores.removeAll()

                for z in active {
                    let center = RoGeo.project(lon: z.longitude, lat: z.latitude)
                    let pos = ZoneARView.local(center, y: 0.006)
                    let rPx = Float(z.radiusKm) * ZoneARView.kmToPx
                    let r = max(0.01, rPx * ZoneARView.scale)
                    let col = UIColor(hex: z.color)

                    // dom translucid (semisferă turtită)
                    let dome = ModelEntity(
                        mesh: .generateSphere(radius: r),
                        materials: [SimpleMaterial(color: col.withAlphaComponent(0.22), isMetallic: false)]
                    )
                    dome.position = pos
                    dome.scale = [1, 0.55, 1]
                    zonesRoot.addChild(dome)

                    // beacon vertical
                    let beacon = ModelEntity(
                        mesh: .generateBox(size: [0.003, 0.06, 0.003]),
                        materials: [UnlitMaterial(color: col)]
                    )
                    beacon.position = [pos.x, 0.03, pos.z]
                    zonesRoot.addChild(beacon)

                    // miez pulsatil
                    let core = ModelEntity(mesh: .generateSphere(radius: 0.006), materials: [UnlitMaterial(color: col)])
                    core.position = [pos.x, 0.06, pos.z]
                    zonesRoot.addChild(core)
                    cores.append(core)

                    // etichetă
                    let txt = "\(z.name)\n\(z.band)"
                    let mesh = MeshResource.generateText(txt, extrusionDepth: 0.001,
                                                         font: .systemFont(ofSize: 0.014, weight: .semibold))
                    let label = ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: .white)])
                    label.position = [pos.x, 0.085, pos.z]
                    zonesRoot.addChild(label)
                    labels.append(label)
                }
            }

            // marker utilizator
            guard let user = user else { return }
            insideZone = active.contains { distanceMeters(user, CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)) <= $0.radiusKm * 1000 }
            let up = ZoneARView.local(RoGeo.project(lon: user.longitude, lat: user.latitude), y: 0.006)

            if userMarker == nil {
                let marker = Entity()
                let pin = ModelEntity(mesh: .generateBox(size: [0.004, 0.07, 0.004]),
                                      materials: [UnlitMaterial(color: UIColor(hex: "#00aaff"))])
                pin.position = [0, 0.035, 0]
                let head = ModelEntity(mesh: .generateSphere(radius: 0.009),
                                       materials: [UnlitMaterial(color: .white)])
                head.position = [0, 0.075, 0]
                marker.addChild(pin)
                marker.addChild(head)
                mapRoot?.addChild(marker)
                userMarker = marker
            }
            userMarker?.position = up
        }

        func onUpdate() {
            guard let arView = arView else { return }
            t += 1.0 / 60.0

            let camPos = arView.cameraTransform.translation
            for l in labels {
                let p = l.position(relativeTo: nil)
                l.look(at: camPos, from: p, relativeTo: nil)
                l.orientation = simd_mul(l.orientation, simd_quatf(angle: .pi, axis: [0, 1, 0]))
            }

            let s = 1.0 + 0.3 * sin(t * 3.0)
            for c in cores { c.scale = [s, s, s] }

            // markerul tău pulsează roșu când ești într-o zonă activă
            if let head = userMarker?.children.last as? ModelEntity {
                let col: UIColor = insideZone ? UIColor(hex: "#ff5555") : .white
                if var m = head.model {
                    m.materials = [UnlitMaterial(color: col)]
                    head.model = m
                }
                let us = insideZone ? Float(1.0 + 0.4 * sin(t * 6.0)) : 1.0
                head.scale = [us, us, us]
            }
        }
    }
}