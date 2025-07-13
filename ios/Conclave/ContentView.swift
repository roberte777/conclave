import ConclaveKit
import SwiftUI

struct ContentView: View {
    @Environment(ConclaveClientManager.self) private var conclave

    var body: some View {
        Text("Hello, World!")
    }
}
