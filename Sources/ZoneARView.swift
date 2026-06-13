import SwiftUI
import RealityKit
import ARKit
import CoreLocation
import Combine

struct ZoneARView: UIViewRepresentable {
    var zones: [Zone]
    var user: CLLocationCoordinate2D?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravityAndHeading   // -Z = Nord, +X = Est
        config.planeDetection = []
        arView.session.run(config)
        arView.environment.background = .cameraFeed()

        let root = AnchorEntity(world: .zero)
        arView.scene.addAnchor(root)

        context.coordinator.arView = arView
        context.coordinator.root = root
        context.coordinator.cancellable = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak coord = context.coordinator] _ in
            coord?.onUpdate()
        }
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.rebuild(zones: zones, user: user)
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        uiView.session.pause()
        coordinator.cancellable?.cancel()
    }

    // MARK: - Coordinator
    final class Coordinator {
        weak var arView: ARView?
        var root: AnchorEntity?
        var cancellable: Cancellable?

        private var labels: [ModelEntity] = []
        private var cores: [ModelEntity] = []
        private var key = ""
        private var t: Float = 0

        func rebuild(zones: [Zone], user: CLLocationCoordinate2D?) {
            guard let root = root, let user = user else { return }
            let active = zones.filter { $0.isActive }

            // reconstruim doar dacă s-a schimbat ceva relevant
            let newKey = active.map { "\($0.id)|\(Int($0.radiusKm))|\($0.color)" }.joined()
                + String(format: "@%.5f,%.5f", user.latitude, user.longitude)
            if newKey == key { return }
            key = newKey

            root.children.removeAll()
            labels.removeAll()
            cores.removeAll()

            for z in active {
                let to = CLLocationCoordinate2D(latitude: z.latitude, longitude: z.longitude)
                let realM = distanceMeters(user, to)
                let brg = bearingDegrees(user, to) * .pi / 180

                // compresie distanță: 1 km -> 1.5 m, limitat la 3..40 m
                let d = Float(min(40.0, max(3.0, realM / 1000.0 * 1.5)))
                let x = d * Float(sin(brg))
                let zc = -d * Float(cos(brg))
                let domeR = Float(min(6.0, max(1.0, z.radiusKm / 12.0)))
                let col = UIColor(hex: z.color)

                // cupolă translucidă
                let dome = ModelEntity(
                    mesh: .generateSphere(radius: domeR),
                    materials: [UnlitMaterial(color: col.withAlphaComponent(0.22))]
                )
                dome.position = [x, 0, zc]
                root.addChild(dome)

                // miez (pulsatil)
                let core = ModelEntity(
                    mesh: .generateSphere(radius: 0.22),
                    materials: [UnlitMaterial(color: col)]
                )
                core.position = [x, 0, zc]
                root.addChild(core)
                cores.append(core)

                // etichetă text
                let txt = "\(z.name)\n\(z.band) • \(z.jammerLabel)\n\(Int(realM / 1000)) km"
                let mesh = MeshResource.generateText(
                    txt,
                    extrusionDepth: 0.01,
                    font: .systemFont(ofSize: 0.32, weight: .semibold),
                    containerFrame: .zero,
                    alignment: .center,
                    lineBreakMode: .byWordWrapping
                )
                let label = ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: .white)])
                label.position = [x, domeR + 0.7, zc]
                root.addChild(label)
                labels.append(label)
            }
        }

        func onUpdate() {
            guard let arView = arView else { return }
            t += 1.0 / 60.0

            // etichetele se orientează spre cameră (billboard)
            let camPos = arView.cameraTransform.translation
            for l in labels {
                let p = l.position(relativeTo: nil)
                l.look(at: camPos, from: p, relativeTo: nil)
                // textul are fața pe +Z, look() pune -Z spre țintă -> rotim 180° pe Y
                l.orientation = simd_mul(l.orientation, simd_quatf(angle: .pi, axis: [0, 1, 0]))
            }

            // puls miezuri
            let s = 1.0 + 0.25 * sin(t * 3.0)
            for c in cores { c.scale = [s, s, s] }
        }
    }
}
