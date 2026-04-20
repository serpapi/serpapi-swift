#if os(macOS)
import AppKit
import SwiftUI

/// Sets the hosting `NSWindow` to **800×600** points once, keeping the window centered on its previous center.
struct WindowFrameAdjuster: NSViewRepresentable {
    private static let targetWidth: CGFloat = 800
    private static let targetHeight: CGFloat = 600

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.scheduleResize(hostingView: nsView)
    }

    @MainActor
    final class Coordinator {
        private var didResize = false
        private var didScheduleResize = false

        func scheduleResize(hostingView: NSView) {
            guard !didScheduleResize else { return }
            didScheduleResize = true
            Task {
                await tryResize(hostingView: hostingView, attempt: 0)
            }
        }

        func tryResize(hostingView: NSView, attempt: Int = 0) async {
            guard !didResize else { return }
            if attempt > 40 {
                didResize = true
                return
            }

            guard let window = hostingView.window else {
                try? await Task.sleep(nanoseconds: 16_000_000)
                await tryResize(hostingView: hostingView, attempt: attempt + 1)
                return
            }

            let frame = window.frame
            guard frame.width > 50, frame.height > 50 else {
                try? await Task.sleep(nanoseconds: 16_000_000)
                await tryResize(hostingView: hostingView, attempt: attempt + 1)
                return
            }

            let newWidth = WindowFrameAdjuster.targetWidth
            let newHeight = WindowFrameAdjuster.targetHeight
            let x = frame.midX - newWidth / 2
            let y = frame.midY - newHeight / 2

            window.setFrame(
                NSRect(x: x, y: y, width: newWidth, height: newHeight),
                display: true,
                animate: false
            )
            didResize = true
        }
    }
}
#endif
