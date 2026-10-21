import SwiftUI
import SpriteKit

// Explicitly host the native SKView: the SwiftUI SpriteView can remain paused when
// embedded in an accessory application's borderless AppKit window.
#if os(macOS)
/// Rebind the existing scene after AppKit display/session restoration. Never
/// recreate gameplay state or reset the scene graph during surface recovery.
class AquariumRenderView: SKView {
    func restorePresentation(of aquarium: AquariumScene) {
        let paused = isPaused
        presentScene(nil)
        allowsTransparency = true
        presentScene(aquarium)
        isPaused = paused
        needsDisplay = true
    }
}

struct NativeAquariumView: NSViewRepresentable {
    let scene: AquariumScene
    var paused: Bool
    func makeNSView(context: Context) -> SKView {
        let view = SKView(frame: NSRect(x: 0, y: 0, width: 320, height: 180))
        view.preferredFramesPerSecond = 30
        view.allowsTransparency = true
        view.presentScene(scene)
        return view
    }
    func updateNSView(_ view: SKView, context: Context) { view.isPaused = paused; view.preferredFramesPerSecond = scene.reducedMotion ? 10 : 30 }
}
#else
private final class ViewportAquariumView: SKView {
    var fillsViewport = false
    var singleTap: ((CGPoint) -> Void)?
    var doubleTap: (() -> Void)?
    private lazy var single = UITapGestureRecognizer(target: self, action: #selector(tappedOnce(_:)))
    private lazy var double = UITapGestureRecognizer(target: self, action: #selector(tappedTwice(_:)))
    private var installedGestures = false

    func configureInteraction() {
        if !installedGestures {
            double.numberOfTapsRequired = 2
            single.require(toFail: double)
            addGestureRecognizer(single)
            addGestureRecognizer(double)
            installedGestures = true
        }
        single.isEnabled = singleTap != nil
        double.isEnabled = doubleTap != nil
    }

    @objc private func tappedOnce(_ recognizer: UITapGestureRecognizer) {
        guard let scene else { return }
        singleTap?(scene.convertPoint(fromView: recognizer.location(in: self)))
    }
    @objc private func tappedTwice(_ recognizer: UITapGestureRecognizer) { doubleTap?() }

    override func layoutSubviews() {
        super.layoutSubviews()
        (scene as? AquariumScene)?.setViewportSize(fillsViewport ? bounds.size : nil)
    }
}

struct NativeAquariumView: UIViewRepresentable {
    let scene: AquariumScene
    var paused: Bool
    var fillsViewport = false
    var interactionEnabled = true
    var onSingleTap: ((CGPoint) -> Void)? = nil
    var onDoubleTap: (() -> Void)? = nil
    func makeUIView(context: Context) -> SKView {
        let view = ViewportAquariumView(frame: CGRect(x: 0, y: 0, width: 320, height: 180))
        view.preferredFramesPerSecond = 30
        view.fillsViewport = fillsViewport
        view.backgroundColor = .clear
        view.allowsTransparency = true
        view.presentScene(scene)
        return view
    }
    func updateUIView(_ view: SKView, context: Context) {
        view.isUserInteractionEnabled = interactionEnabled
        view.accessibilityElementsHidden = !interactionEnabled
        if let aquarium = view as? ViewportAquariumView {
            aquarium.fillsViewport = fillsViewport
            aquarium.singleTap = onSingleTap
            aquarium.doubleTap = onDoubleTap
            aquarium.configureInteraction()
        }
        scene.setViewportSize(fillsViewport ? view.bounds.size : nil)
        view.isPaused = paused
        view.preferredFramesPerSecond = scene.reducedMotion ? 10 : 30
        view.setNeedsLayout()
    }
}
#endif
