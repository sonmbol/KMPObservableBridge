import SwiftUI
import shared

@main
struct iOSApp: App {
    init() {
        KoinIntializerKt.doInitKoin()
    }
	var body: some Scene {
		WindowGroup {
			ContentView()
		}
	}
}
