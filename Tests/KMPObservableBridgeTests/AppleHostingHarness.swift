#if os(iOS) || os(macOS)
import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
final class AppleHostingHarness {
    #if os(iOS)
    private let window: UIWindow
    private let controller: UIHostingController<AnyView>
    #elseif os(macOS)
    private let window: NSWindow
    private let controller: NSHostingController<AnyView>
    #endif

    init<Content: View>(rootView: Content) {
        #if os(iOS)
        controller = UIHostingController(rootView: AnyView(rootView))
        window = UIWindow(
            frame: CGRect(x: 0, y: 0, width: 320, height: 480)
        )
        window.rootViewController = controller
        window.makeKeyAndVisible()
        layoutIfNeeded()
        #elseif os(macOS)
        _ = NSApplication.shared
        controller = NSHostingController(rootView: AnyView(rootView))
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 480),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = controller
        window.orderFrontRegardless()
        layoutIfNeeded()
        #endif
    }

    func flushPendingUpdates() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { [self] in
                layoutIfNeeded()
                DispatchQueue.main.async {
                    continuation.resume()
                }
            }
        }
    }

    func removeContent() {
        controller.rootView = AnyView(EmptyView())
        layoutIfNeeded()
        #if os(iOS)
        window.rootViewController = nil
        window.isHidden = true
        #elseif os(macOS)
        window.contentViewController = nil
        window.orderOut(nil)
        #endif
    }

    private func layoutIfNeeded() {
        #if os(iOS)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        #elseif os(macOS)
        controller.view.needsLayout = true
        controller.view.layoutSubtreeIfNeeded()
        #endif
    }
}
#endif
