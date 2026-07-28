import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            OwnershipExamplesView()
                .tabItem {
                    Label("Ownership", systemImage: "rectangle.stack")
                }

            ArticleInjectorExampleView()
                .tabItem {
                    Label("SKIE", systemImage: "newspaper")
                }

            CallbackExamplesView()
                .tabItem {
                    Label("Adapters", systemImage: "arrow.triangle.2.circlepath")
                }

            NativeCoroutinesExampleView()
                .tabItem {
                    Label("Native", systemImage: "point.3.connected.trianglepath.dotted")
                }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            List {
                ExampleHeader(
                    title: "SwiftUI Ownership",
                    subtitle: "StateObject, ObservedObject, and environment.",
                    systemImage: "rectangle.stack"
                )
                ExampleHeader(
                    title: "SKIE StateFlow",
                    subtitle: "Macro-checked, field-level observation.",
                    systemImage: "newspaper"
                )
                ExampleHeader(
                    title: "Explicit Adapters",
                    subtitle: "Callback and Combine cancellation.",
                    systemImage: "arrow.triangle.2.circlepath"
                )
            }
            .navigationTitle("Bridge Examples")
        }
        .previewDisplayName("Example catalog")
    }
}
